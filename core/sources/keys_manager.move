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
    }
    #[view]
    fun get_price(supply: u64, amount: u64) : u64 {
        sum1 = supply == 0 ? 0 : (supply - 1) * supply * (2 * (supply - 1) + 1) / 6;
        sum2 = supply == 0 && amount == 1 ? 0 : (supply - 1 + amount) * (supply + amount) * (2 * (supply - 1 + amount) + 1) / 6;
        return (sum2 - sum1) * 1 octas / 16000;
    }

    #[view]
    fun get_buy_price(key_subject: address, amount: u64) : u64 {
        let supply = borrow_global<domains::NameRecord>(key_subject).keySupply;
        return get_price(supply, amount);
    }

    #[view]
    fun get_sell_price(key_subject: address, amount: u64) : u64 {
        let supply = borrow_global<domains::NameRecord>(key_subject).keySupply;
        return get_price(supply - amount, amount);
    }

    fun get_buy_price_after_fee(key_subject: address, amount: u64) : u64 {
        let price = get_buy_price(key_subject, amount);
        protocol_fee = price * config::protocol_fee_percent() / 1 octas;
        application_fee = price * config::application_fee_percent() / 1 octas;
    }

    #[view]
    fun get_sell_price_after_fee(key_subject: address, amount: u64) : u64 {
        let price = get_sell_price(key_subject, amount);
        return price * (10000 - config::subject_fee_percent()) / 10000;
    }

    
}
