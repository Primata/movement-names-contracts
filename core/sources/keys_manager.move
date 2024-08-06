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
        protocolFeeDestination : address,
        applicationFeePercent : u64,
        protocolFeePercent : u64,
        subjectFeePercent : u64,
    }

    #[event]
    struct Trade {
        trader: address,
        domain: address,
        appliaction: address,
        isBuy: bool,
        keyAmount: u64,
        moveAmount: u64,
        protocolAmount: u64,
        domainAmount: u64,
        protocolAmount: u64,
        newSupply: u64,
    }

    fun init_module(admin: &signer) {
        let settings = Settings {
            protocolFeeDestination: signer::address_of(admin),
            applicationFeePercent: 300,
            protocolFeePercent: 10,
            subjectFeePercent: 500,
        };
        let admin_address = signer::address_of(admin);
        let constructor_ref = object::create_object(admin_address);
        let object_signer = object::generate_signer(constructor_ref);
    }
}
