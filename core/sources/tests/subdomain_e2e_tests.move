#[test_only]
module movement_names::subdomain_e2e_tests {
    use aptos_framework::timestamp;
    use movement_names::domains;
    use movement_names::test_helper;
    use movement_names::test_utils;
    use std::option;
    use std::signer;
    use std::vector;
    use movement_names::config;

    const MAX_REMAINING_TIME_FOR_RENEWAL_SEC: u64 = 15552000;
    const SECONDS_PER_YEAR: u64 = 60 * 60 * 24 * 365;

    #[test(
        router_signer = @router_signer,
        movement_names = @movement_names,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    fun happy_path_e2e_test(
        router_signer: &signer,
        movement_names: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer,
    ) {
        let users = test_helper::e2e_test_setup(movement_names, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let rando = vector::borrow(&users, 1);

        let user_addr = signer::address_of(user);

        // Register the domain
        test_helper::register_name(router_signer, user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1);

        // Set an address and verify it
        test_helper::set_target_address(user, test_helper::domain_name(), option::none(), user_addr);

        // Ensure the owner can clear the address
        test_helper::clear_target_address(user, option::none(), test_helper::domain_name());

        // And also can clear if the user is the registered address, but not owner
        test_helper::set_target_address(user, test_helper::domain_name(), option::none(), signer::address_of(rando));
        test_helper::clear_target_address(rando, option::none(), test_helper::domain_name());

        // Set it back for following tests
        test_helper::set_target_address(user, test_helper::domain_name(), option::none(), user_addr);

        // Register a subdomain!
        test_helper::register_name(router_signer, user, option::some(test_helper::subdomain_name()), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_subdomain_name(), 1);

        // Set a subdomain address and verify it
        test_helper::set_target_address(user, test_helper::domain_name(), option::some(
            test_helper::subdomain_name()), user_addr);

        // Ensure these also work :-)
        test_helper::clear_target_address(user, option::some(test_helper::subdomain_name()), test_helper::domain_name());

        // And also can clear if is registered address, but not owner
        test_helper::set_target_address(user, test_helper::domain_name(), option::some(
            test_helper::subdomain_name()), signer::address_of(rando));
        test_helper::clear_target_address(rando, option::some(test_helper::subdomain_name()), test_helper::domain_name());
    }

    #[test(
        router_signer = @router_signer,
        movement_names = @movement_names,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    fun test_renew_domain_e2e(
        router_signer: &signer,
        movement_names: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer,
    ) {
        let users = test_helper::e2e_test_setup(movement_names, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);

        // Register the domain
        test_helper::register_name(router_signer, user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1);
        let expiration_time_sec = domains::get_expiration(test_helper::domain_name(), option::none());

        // Set the time is early than max remaining time for renewal from expiration time
        timestamp::update_global_time_for_test_secs(expiration_time_sec - MAX_REMAINING_TIME_FOR_RENEWAL_SEC - 5);
        assert!(!domains::is_domain_in_renewal_window(test_helper::domain_name()), 1);

        timestamp::update_global_time_for_test_secs(expiration_time_sec - MAX_REMAINING_TIME_FOR_RENEWAL_SEC + 5);
        assert!(domains::is_domain_in_renewal_window(test_helper::domain_name()), 2);

        // Renew the domain
        domains::renew_domain(user, test_helper::domain_name(), SECONDS_PER_YEAR);

        // Ensure the domain is still registered after the original expiration time
        timestamp::update_global_time_for_test_secs(expiration_time_sec + 5);
        assert!(domains::is_name_registered(test_helper::domain_name(), option::none()), 4);

        let new_expiration_time_sec = domains::get_expiration(test_helper::domain_name(), option::none());
        // Ensure the domain is still expired after the new expiration time
        timestamp::update_global_time_for_test_secs(new_expiration_time_sec + 5);
        assert!(domains::is_name_expired(test_helper::domain_name(), option::none()), 5);
    }

    #[test(
        router_signer = @router_signer,
        movement_names = @movement_names,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    #[expected_failure(abort_code = 131083, location = movement_names::domains)]
    fun test_register_subdomain_with_invalid_string(
        router_signer: &signer,
        movement_names: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer,
    ) {
        let users = test_helper::e2e_test_setup(movement_names, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);

        // Register the domain
        test_helper::register_name(router_signer, user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1);

        // Register a subdomain with an invalid string!
        test_helper::register_name(router_signer, user, option::some(test_helper::invalid_subdomain_name()), test_helper::domain_name(), timestamp::now_seconds() + test_helper::one_year_secs(), test_helper::fq_subdomain_name(), 1);

    }

    #[test(
        router_signer = @router_signer,
        movement_names = @movement_names,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    fun test_auto_renew_subdomain_e2e(
        router_signer: &signer,
        movement_names: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer,
    ) {
        let users = test_helper::e2e_test_setup(movement_names, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        // Register the domain
        test_helper::register_name(router_signer, user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1);

        // Register a subdomain!
        test_helper::register_name(router_signer, user, option::some(test_helper::subdomain_name()), test_helper::domain_name(), timestamp::now_seconds() + test_helper::one_year_secs(), test_helper::fq_subdomain_name(), 1);
        // The subdomain auto-renewal policy is true by default
        assert!(
            domains::get_subdomain_renewal_policy(test_helper::domain_name(), test_helper::subdomain_name()) == 0, 2);
        // The subdomain auto-renewal policy is set to auto_renew
        domains::set_subdomain_expiration_policy(user, test_helper::domain_name(), test_helper::subdomain_name(), 1);

        // Renew the domain (and the subdomain should be auto renewed)
        let original_expiration_time_sec = domains::get_expiration(test_helper::domain_name(), option::some(test_helper::subdomain_name()));
        timestamp::update_global_time_for_test_secs(original_expiration_time_sec - 5);
        domains::renew_domain(user, test_helper::domain_name(), SECONDS_PER_YEAR);
        // Set the time past the domain's expiration time
        timestamp::update_global_time_for_test_secs(original_expiration_time_sec + 5);
        // Both domain and subdomain are not expired
        assert!(!domains::is_name_expired(test_helper::domain_name(), option::none()), 80);
        assert!(!domains::is_name_expired(
            test_helper::domain_name(), option::some(test_helper::subdomain_name())), 80);
     }

    #[test(
        router_signer = @router_signer,
        movement_names = @movement_names,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    #[expected_failure(abort_code = 65562, location = movement_names::domains)]
    fun test_set_subdomain_expiration_policy(
        router_signer: &signer,
        movement_names: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer,
    ) {
        let users = test_helper::e2e_test_setup(movement_names, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        // Register the domain
        test_helper::register_name(router_signer, user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1);

        // Register a subdomain!
        test_helper::register_name(router_signer, user, option::some(test_helper::subdomain_name()), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_subdomain_name(), 1);
        assert!(
            domains::get_subdomain_renewal_policy(test_helper::domain_name(), test_helper::subdomain_name()) == 0, 2);
        // test set the policy to auto-renewal
        domains::set_subdomain_expiration_policy(user, test_helper::domain_name(), test_helper::subdomain_name(), 1);
        assert!(
            domains::get_subdomain_renewal_policy(test_helper::domain_name(), test_helper::subdomain_name()) == 1, 3);

        // test set the policy to something not exist
        domains::set_subdomain_expiration_policy(user, test_helper::domain_name(), test_helper::subdomain_name(), 100);
    }

    #[test(
        router_signer = @router_signer,
        movement_names = @movement_names,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    fun test_manual_renew_subdomain_e2e(
        router_signer: &signer,
        movement_names: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer,
    ) {
        let users = test_helper::e2e_test_setup(movement_names, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        // Register the domain
        test_helper::register_name(router_signer, user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1);

        // Register a subdomain!
        test_helper::register_name(router_signer, user, option::some(test_helper::subdomain_name()), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_subdomain_name(), 1);
        domains::set_subdomain_expiration_policy(user, test_helper::domain_name(), test_helper::subdomain_name(), 0);
        assert!(
            domains::get_subdomain_renewal_policy(test_helper::domain_name(), test_helper::subdomain_name()) == 0, 2);

        // Set the time past the domain's expiration time
        let expiration_time_sec = domains::get_expiration(test_helper::domain_name(), option::some(test_helper::subdomain_name()));
        // Renew the domain before it's expired
        timestamp::update_global_time_for_test_secs(expiration_time_sec - 5);
        domains::renew_domain(user, test_helper::domain_name(), SECONDS_PER_YEAR);
        // Set the time past the domain's expiration time
        timestamp::update_global_time_for_test_secs(expiration_time_sec + 5);
        // Ensure the subdomain is still expired after domain renewal
        assert!(!domains::is_name_expired(test_helper::domain_name(), option::none()), 80);
        assert!(
            domains::is_name_expired(test_helper::domain_name(), option::some(test_helper::subdomain_name())), 80);
    }

    #[test(
        router_signer = @router_signer,
        movement_names = @movement_names,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    fun test_admin_can_force_renew_subdomain_name(
        router_signer: &signer,
        movement_names: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer
    ) {
        let users = test_helper::e2e_test_setup(movement_names, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);

        // Register the domain
        test_helper::register_name(router_signer, user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1);

        // Register a subdomain!
        test_helper::register_name(router_signer, user, option::some(test_helper::subdomain_name()), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_subdomain_name(), 1);

        // renew the domain by admin outside of renewal window
        domains::force_set_name_expiration(movement_names, test_helper::domain_name(), option::some(
            test_helper::subdomain_name()), timestamp::now_seconds() + 2 * test_helper::one_year_secs());

        let expiration_time_sec = domains::get_expiration(test_helper::domain_name(), option::some(test_helper::subdomain_name()));
        assert!(
            expiration_time_sec / SECONDS_PER_YEAR == 2, expiration_time_sec / SECONDS_PER_YEAR);
    }

    #[test(
        router_signer = @router_signer,
        movement_names = @movement_names,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    fun test_transfer_subdomain(
        router_signer: &signer,
        movement_names: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer,
    ) {
        let users = test_helper::e2e_test_setup(movement_names, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let user_addr = signer::address_of(user);
        let rando = vector::borrow(&users, 1);
        let rando_addr = signer::address_of(rando);
        // create the domain
        test_helper::register_name(
            router_signer,
            user,
            option::none(),
            test_helper::domain_name(),
            test_helper::one_year_secs(),
            test_helper::fq_domain_name(),
            1
        );
        test_helper::register_name(
            router_signer,
            user,
            option::some(test_helper::subdomain_name()),
            test_helper::domain_name(),
            test_helper::one_year_secs(),
            test_helper::fq_domain_name(),
            1
        );

        // user is the owner of domain
        let is_owner = domains::is_token_owner(user_addr, test_helper::domain_name(), option::none());
        let is_expired = domains::is_name_expired(test_helper::domain_name(), option::none());
        assert!(is_owner && !is_expired, 1);

        // transfer the subdomain to rando
        domains::transfer_subdomain_owner(
            user,
            test_helper::domain_name(),
            test_helper::subdomain_name(),
            rando_addr,
            option::some(rando_addr)
        );

        // rando owns the subdomain
        let is_owner = domains::is_token_owner(
            rando_addr,
            test_helper::domain_name(),
            option::some(test_helper::subdomain_name())
        );
        let is_expired = domains::is_name_expired(
            test_helper::domain_name(),
            option::some(test_helper::subdomain_name())
        );
        assert!(is_owner && !is_expired, 2);

        {
            // when rando owns the subdomain and user owns the domain, user can still transfer the subdomain.
            domains::transfer_subdomain_owner(
                user,
                test_helper::domain_name(),
                test_helper::subdomain_name(),
                user_addr,
                option::some(user_addr)
            );
            let is_owner = domains::is_token_owner(
                user_addr,
                test_helper::domain_name(),
                option::some(test_helper::subdomain_name()),
            );
            assert!(is_owner, 1);
        }
    }

    #[test(
        router_signer = @router_signer,
        movement_names = @movement_names,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    #[expected_failure(abort_code = 327686, location = movement_names::domains)]
    fun test_non_domain_owner_transfer_subdomain(
        router_signer: &signer,
        movement_names: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer,
    ) {
        let users = test_helper::e2e_test_setup(movement_names, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let user_addr = signer::address_of(user);
        let rando = vector::borrow(&users, 1);
        let rando_addr = signer::address_of(rando);
        // create the domain
        test_helper::register_name(router_signer, user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1);
        test_helper::register_name(router_signer, user, option::some(test_helper::subdomain_name()), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1);

        // user is the owner of domain
        let is_owner = domains::is_token_owner(user_addr, test_helper::domain_name(), option::none());
        let is_expired = domains::is_name_expired(test_helper::domain_name(), option::none());
        assert!(is_owner && !is_expired, 1);

        // transfer the subdomain to rando
        domains::transfer_subdomain_owner(
            user,
            test_helper::domain_name(),
            test_helper::subdomain_name(),
            rando_addr,
            option::some(rando_addr)
        );

        {
            // when rando owns the subdomain but not the domain, rando can't transfer subdomain ownership.
            domains::transfer_subdomain_owner(
                rando,
                test_helper::domain_name(),
                test_helper::subdomain_name(),
                user_addr,
                option::some(user_addr)
            );
        }
    }

    #[test(
        router_signer = @router_signer,
        movement_names = @movement_names,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    #[expected_failure(abort_code = 196632, location = movement_names::domains)]
    fun test_set_expiration_date_for_subdomain(
        router_signer: &signer,
        movement_names: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer,
    ) {
        let users = test_helper::e2e_test_setup(movement_names, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        // Register the domain
        test_helper::register_name(router_signer, user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1);
        // Register a subdomain!
        test_helper::register_name(router_signer, user, option::some(test_helper::subdomain_name()), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_subdomain_name(), 1);
        // Set the auto-renewal flag as false
        domains::set_subdomain_expiration_policy(user, test_helper::domain_name(), test_helper::subdomain_name(), 0);

        domains::set_subdomain_expiration(user, test_helper::domain_name(), test_helper::subdomain_name(), timestamp::now_seconds() + 10);
        let domain_expiration_time_sec = domains::get_expiration(test_helper::domain_name(), option::none());

        // expect error when the expiration date pass the domain expiration date
        domains::set_subdomain_expiration(user, test_helper::domain_name(), test_helper::subdomain_name(), domain_expiration_time_sec + 5);
    }

    #[test(
        router_signer = @router_signer,
        movement_names = @movement_names,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    #[expected_failure(abort_code = 65561, location = movement_names::domains)]
    fun test_register_domain_less_than_a_year(
        router_signer: &signer,
        movement_names: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer,
    ) {
        let users = test_helper::e2e_test_setup(movement_names, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        // Register the domain
        test_helper::register_name(router_signer, user, option::none(), test_helper::domain_name(), 100, test_helper::fq_domain_name(), 1);
    }

    #[test(
        router_signer = @router_signer,
        movement_names = @movement_names,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    #[expected_failure(abort_code = 65561, location = movement_names::domains)]
    fun test_register_domain_duration_not_whole_years(
        router_signer: &signer,
        movement_names: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer,
    ) {
        let users = test_helper::e2e_test_setup(movement_names, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        // Register the domain
        test_helper::register_name(router_signer, user, option::none(), test_helper::domain_name(), test_helper::one_year_secs()+5, test_helper::fq_domain_name(), 1);
    }

    #[test(
        router_signer = @router_signer,
        movement_names = @movement_names,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    fun test_names_are_registerable_after_expiry_past_grace_e2e(
        router_signer: &signer,
        movement_names: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer,
    ) {
        let users = test_helper::e2e_test_setup(movement_names, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let rando = vector::borrow(&users, 1);

        // Register the domain
        test_helper::register_name(router_signer, user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1);

        // Register a subdomain!
        test_helper::register_name(router_signer, user, option::some(test_helper::subdomain_name()), test_helper::domain_name(), timestamp::now_seconds() + test_helper::one_year_secs(), test_helper::fq_subdomain_name(), 1);
        // Set the subdomain auto-renewal policy to false
        domains::set_subdomain_expiration_policy(user, test_helper::domain_name(), test_helper::subdomain_name(), 0);

        // Set the time past the domain's expiration time and past grace period
        let expiration_time_sec = domains::get_expiration(test_helper::domain_name(), option::some(test_helper::subdomain_name()));
        timestamp::update_global_time_for_test_secs(expiration_time_sec + config::reregistration_grace_sec() + 5);

        // The domain should now be: expired, registered, AND registerable
        assert!(domains::is_name_expired(test_helper::domain_name(), option::none()), 80);
        assert!(domains::is_name_registered(test_helper::domain_name(), option::none()), 81);
        assert!(domains::is_name_registerable(test_helper::domain_name(), option::none()), 82);

        // The subdomain now be: expired, registered, AND NOT registerable (because the domain is expired, too)
        assert!(
            domains::is_name_expired(test_helper::domain_name(), option::some(test_helper::subdomain_name())), 90);
        assert!(
            domains::is_name_registered(
                test_helper::domain_name(), option::some(test_helper::subdomain_name())), 91);
        assert!(!domains::is_name_registerable(
            test_helper::domain_name(), option::some(test_helper::subdomain_name())), 92);

        // Lets try to register it again, now that it is expired
        test_helper::register_name(router_signer, rando, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 2);
        // The subdomain should now be registerable: it's both expired AND the domain is registered
        assert!(
            domains::is_name_expired(test_helper::domain_name(), option::some(test_helper::subdomain_name())), 93);
        assert!(
            domains::is_name_registered(
                test_helper::domain_name(), option::some(test_helper::subdomain_name())), 94);
        assert!(
            domains::is_name_registerable(
                test_helper::domain_name(), option::some(test_helper::subdomain_name())), 95);

        // and likewise for the subdomain
        test_helper::register_name(router_signer, rando, option::some(test_helper::subdomain_name()), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_subdomain_name(), 2);

        // And again!
        let expiration_time_sec = domains::get_expiration(test_helper::domain_name(), option::some(test_helper::subdomain_name()));
        timestamp::update_global_time_for_test_secs(expiration_time_sec + config::reregistration_grace_sec() + 5);


        // The domain should now be: expired, registered, AND registerable
        assert!(domains::is_name_expired(test_helper::domain_name(), option::none()), 80);
        assert!(domains::is_name_registered(test_helper::domain_name(), option::none()), 81);
        assert!(domains::is_name_registerable(test_helper::domain_name(), option::none()), 82);

        // The subdomain now be: expired, registered, AND NOT registerable (because the domain is expired, too)
        assert!(
            domains::is_name_expired(test_helper::domain_name(), option::some(test_helper::subdomain_name())), 90);
        assert!(
            domains::is_name_registered(
                test_helper::domain_name(), option::some(test_helper::subdomain_name())), 91);
        assert!(!domains::is_name_registerable(
            test_helper::domain_name(), option::some(test_helper::subdomain_name())), 92);

        // Lets try to register it again, now that it is expired
        test_helper::register_name(router_signer, rando, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 3);
        // The subdomain should now be registerable: it's both expired AND the domain is registered
        assert!(
            domains::is_name_expired(test_helper::domain_name(), option::some(test_helper::subdomain_name())), 93);
        assert!(
            domains::is_name_registered(
                test_helper::domain_name(), option::some(test_helper::subdomain_name())), 94);
        assert!(
            domains::is_name_registerable(
                test_helper::domain_name(), option::some(test_helper::subdomain_name())), 95);

        // and likewise for the subdomain
        test_helper::register_name(router_signer, rando, option::some(test_helper::subdomain_name()), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_subdomain_name(), 3);
    }

    #[test(
        router_signer = @router_signer,
        movement_names = @movement_names,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    #[expected_failure(abort_code = 196611, location = movement_names::domains)]
    fun test_dont_allow_double_subdomain_registrations_e2e(
        router_signer: &signer,
        movement_names: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer,
    ) {
        let users = test_helper::e2e_test_setup(movement_names, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);

        // Register the domain
        test_helper::register_name(router_signer, user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1);
        // Try to register a subdomain twice (ensure we can't)
        test_helper::register_name(router_signer, user, option::some(test_helper::subdomain_name()), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_subdomain_name(), 1);
        test_helper::register_name(router_signer, user, option::some(test_helper::subdomain_name()), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_subdomain_name(), 1);
    }

    #[test(
        router_signer = @router_signer,
        movement_names = @movement_names,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    fun test_get_target_address_for_subdomain(
        router_signer: &signer,
        movement_names: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer,
    ) {
        let users = test_helper::e2e_test_setup(movement_names, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let user_addr = signer::address_of(user);

        // Register the domain
        test_helper::register_name(router_signer, user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1);
        // Register a subdomain!
        test_helper::register_name(router_signer, user, option::some(test_helper::subdomain_name()), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_subdomain_name(), 1);

        test_helper::set_target_address(user, test_helper::domain_name(),option::some(test_helper::subdomain_name()),  user_addr);
        let target_address = domains::get_target_address(test_helper::domain_name(), option::some(test_helper::subdomain_name()));
        assert!(target_address == option::some(user_addr), 2);

        timestamp::update_global_time_for_test_secs(test_helper::one_year_secs() + 5);
        let target_address = domains::get_target_address(test_helper::domain_name(), option::none());
        assert!(option::is_none(&target_address), 3);
    }

    #[test(
        router_signer = @router_signer,
        movement_names = @movement_names,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    fun test_get_expiration_sec_for_subdomain(
        router_signer: &signer,
        movement_names: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer,
    ) {
        let users = test_helper::e2e_test_setup(movement_names, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);

        // Register the domain
        test_helper::register_name(router_signer, user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1);

        // Register a subdomain!
        test_helper::register_name(router_signer, user, option::some(test_helper::subdomain_name()), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_subdomain_name(), 1);
        assert!(
            domains::get_subdomain_renewal_policy(test_helper::domain_name(), test_helper::subdomain_name()) == 0, 2);
        // set the subdomain's renewal policy to manual
        domains::set_subdomain_expiration_policy(user, test_helper::domain_name(), test_helper::subdomain_name(), 0);
        // set the subdomain's expiration date to now
        domains::set_subdomain_expiration(user, test_helper::domain_name(), test_helper::subdomain_name(), timestamp::now_seconds());
        // check that the subdomain's expiration date is now
        let expiration_time_sec = domains::get_expiration(test_helper::domain_name(), option::some(test_helper::subdomain_name()));
        assert!(expiration_time_sec == timestamp::now_seconds(), 3);

        // set the subdomain's renewal policy to auto renewal
        domains::set_subdomain_expiration_policy(user, test_helper::domain_name(), test_helper::subdomain_name(), 1);
        let expiration_time_sec = domains::get_expiration(test_helper::domain_name(), option::some(test_helper::subdomain_name()));
        let domain_expiration_time_sec = domains::get_expiration(test_helper::domain_name(), option::none());
        assert!(expiration_time_sec == domain_expiration_time_sec, 4);
    }

    #[test(
        router_signer = @router_signer,
        movement_names = @movement_names,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    #[expected_failure(abort_code = 327689, location = movement_names::domains)]
    fun test_dont_allow_rando_to_set_subdomain_address_e2e(
        router_signer: &signer,
        movement_names: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer,
    ) {
        let users = test_helper::e2e_test_setup(movement_names, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let rando = vector::borrow(&users, 1);

        // Register the domain and subdomain
        test_helper::register_name(router_signer, user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1);
        test_helper::register_name(router_signer, user, option::some(test_helper::subdomain_name()), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_subdomain_name(), 1);
        // Ensure we can't clear it as a rando. The expected target address doesn't matter as it won't get hit
        test_helper::set_target_address(rando, test_helper::domain_name(), option::some(
            test_helper::subdomain_name()), @movement_names);
    }

    #[test(
        router_signer = @router_signer,
        movement_names = @movement_names,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    #[expected_failure(abort_code = 327689, location = movement_names::domains)]
    fun test_dont_allow_rando_to_clear_subdomain_address_e2e(
        router_signer: &signer,
        movement_names: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer,
    ) {
        let users = test_helper::e2e_test_setup(movement_names, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let rando = vector::borrow(&users, 1);

        // Register the domain and subdomain
        test_helper::register_name(router_signer, user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1);
        test_helper::register_name(router_signer, user, option::some(test_helper::subdomain_name()), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_subdomain_name(), 1);
        test_helper::set_target_address(user, test_helper::domain_name(), option::some(
            test_helper::subdomain_name()), signer::address_of(user));
        // Ensure we can't clear it as a rando. The expected target address doesn't matter as it won't get hit
        test_helper::set_target_address(rando, test_helper::domain_name(), option::some(
            test_helper::subdomain_name()), @movement_names);
    }

    #[test(
        router_signer = @router_signer,
        movement_names = @movement_names,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    fun test_admin_can_force_set_subdomain_address_e2e(
        router_signer: &signer,
        movement_names: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer,
    ) {
        let users = test_helper::e2e_test_setup(movement_names, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let rando = vector::borrow(&users, 1);

        let rando_addr = signer::address_of(rando);

        // Register the domain
        test_helper::register_name(router_signer, user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1);
        test_helper::register_name(router_signer, user, option::some(test_helper::subdomain_name()), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_subdomain_name(), 1);

        domains::force_set_target_address(movement_names, test_helper::domain_name(), option::some(
            test_helper::subdomain_name()), rando_addr);
        let target_address = domains::get_target_address(test_helper::domain_name(), option::some(test_helper::subdomain_name()));
        test_utils::print_actual_expected(b"set_subdomain_address: ", target_address, option::some(rando_addr), false);
        assert!(target_address == option::some(rando_addr), 33);
    }

    #[test(
        router_signer = @router_signer,
        movement_names = @movement_names,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    #[expected_failure(abort_code = 327681, location = movement_names::config)]
    fun test_rando_cant_force_set_subdomain_address_e2e(
        router_signer: &signer,
        movement_names: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer,
    ) {
        let users = test_helper::e2e_test_setup(movement_names, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);

        let rando = vector::borrow(&users, 1);

        let rando_addr = signer::address_of(rando);

        // Register the domain and subdomain
        test_helper::register_name(router_signer, user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1);
        test_helper::register_name(router_signer, user, option::some(test_helper::subdomain_name()), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_subdomain_name(), 1);

        // Rando is not allowed to do this
        domains::force_set_target_address(rando, test_helper::domain_name(), option::some(
            test_helper::subdomain_name()), rando_addr);
    }

    #[test(
        router_signer = @router_signer,
        movement_names = @movement_names,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    fun test_admin_can_force_seize_subdomain_name_e2e(
        router_signer: &signer,
        movement_names: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer,
    ) {
        let users = test_helper::e2e_test_setup(movement_names, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);

        // Register the domain and subdomain
        test_helper::register_name(router_signer, user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1);
        test_helper::register_name(router_signer, user, option::some(test_helper::subdomain_name()), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_subdomain_name(), 1);
        let is_owner = domains::is_token_owner(signer::address_of(user), test_helper::domain_name(), option::some(
            test_helper::subdomain_name()));
        let is_expired = domains::is_name_expired(test_helper::domain_name(), option::some(
            test_helper::subdomain_name()));
        assert!(is_owner && !is_expired, 1);

        // Take the subdomain name for much longer than users are allowed to register it for
        domains::force_create_or_seize_name(movement_names, test_helper::domain_name(), option::some(
            test_helper::subdomain_name()), test_helper::one_year_secs());
        let is_owner = domains::is_token_owner(signer::address_of(movement_names), test_helper::domain_name(), option::some(
            test_helper::subdomain_name()));
        let is_expired = domains::is_name_expired(test_helper::domain_name(), option::some(
            test_helper::subdomain_name()));
        assert!(is_owner && !is_expired, 2);

        // Ensure the expiration_time_sec is set to the new far future value
        let expiration_time_sec = domains::get_expiration(test_helper::domain_name(), option::some(test_helper::subdomain_name()));
        assert!(
            expiration_time_sec / SECONDS_PER_YEAR == 1, expiration_time_sec / SECONDS_PER_YEAR);
    }

    #[test(
        router_signer = @router_signer,
        movement_names = @movement_names,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    fun test_admin_can_force_create_subdomain_name_e2e(
        router_signer: &signer,
        movement_names: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer,
    ) {
        let users = test_helper::e2e_test_setup(movement_names, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);

        // No subdomain is registered yet
        test_helper::register_name(router_signer, user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1);
        assert!(!domains::is_name_registered(
            test_helper::domain_name(), option::some(test_helper::subdomain_name())), 1);

        // Take the subdomain name
        domains::force_create_or_seize_name(movement_names, test_helper::domain_name(), option::some(
            test_helper::subdomain_name()), test_helper::one_year_secs());
        let is_owner = domains::is_token_owner(signer::address_of(movement_names), test_helper::domain_name(), option::some(
            test_helper::subdomain_name()));
        let is_expired = domains::is_name_expired(test_helper::domain_name(), option::some(
            test_helper::subdomain_name()));
        assert!(is_owner && !is_expired, 2);

        // Ensure the expiration_time_sec is set to the new far future value
        let expiration_time_sec = domains::get_expiration(test_helper::domain_name(), option::some(test_helper::subdomain_name()));
        assert!(
            expiration_time_sec / SECONDS_PER_YEAR == 1, expiration_time_sec / SECONDS_PER_YEAR);
    }

    #[test(
        router_signer = @router_signer,
        movement_names = @movement_names,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    #[expected_failure(abort_code = 131096, location = movement_names::domains)]
    fun test_admin_cant_force_create_subdomain_more_than_domain_time_e2e(
        router_signer: &signer,
        movement_names: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer,
    ) {
        let users = test_helper::e2e_test_setup(movement_names, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);

        // No subdomain is registered yet- domain is registered for 1 year
        test_helper::register_name(router_signer, user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1);
        assert!(!domains::is_name_registered(
            test_helper::domain_name(), option::some(test_helper::subdomain_name())), 1);

        // Take the subdomain name for longer than domain: this should explode
        domains::force_create_or_seize_name(movement_names, test_helper::domain_name(), option::some(
            test_helper::subdomain_name()), test_helper::one_year_secs() + 1);
    }

    #[test(
        router_signer = @router_signer,
        movement_names = @movement_names,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    #[expected_failure(abort_code = 327681, location = movement_names::config)]
    fun test_rando_cant_force_seize_subdomain_name_e2e(
        router_signer: &signer,
        movement_names: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer,
    ) {
        let users = test_helper::e2e_test_setup(movement_names, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let rando = vector::borrow(&users, 1);

        // Register the domain and subdomain
        test_helper::register_name(router_signer, user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1);
        test_helper::register_name(router_signer, user, option::some(test_helper::subdomain_name()), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_subdomain_name(), 1);
        let is_owner = domains::is_token_owner(signer::address_of(user), test_helper::domain_name(), option::some(
            test_helper::subdomain_name()));
        let is_expired = domains::is_name_expired(test_helper::domain_name(), option::some(
            test_helper::subdomain_name()));
        assert!(is_owner && !is_expired, 1);

        // Attempt (and fail) to take the subdomain name for much longer than users are allowed to register it for
        domains::force_create_or_seize_name(rando, test_helper::domain_name(), option::some(
            test_helper::subdomain_name()), test_helper::two_hundred_year_secs());
    }

    #[test(
        router_signer = @router_signer,
        movement_names = @movement_names,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    #[expected_failure(abort_code = 327681, location = movement_names::config)]
    fun test_rando_cant_force_create_subdomain_name_e2e(
        router_signer: &signer,
        movement_names: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer,
    ) {
        let users = test_helper::e2e_test_setup(movement_names, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let rando = vector::borrow(&users, 1);

        // Register a domain, and ensure no subdomain is registered yet
        test_helper::register_name(router_signer, user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1);
        assert!(!domains::is_name_registered(
            test_helper::domain_name(), option::some(test_helper::subdomain_name())), 1);

        // Attempt (and fail) to take the subdomain name for much longer than users are allowed to register it for
        domains::force_create_or_seize_name(rando, test_helper::domain_name(), option::some(
            test_helper::subdomain_name()), test_helper::two_hundred_year_secs());
    }

    #[test(
        router_signer = @router_signer,
        movement_names = @movement_names,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    fun test_subdomain_reset(
        router_signer: &signer,
        movement_names: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer,
    ) {
        let users = test_helper::e2e_test_setup(movement_names, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let user_addr = signer::address_of(user);

        // Register the domain
        test_helper::register_name(
            router_signer,
            user,
            option::none(),
            test_helper::domain_name(),
            test_helper::one_year_secs(),
            test_helper::fq_domain_name(),
            1
        );

        // Register a subdomain!
        test_helper::register_name(
            router_signer,
            user,
            option::some(test_helper::subdomain_name()),
            test_helper::domain_name(),
            test_helper::one_year_secs(),
            test_helper::fq_subdomain_name(),
            1
        );
        assert!(!domains::is_name_expired(
            test_helper::domain_name(), option::some(test_helper::subdomain_name())), 1);

        // Let the domain expire and re-register it
        timestamp::update_global_time_for_test_secs(SECONDS_PER_YEAR * 2);
        test_helper::register_name(
            router_signer,
            user,
            option::none(),
            test_helper::domain_name(),
            test_helper::one_year_secs(),
            test_helper::fq_domain_name(),
            2
        );

        // The subdomain should be clear (expired, no target addr, no owner)
        {
            assert!(domains::is_name_expired(
                test_helper::domain_name(), option::some(test_helper::subdomain_name())), 3);
            let owner_addr = domains::get_name_owner_addr(
                option::some(test_helper::subdomain_name()), test_helper::domain_name());
            assert!(owner_addr == option::none(), 4);
            let target_addr = domains::get_target_address(test_helper::domain_name(), option::some(test_helper::subdomain_name()));
            assert!(target_addr == option::none(), 5);
        };

        // Even if the admin force changes the expiration time, the subdomain should still be clear
        domains::force_set_name_expiration(
            movement_names,
            test_helper::domain_name(),
            option::some(test_helper::subdomain_name()),
            timestamp::now_seconds() + test_helper::one_year_secs()
        );
        {
            assert!(domains::is_name_expired(
                test_helper::domain_name(), option::some(test_helper::subdomain_name())), 3);
            let owner_addr = domains::get_name_owner_addr(
                option::some(test_helper::subdomain_name()), test_helper::domain_name());
            assert!(owner_addr == option::none(), 4);
            let target_addr = domains::get_target_address(test_helper::domain_name(), option::some(test_helper::subdomain_name()));
            assert!(target_addr == option::none(), 5);
        };

        // The subdomain can be re-registered
        test_helper::register_name(
            router_signer,
            user,
            option::some(test_helper::subdomain_name()),
            test_helper::domain_name(),
            test_helper::one_year_secs(),
            test_helper::fq_subdomain_name(),
            3
        );
        {
            assert!(!domains::is_name_expired(
                test_helper::domain_name(), option::some(test_helper::subdomain_name())), 3);
            let owner_addr = domains::get_name_owner_addr(
                option::some(test_helper::subdomain_name()), test_helper::domain_name());
            assert!(*option::borrow(&owner_addr) == user_addr, 4);
        };
    }
}
