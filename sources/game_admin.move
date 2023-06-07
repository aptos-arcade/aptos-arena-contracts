module aptos_arena::game_admin {

    use std::signer;

    use aptos_framework::account::{Self, SignerCapability};

    // friend modules

    friend aptos_arena::player;
    friend aptos_arena::melee_weapon;
    friend aptos_arena::ranged_weapon;

    // error codes

    /// non-deployer account tries to initialize the creator resource account
    const ENOT_DEPLOYER: u64 = 1;

    /// creator resource account already initialized
    const EALREADY_INITIALIZED: u64 = 2;

    /// creator resource account not initialized
    const ENOT_INITIALIZED: u64 = 3;

    // constants

    /// seed for the creator resource account
    const ACCOUNT_SEED: vector<u8> = b"Aptos Arena";

    // structs

    /// holds the signer capability of the creator resource account
    struct AdminAccount has key {
        /// signer capability of the creator resource account
        signer_cap: SignerCapability
    }

    /// creates the creator resource account and stores the signer capability
    /// `deployer` - signer of the transaction; must be the deployer of the package
    public entry fun initialize(deployer: &signer) {
        assert_signer_is_deployer(deployer);
        assert_not_initialized();
        let (_, signer_cap) = account::create_resource_account(deployer, ACCOUNT_SEED);
        move_to(deployer, AdminAccount {
            signer_cap
        });
    }

    public(friend) fun get_signer(): signer acquires AdminAccount {
        assert_initialized();
        let admin_account = borrow_global<AdminAccount>(@aptos_arena);
        account::create_signer_with_capability(&admin_account.signer_cap)
    }

    // view functions

    #[view]
    public fun get_creator_address(): address acquires AdminAccount {
        assert_initialized();
        account::get_signer_capability_address(&borrow_global<AdminAccount>(@aptos_arena).signer_cap)
    }

    // asserts

    /// asserts that the `deployer` signer is the deployer of the package
    /// `deployer` - signer of the transaction
    public fun assert_signer_is_deployer(deployer: &signer) {
        assert!(signer::address_of(deployer) == @aptos_arena, ENOT_DEPLOYER)
    }

    /// asserts that the creator resource account is not initialized
    fun assert_not_initialized() {
        assert!(!exists<AdminAccount>(@aptos_arena), EALREADY_INITIALIZED)
    }

    /// asserts that the creator resource account is initialized
    fun assert_initialized() {
        assert!(exists<AdminAccount>(@aptos_arena), ENOT_INITIALIZED)
    }

    // tests

    #[test(aptos_arena = @aptos_arena)]
    fun test_initialize(aptos_arena: &signer) {
        initialize(aptos_arena);
        assert_initialized();
    }

    #[test(aptos_arena = @aptos_arena)]
    #[expected_failure(abort_code = EALREADY_INITIALIZED)]
    fun test_initialize_twice(aptos_arena: &signer) {
        initialize(aptos_arena);
        assert_initialized();
        initialize(aptos_arena);
    }

    #[test(not_aptos_arena = @0x1)]
    #[expected_failure(abort_code = ENOT_DEPLOYER)]
    fun test_initialize_not_deployer(not_aptos_arena: &signer) {
        initialize(not_aptos_arena);
    }

    #[test(aptos_arena = @aptos_arena)]
    fun test_get_signer(aptos_arena: &signer) acquires AdminAccount {
        initialize(aptos_arena);
        assert!(signer::address_of(&get_signer()) == account::create_resource_address(&@aptos_arena, ACCOUNT_SEED), 0);
    }

    #[test]
    #[expected_failure(abort_code = ENOT_INITIALIZED)]
    fun test_get_signer_not_initialized() acquires AdminAccount {
        get_signer();
    }

    #[test(aptos_arena = @aptos_arena)]
    fun test_get_creator_address(aptos_arena: &signer) acquires AdminAccount {
        initialize(aptos_arena);
        assert!(get_creator_address() == account::create_resource_address(&@aptos_arena, ACCOUNT_SEED), 0);
    }

    #[test]
    #[expected_failure(abort_code = ENOT_INITIALIZED)]
    fun test_get_creator_address_not_initialized() acquires AdminAccount {
        get_creator_address();
    }
}
