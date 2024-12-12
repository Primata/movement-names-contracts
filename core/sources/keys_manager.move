module movement_names::keys_manager {
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin;
    use aptos_framework::event;
    use aptos_framework::object::{Self, Object, ExtendRef, TransferRef};
    use aptos_framework::timestamp;
    use aptos_framework::account;
    use movement_names::config;
    use movement_names::price_model;
    use movement_names::token_helper;
    use movement_names::string_validator;
    use movement_names::domains;
    use std::error;
    use std::option::{Self, Option};
    use std::signer::address_of;
    use std::signer;
    use std::string::{Self, String, utf8};
    
    struct Settings has key {
        protocol_fee_destination : address,
        application_fee_percent : u64,
        protocol_fee_percent : u64,
        subject_fee_percent : u64,
    }

    #[event]
    struct Trade has drop, store {
        trader: address,
        domain: address,
        appliaction: address,
        is_buy: bool,
        key_amount: u64,
        move_amount: u64,
        protocol_amount: u64,
        subject_amount: u64,
        application_amount: u64,
        new_supply: u64,
    }

    struct TradeEvents has key, store {
        trade_events: event::EventHandle<Trade>,
    }

    const OCTAS: u64 = 100000000;

    fun init_module(admin: &signer) {
        let settings = Settings {
            protocol_fee_destination: signer::address_of(admin),
            application_fee_percent: 300,
            protocol_fee_percent: 10,
            subject_fee_percent: 500,
        };
        let admin_address = signer::address_of(admin);
        let constructor_ref = object::create_object(admin_address);
        let object_signer = &object::generate_signer(&constructor_ref);

        move_to<Settings>(object_signer, settings);

        move_to(object_signer, TradeEvents {
            trade_events: account::new_event_handle<Trade>(object_signer),
        });
    }

    #[view]
    public fun get_settings() : &Settings {
        &borrow_global_mut<Settings>(signer::address_of(&object_signer()))
    }
    
    #[view]
    public fun get_price(supply: u64, amount: u64) : u64 {
        let sum1 = if (supply == 0) { 0 } else { (supply - 1) * supply * (2 * (supply - 1) + 1) / 6 };
        let sum2 = if (supply == 0 && amount == 1) { 0 } else { (supply - 1 + amount) * (supply + amount) * (2 * (supply - 1 + amount) + 1) / 6 };
        return (sum2 - sum1) * 1 * OCTAS / 16000
    }

    #[view]
    public fun get_buy_price(domain_name: &String, amount: u64) : u64  {
        let supply = get_name_record(domain_name).key_supply;
        return get_price(supply, amount)
    }

    #[view]
    public fun get_sell_price(domain_name: &String, amount: u64) : u64  {
        let supply = get_name_record(domain_name).key_supply;
        return get_price(supply - amount, amount)
    }

    fun object_signer() : signer {
        let constructor_ref = object::create_object(@keys_manager);
        object::generate_signer(&constructor_ref)
    }

    #[view]
    public fun get_buy_price_after_fee(domain_name: &String, amount: u64) : u64 acquires Settings {
        let price = get_buy_price(domain_name, amount);
        let settings = get_settings();
        let protocol_fee = price * settings.protocol_fee_percent / 1 * OCTAS;
        let application_fee = price * settings.application_fee_percent / 1 * OCTAS;
        let subject_fee = price * settings.subject_fee_percent / 1 * OCTAS;
        price + protocol_fee + application_fee + subject_fee
    }

    #[view]
    public fun get_sell_price_after_fee(domain_name: &String, amount: u64) : u64 {
        let price = get_sell_price(domain_name, amount);
        let settings = get_settings();
        let protocol_fee = price * settings.protocol_fee_percent / 1 * OCTAS;
        let application_fee = price * settings.application_fee_percent / 1 * OCTAS;
        let subject_fee = price * settings.subject_fee_percent / 1 * OCTAS;
        price - protocol_fee - application_fee - subject_fee
    }

    entry fun buy_keys(account: &signer, domain_name: &String, amount: u64, application_fee_destination: address) acquires Settings {
        let record = domains::get_name_record(domain_name);
        let account_addr = signer::address_of(account);
        assert!(record.key_supply > 0, 1);
        let price = get_price(record.key_supply, amount);

        let protocol_fee = price * get_settings().protocol_fee_percent / 1 * OCTAS;
        let application_fee = price * get_settings().application_fee_percent / 1 * OCTAS;
        let subject_fee = price * get_settings().subject_fee_percent / 1 * OCTAS;
        
        coin::transfer(account, get_settings().protocol_fee_destination, protocol_fee);
        if (application_fee_destination != @0x0) {
            coin::transfer(account, application_fee_destination, application_fee);
        } else {
            coin::transfer(account, get_settings().protocol_fee_destination, application_fee);
        };
        coin::transfer(account, subject, subject_fee);
        coin::transfer(account, admin_address, price - protocol_fee - application_fee - subject_fee);
        record.key_supply = record.key_supply + amount;
        
        let constructor_ref = &object::create_named_object(&get_app_signer(), domain_name);
        let mint_ref = fungible_asset::generate_mint_ref(constructor_ref);
        fungible_asset::mint_to(&mint_ref, account_addr, amount);

        trade_events = account::get_event_handle<Trade>(admin_address);
        event::emit_event(  
            &mut trade_events.trade_events,
            Trade {  
                trader: account_addr,
                domain: subject,
                appliaction: application_fee_destination,
                is_buy: true,
                key_amount: amount,
                move_amount: price,
                protocol_amount: protocol_fee,
                subject_amount: subject_fee,
                application_amount: application_fee,
                new_supply: record.key_supply,
           }  
       );  
    }

    entry fun sell_keys(account: &signer, subject: address, amount: u64, application_fee_destination: address) acquires NameRecord, Settings {
        let record = get_name_record(subject);
        let account_addr = signer::address_of(account);
        assert!(record.key_supply - amount > 0, 1);
        let price = get_price(record.key_supply - amount, amount);

        let protocol_fee = price * get_settings().protocol_fee_percent / 1 * OCTAS;
        let application_fee = price * get_settings().application_fee_percent / 1 * OCTAS;
        let subject_fee = price * get_settings().subject_fee_percent / 1 * OCTAS;
        
        let admin_address = get_settings().protocol_fee_destination;
        coin::transfer(admin_address, get_settings().protocol_fee_destination, protocol_fee);
        if (application_fee_destination != 0) {
            coin::transfer(admin_address, application_fee_destination, application_fee);
        } else {
            coin::transfer(admin_address, get_settings().protocol_fee_destination, application_fee);
        };
        coin::transfer(admin_address, subject, subject_fee);
        coin::transfer(account_addr, account_addr, price - protocol_fee - application_fee - subject_fee);

        record.key_supply = record.key_supply - amount;
        
        let constructor_ref = &object::create_named_object(&get_app_signer(), domain_name);
        let burn_ref = fungible_asset::generate_burn_ref(constructor_ref);
        fungible_asset::burn(&burn_ref, account_addr, amount);

        let new_supply = record.key_supply;

        trade_events = account::get_event_handle<Trade>(admin_address);
        event::emit_event(  
            &mut trade_events.trade_events,
            Trade {  
                trader: account_addr,
                domain: subject,
                appliaction: application_fee_destination,
                is_buy: false,
                key_amount: amount,
                move_amount: price,
                protocol_amount: protocol_fee,
                subject_amount: subject_fee,
                application_amount: application_fee,
                new_supply: record.key_supply,
           }  
       );  
    }
    
}
