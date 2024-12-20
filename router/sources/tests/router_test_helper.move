#[test_only]
module router::router_test_helper {
    use aptos_framework::account;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin;
    use aptos_framework::timestamp;
    use std::signer;
    use std::vector;

    // Ammount to mint to test accounts during the e2e tests
    const MINT_AMOUNT_APT: u64 = 500;
    const OCTAS: u64 = 100000000;
    const ONE_MONTH_IN_SECONDS: u64 = 2_592_000;

    // 500 APT
    public fun mint_amount(): u64 {
        MINT_AMOUNT_APT * OCTAS
    }

    /// Sets up test by initializing MNS v2
    public fun e2e_test_setup(
        movement_names: &signer,
        movement_names: &signer,
        user: signer,
        aptos: &signer,
        rando: signer,
        foundation: &signer
    ): vector<signer> {
        account::create_account_for_test(@movement_names);
        if (movement_names != movement_names) {
            account::create_account_for_test(@movement_names);
        };
        let new_accounts = setup_and_fund_accounts(aptos, foundation, vector[user, rando]);
        timestamp::set_time_has_started_for_testing(aptos);
        movement_names::domains::init_module_for_test(movement_names);
        movement_names::domains::init_module_for_test(movement_names);
        movement_names::config::set_fund_destination_address_test_only(signer::address_of(foundation));
        movement_names::config::set_reregistration_grace_sec(movement_names, ONE_MONTH_IN_SECONDS);
        movement_names::config::set_fund_destination_address_test_only(signer::address_of(foundation));
        movement_names::config::set_reregistration_grace_sec(movement_names, ONE_MONTH_IN_SECONDS);
        new_accounts
    }

    public fun setup_and_fund_accounts(aptos: &signer, foundation: &signer, users: vector<signer>): vector<signer> {
        let (burn_cap, mint_cap) = aptos_framework::aptos_coin::initialize_for_test(aptos);

        let len = vector::length(&users);
        let i = 0;
        while (i < len) {
            let user = vector::borrow(&users, i);
            let user_addr = signer::address_of(user);
            account::create_account_for_test(user_addr);
            coin::register<AptosCoin>(user);
            coin::deposit(user_addr, coin::mint<AptosCoin>(mint_amount(), &mint_cap));
            assert!(coin::balance<AptosCoin>(user_addr) == mint_amount(), 1);
            i = i + 1;
        };

        account::create_account_for_test(signer::address_of(foundation));
        coin::register<AptosCoin>(foundation);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
        users
    }
}
