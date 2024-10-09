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
        let subject_fee = price * config::subject_fee_percent() / 1 * OCTAS;
        return price + protocol_fee + application_fee + subject_fee;
    }

    #[view]
    public fun get_sell_price_after_fee(key_subject: address, amount: u64) : u64 {
        let price = get_sell_price(key_subject, amount);
        let protocol_fee = price * settings.protocol_fee_percent / 1 * OCTAS;
        let application_fee = price * settings.application_fee_percent / 1 * OCTAS;
        let subject_fee = price * config::subject_fee_percent() / 1 * OCTAS;
        return price - protocol_fee - application_fee - subject_fee;
    }

    entry fun buy_keys(subject_key: address, amount: u64) acquires NameRecord, Settings {
        let record = borrow_global_mut<NameRecord>(subject_key);
        // TODO: handle initial supply
        assert!(record.supply > 0, 1);
        let price = get_price(record.key_supply, amount);
        let settings = borrow_global<Settings>(object_signer());
        let protocol_fee = price * settings.protocol_fee_percent / 1 * OCTAS;
        let application_fee = price * settings.application_fee_percent / 1 * OCTAS;
        let subject_fee = price * config::subject_fee_percent() / 1 * OCTAS;

        // TODO: handle price
        assert!(coin::transfer_from(sender, settings.protocol_fee_destination, protocol_fee), 2);
        record.key_supply += amount;

    }
    
}
