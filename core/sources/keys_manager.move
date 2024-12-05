module movement_names::keys_manager {
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin;
    use aptos_framework::event;
    use aptos_framework::object::{Self, Object, ExtendRef, TransferRef};
    use aptos_framework::timestamp;
    use movement_names::config;
    use movement_names::price_model;
    use movement_names::token_helper;
    use movement_names::string_validator;
    use movement_names::domains::{NameRecord};
    use movement_names::domains;
    use std::error;
    use std::option::{Self, Option};
    use std::signer::address_of;
    use std::signer;
    use std::string::{Self, String, utf8};

    struct Settings {
        protocol_fee_destination : address,
        application_fee_percent : u64,
        protocol_fee_percent : u64,
        subject_fee_percent : u64,
    }

    #[event]
    struct Trade {
        trader: address,
        domain: address,
        appliaction: address,
        is_buy: bool,
        key_amount: u64,
        move_amount: u64,
        protocol_amount: u64,
        domain_amount: u64,
        protocol_amount: u64,
        new_supply: u64,
    }

    struct TradeEvents has key, store {
        trade_events: EventHandle<Trade>,
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
        let object_signer = object::generate_signer(constructor_ref);

        object::move_to<Settings>(object_signer, settings);

        move_to(admin_address, BridgeEvents {
            trade_events: account::new_event_handle<Trade>(admin_address),
        });
    }
    
    #[view]
    public fun get_price(supply: u64, amount: u64) : u64 {
        let sum1 = if (supply == 0) { 0 } else { (supply - 1) * supply * (2 * (supply - 1) + 1) / 6 };
        let sum2 = if (supply == 0 && amount == 1) { 0 } else { (supply - 1 + amount) * (supply + amount) * (2 * (supply - 1 + amount) + 1) / 6 };
        return (sum2 - sum1) * 1 * OCTAS / 16000;
    }

    #[view]
    public fun get_buy_price(key_subject: address, amount: u64) : u64 acquires NameRecord {
        let supply = borrow_global<NameRecord>(key_subject).keySupply;
        return get_price(supply, amount);
    }

    #[view]
    public fun get_sell_price(key_subject: address, amount: u64) : u64 acquires NameRecord {
        let supply = borrow_global<NameRecord>(key_subject).keySupply;
        return get_price(supply - amount, amount);
    }

    fun object_signer() : signer {
        let constructor_ref = object::create_object(@keys_manager);
        object::generate_signer(constructor_ref)
    }

    #[view]
    public fun get_buy_price_after_fee(key_subject: address, amount: u64) : u64 acquires Settings {
        let price = get_buy_price(key_subject, amount);
        let settings = borrow_global<Settings>(object_signer());
        let protocol_fee = price * settings.protocol_fee_percent / 1 * OCTAS;
        let application_fee = price * settings.application_fee_percent / 1 * OCTAS;
        let subject_fee = price * settings.subject_fee_percent / 1 * OCTAS;
        return price + protocol_fee + application_fee + subject_fee;
    }

    #[view]
    public fun get_sell_price_after_fee(key_subject: address, amount: u64) : u64 {
        let price = get_sell_price(key_subject, amount);
        let protocol_fee = price * settings.protocol_fee_percent / 1 * OCTAS;
        let application_fee = price * settings.application_fee_percent / 1 * OCTAS;
        let subject_fee = price * settings.subject_fee_percent / 1 * OCTAS;
        return price - protocol_fee - application_fee - subject_fee;
    }

    entry fun buy_keys(account: &signer, subject: address, amount: u64, application_fee_destination: address) acquires NameRecord, Settings {
        let record = borrow_global_mut<NameRecord>(subject);
        let account_addr = signer::signer_addr(account);
        assert!(record.supply > 0, 1);
        let price = get_price(record.key_supply, amount);
        let settings = borrow_global<Settings>(object_signer());
        let protocol_fee = price * settings.protocol_fee_percent / 1 * OCTAS;
        let application_fee = price * settings.application_fee_percent / 1 * OCTAS;
        let subject_fee = price * settings.subject_fee_percent / 1 * OCTAS;
        
        assert!(coin::transfer(account_addr, settings.protocol_fee_destination, protocol_fee), 2);
        if (application_fee_destination != 0) {
            assert!(coin::transfer(account_addr, application_fee_destination, application_fee), 3);
        } else {
            assert!(coin::transfer(account_addr, settings.protocol_fee_destination, application_fee), 3);
        }
        assert!(coin::transfer(account_addr, subject, subject_fee), 2);
        assert!(coin::transfer(account_addr, admin_address, price - protocol_fee - application_fee - subject_fee));
        record.key_supply = record.key_supply + amount;
        
        let constructor_ref = &object::create_named_object(&get_app_signer(), domain_name);
        let token_signer = object::generate_signer(&constructor_ref);
        let mint_ref = fungible_asset::generate_mint_ref(constructor_ref);
        fungible_asset::mint_to(&mint_ref, account_addr, amount);

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
                domain_amount: subject_fee,
                application_amount: application_fee,
                new_supply: record.key_supply,
           }  
       );  
    }

    entry fun sell_keys(account: &signer, subject: address, amount: u64, application_fee_destination: address) acquires NameRecord, Settings {
        let record = borrow_global_mut<NameRecord>(subject);
        let account_addr = signer::signer_addr(account);
        assert!(record.supply - amount > 0, 1);
        let price = get_price(record.key_supply - amount, amount);
        let settings = borrow_global<Settings>(object_signer());
        let protocol_fee = price * settings.protocol_fee_percent / 1 * OCTAS;
        let application_fee = price * settings.application_fee_percent / 1 * OCTAS;
        let subject_fee = price * settings.subject_fee_percent / 1 * OCTAS;
        
        let admin_address = settings.protocol_fee_destination;
        assert!(coin::transfer(admin_address, settings.protocol_fee_destination, protocol_fee), 2);
        if (application_fee_destination != 0) {
            assert!(coin::transfer(admin_address, application_fee_destination, application_fee), 3);
        } else {
            assert!(coin::transfer(admin_address, settings.protocol_fee_destination, application_fee), 3);
        }
        assert!(coin::transfer(admin_address, subject, subject_fee), 2);
        assert!(coin::transfer(account_addr, account_addr, price - protocol_fee - application_fee - subject_fee));

        record.key_supply = record.key_supply - amount;
        
        let constructor_ref = &object::create_named_object(&get_app_signer(), domain_name);
        let token_signer = object::generate_signer(&constructor_ref);
        let burn_ref = fungible_asset::generate_burn_ref(constructor_ref);
        fungible_asset::burn(&burn_ref, account_addr, amount);

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
                domain_amount: subject_fee,
                application_amount: application_fee,
                new_supply: record.key_supply,
           }  
       );  
    }
    
}
