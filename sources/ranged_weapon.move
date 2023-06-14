module aptos_arena::ranged_weapon {

    use std::string;
    use std::option;
    use std::signer;

    use aptos_std::smart_table::{Self, SmartTable};
    use aptos_std::string_utils;

    use aptos_framework::object::{Self, Object, TransferRef};

    use aptos_token_objects::collection;

    use aptos_arena::utils;
    use aptos_arena::aptos_arena;

    // errors

    /// player collection already initialized
    const EALREADY_INITIALIZED: u64 = 1;

    /// player collection not initialized
    const ENOT_INITIALIZED: u64 = 2;

    /// player has already claimed a token
    const EALREADY_CLAIMED: u64 = 3;

    /// invalid weapon unequip
    const EINVALID_WEAPON_UNEQUIP: u64 = 4;

    // constants

    const COLLECTION_NAME: vector<u8> = b"RANGED_WEAPON";
    const COLLECTION_DESCRIPTION: vector<u8> = b"Ranged weapon for Aptos Arena";
    const COLLECTION_BASE_URI: vector<u8> = b"https://aptosarcade.com/api/ranged/{}";

    const TOKEN_DESCRIPTION: vector<u8> = b"Ranged weapon for Aptos Arena";
    const TOKEN_NAME: vector<u8> = b"RANGED_WEAPON";

    const NUM_RANGED_WEAPONS: u64 = 5;

    struct RangedWeaponCollection has key {
        player_has_minted: SmartTable<address, bool>,
    }

    struct RangedWeapon has key {
        power: u64,
        type: u64,
        range: u64,
        transfer_ref: TransferRef
    }

    /// create the ranged weapon collection
    /// `deployer` - the transaction signer; must be the deployer
    public fun initialize(aptos_arena: &signer) {
        assert_collection_not_initialized();
        let constructor_ref = aptos_arena::create_collection(
            aptos_arena,
            string::utf8(COLLECTION_DESCRIPTION),
            string::utf8(COLLECTION_NAME),
            option::none(),
            string::utf8(COLLECTION_BASE_URI),
        );
        let object_signer = object::generate_signer(&constructor_ref);
        move_to(&object_signer, RangedWeaponCollection {
            player_has_minted: smart_table::new()
        });
    }

    // public functions

    public fun mint(player: &signer): Object<RangedWeapon> acquires RangedWeaponCollection {
        assert_collection_initialized();
        let player_address = signer::address_of(player);
        assert_player_has_not_claimed(player_address);
        let ranged_weapon_type = utils::rand_int(NUM_RANGED_WEAPONS) + 1;
        let constructor_ref = aptos_arena::mint_token_player(
            player,
            string::utf8(COLLECTION_NAME),
            string::utf8(TOKEN_DESCRIPTION),
            string::utf8(TOKEN_NAME),
            option::none(),
            string_utils::format1(&COLLECTION_BASE_URI, ranged_weapon_type),
            false
        );

        let token_signer = object::generate_signer(&constructor_ref);

        // create the ranged weapon struct and move it to the token signer
        let ranged_weapon = RangedWeapon {
            power: 0,
            type: ranged_weapon_type,
            range: 0,
            transfer_ref: object::generate_transfer_ref(&constructor_ref)
        };
        move_to(&token_signer, ranged_weapon);

        let object_address = signer::address_of(&token_signer);

        // update the ranged weapon collection
        let ranged_weapon_collection = borrow_global_mut<RangedWeaponCollection>(get_collection_address());
        smart_table::add(&mut ranged_weapon_collection.player_has_minted, player_address, true);

        let transfer_ref = object::generate_transfer_ref(&constructor_ref);
        object::enable_ungated_transfer(&transfer_ref);

        object::address_to_object<RangedWeapon>(object_address)
    }

    /// trnasfers `ranged_weapon` to `to`
    /// `ranged_weapon` - the ranged weapon to transfer
    /// `to` - the address to transfer to
    public fun transfer_ranged_weapon(ranged_weapon: &Object<RangedWeapon>, to: address) acquires RangedWeapon {
        let ranged_weapon_struct = borrow_global<RangedWeapon>(object::object_address(ranged_weapon));
        let linear_transfer_ref = object::generate_linear_transfer_ref(&ranged_weapon_struct.transfer_ref);
        object::transfer_with_ref(linear_transfer_ref, to);
    }

    // helper functions

    // view functions

    #[view]
    /// returns the address of the player collection
    public fun get_collection_address(): address {
        collection::create_collection_address(&aptos_arena::get_game_account_address(), &string::utf8(COLLECTION_NAME))
    }

    #[view]
    /// returns whether a player has minted a ranged weapon
    public fun has_player_minted(player: address): bool acquires RangedWeaponCollection {
        let ranged_weapon_collection = borrow_global<RangedWeaponCollection>(get_collection_address());
        smart_table::contains(&ranged_weapon_collection.player_has_minted, player)
    }

    #[view]
    /// returns the data of a ranged weapon
    public fun get_ranged_weapon_data(ranged_weapon_obj: Object<RangedWeapon>): (u64, u64) acquires RangedWeapon {
        let ranged_weapon = borrow_global<RangedWeapon>(object::object_address(&ranged_weapon_obj));
        (ranged_weapon.power, ranged_weapon.type)
    }

    // assert statements

    /// asserts that the player collection does not exist
    fun assert_collection_not_initialized() {
        assert!(!exists<RangedWeaponCollection>(get_collection_address()), EALREADY_INITIALIZED)
    }

    /// asserts that the player collection exists
    fun assert_collection_initialized() {
        assert!(exists<RangedWeaponCollection>(get_collection_address()), ENOT_INITIALIZED)
    }

    /// asserts that the player has not already claimed a token
    /// `player` - player address
    fun assert_player_has_not_claimed(player: address) acquires RangedWeaponCollection {
        assert!(!has_player_minted(player), EALREADY_CLAIMED);
    }

    // tests


    #[test_only]
    use aptos_framework::genesis;
    #[test_only]
    use aptos_framework::timestamp;
    #[test_only]
    use aptos_arcade::game_admin;

    #[test_only]
    fun setup_tests(aptos_arena: &signer) {
        genesis::setup();
        aptos_arena::initialize(aptos_arena);
    }

    #[test(aptos_arena = @aptos_arena)]
    fun test_initialize(aptos_arena: &signer) {
        setup_tests(aptos_arena);
        initialize(aptos_arena);
        assert_collection_initialized();
    }

    #[test(aptos_arena = @aptos_arena)]
    #[expected_failure(abort_code=EALREADY_INITIALIZED)]
    fun test_initialize_twice(aptos_arena: &signer) {
        setup_tests(aptos_arena);
        initialize(aptos_arena);
        initialize(aptos_arena);
    }

    #[test(aptos_arena = @aptos_arena, not_aptos_arena = @0x1)]
    #[expected_failure(abort_code=game_admin::ESIGNER_NOT_ADMIN)]
    fun test_initialize_not_deployer(aptos_arena: &signer, not_aptos_arena: &signer) {
        setup_tests(aptos_arena);
        initialize(not_aptos_arena);
    }

    #[test(aptos_arena = @aptos_arena, player = @0x5)]
    fun test_mint_ranged_weapon(aptos_arena: &signer, player: &signer) acquires RangedWeaponCollection, RangedWeapon {
        setup_tests(aptos_arena);
        initialize(aptos_arena);
        let ranged_weapon_obj = mint(player);
        assert!(exists<RangedWeapon>(object::object_address(&ranged_weapon_obj)), 0);
        let (
            power,
            type
        ) = get_ranged_weapon_data(ranged_weapon_obj);
        assert!(power == 0, 0);
        assert!(type == timestamp::now_seconds() % NUM_RANGED_WEAPONS + 1, 1);
    }

    #[test(aptos_arena = @aptos_arena, player = @0x5)]
    #[expected_failure(abort_code=EALREADY_CLAIMED)]
    fun test_mint_ranged_weapon_twice(aptos_arena: &signer, player: &signer) acquires RangedWeaponCollection {
        setup_tests(aptos_arena);
        initialize(aptos_arena);
        mint(player);
        mint(player);
    }

    #[test(aptos_arena = @aptos_arena, player = @0x5)]
    #[expected_failure(abort_code=ENOT_INITIALIZED)]
    fun test_mint_not_initialized(aptos_arena: &signer, player: &signer) acquires RangedWeaponCollection {
        setup_tests(aptos_arena);
        mint(player);
    }

    #[test(aptos_arena = @aptos_arena, player1 = @0x5, player2=@0x6)]
    fun test_transfer_ranged_weapon(aptos_arena: &signer, player1: &signer, player2: &signer)
    acquires RangedWeaponCollection, RangedWeapon {
        setup_tests(aptos_arena);
        initialize(aptos_arena);
        let ranged_weapon_obj = mint(player1);
        let player2_address = signer::address_of(player2);
        transfer_ranged_weapon(&ranged_weapon_obj, player2_address);
        assert!(object::is_owner(ranged_weapon_obj, player2_address), 0);
    }
}
