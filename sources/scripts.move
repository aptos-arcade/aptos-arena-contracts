module aptos_arena::scripts {

    use std::signer;
    use std::string::String;

    use aptos_framework::object::Object;

    use aptos_token::token;

    use aptos_arena::game_admin;
    use aptos_arena::player;
    use aptos_arena::melee_weapon::{Self, MeleeWeapon};
    use aptos_arena::ranged_weapon::{Self, RangedWeapon};

    #[test_only]
    use aptos_framework::genesis;
    #[test_only]
    use aptos_arena::player::{unequip_melee_weapon, unequip_character};
    #[test_only]
    use std::vector;
    #[test_only]
    use std::string;
    #[test_only]
    use aptos_framework::account;
    #[test_only]
    use aptos_framework::object;

    const TEST_COLLECTION_NAME: vector<u8> = b"TEST_COLLECTION";
    const TEST_COLLECTION_DESCRIPTION: vector<u8> = b"TEST_COLLECTION_DESCRIPTION";
    const TEST_COLLECTION_URI: vector<u8> = b"TEST_COLLECTION_URI";

    const TEST_TOKEN_NAME: vector<u8> = b"TEST_TOKEN_NAME";
    const TEST_TOKEN_DESCRIPTION: vector<u8> = b"TEST_TOKEN_DESCRIPTION";
    const TEST_TOKEN_URI: vector<u8> = b"TEST_TOKEN_URI";

    /// initialize all of the modules
    /// aptos_arena - the deployer of the package
    public entry fun initialize(aptos_arena: &signer) {
        game_admin::initialize(aptos_arena);
        player::initialize(aptos_arena);
        melee_weapon::initialize(aptos_arena);
        ranged_weapon::initialize(aptos_arena);
    }

    /// mint a player
    /// player - the player to mint
    public entry fun mint_player(player: &signer) {
        player::mint_player(player);
    }

    /// mint a melee weapon
    /// player - the player to mint the weapon for
    public entry fun mint_melee_weapon(player: &signer) {
        melee_weapon::mint(player);
    }

    /// equip a melee weapon
    /// player - the player to equip the weapon for
    /// weapon - the weapon to equip
    public entry fun equip_melee_weapon(player: &signer, weapon: Object<MeleeWeapon>) {
        let (_, type) = player::get_player_melee_weapon(signer::address_of(player));
        if(type != 0)
        {
            player::unequip_melee_weapon(player);
        };
        player::equip_melee_weapon(player, weapon);
    }

    /// mint a melee weapon and equip it
    /// player - the player to mint the weapon for
    public entry fun mint_and_equip_melee_weapon(player: &signer) {
        let weapon = melee_weapon::mint(player);
        player::equip_melee_weapon(player, weapon);
    }

    /// mint a ranged weapon
    /// player - the player to mint the weapon for
    public entry fun mint_ranged_weapon(player: &signer) {
        ranged_weapon::mint(player);
    }

    /// equip a ranged weapon
    /// player - the player to equip the weapon for
    /// weapon - the weapon to equip
    public entry fun equip_ranged_weapon(player: &signer, weapon: Object<RangedWeapon>) {
        let (_, type) = player::get_player_ranged_weapon(signer::address_of(player));
        if(type != 0)
        {
            player::unequip_ranged_weapon(player);
        };
        player::equip_ranged_weapon(player, weapon);
    }

    /// unequip a ranged weapon
    /// player - the player to unequip the weapon for
    /// weapon - the weapon to unequip
    public entry fun unequip_ranged_weapon(player: &signer) {
        player::unequip_ranged_weapon(player);
    }

    /// mint a ranged weapon and equip it
    /// player - the player to mint the weapon for
    public entry fun mint_and_equip_ranged_weapon(player: &signer) {
        let weapon = ranged_weapon::mint(player);
        player::equip_ranged_weapon(player, weapon);
    }

    /// equip a character
    /// player - the player to equip the character for
    /// creator - the creator of the character
    /// collection - the collection of the character
    /// name - the name of the character
    /// property_version - the property version of the character
    public entry fun equip_character(
        player: &signer,
        creator: address,
        collection: String,
        name: String,
        property_version: u64
    ) {
        let token_id = token::create_token_id_raw(creator, collection, name, property_version);
        player::equip_character(player, token_id);
    }

    #[test_only]
    fun create_collection_and_transfer(from: &signer, to: &signer)
    {
        let collection_mutability_setting = vector<bool>[true, true, true];
        let token_mutability_setting = vector<bool>[true, true, true, true, true];

        token::create_collection(
            from,
            string::utf8(TEST_COLLECTION_NAME),
            string::utf8(TEST_COLLECTION_DESCRIPTION),
            string::utf8(TEST_COLLECTION_URI),
            1,
            collection_mutability_setting,
        );

        token::opt_in_direct_transfer(to, true);

        let from_address = signer::address_of(from);

        token::create_token_script(
            from,
            string::utf8(TEST_COLLECTION_NAME),
            string::utf8(TEST_TOKEN_NAME),
            string::utf8(TEST_TOKEN_DESCRIPTION),
            1,
            1,
            string::utf8(TEST_TOKEN_URI),
            from_address,
            0,
            0,
            token_mutability_setting,
            vector::empty(),
            vector::empty(),
            vector::empty(),
        );

        token::direct_transfer_script(
            from,
            to,
            from_address,
            string::utf8(TEST_COLLECTION_NAME),
            string::utf8(TEST_TOKEN_NAME),
            0,
            1
        );
    }

    #[test(aptos_arena = @aptos_arena, player = @0x50)]
    fun e2e_tests(aptos_arena: &signer, player: &signer) {
        genesis::setup();

        account::create_account_for_test(signer::address_of(aptos_arena));
        account::create_account_for_test(signer::address_of(player));

        initialize(aptos_arena);
        mint_player(player);

        let melee_weapon = melee_weapon::mint(player);
        let (expected_melee_power, expected_melee_type) = melee_weapon::get_melee_weapon_data(melee_weapon);
        equip_melee_weapon(player, melee_weapon);
        let (actual_melee_power, actual_melee_type) = player::get_player_melee_weapon(signer::address_of(player));
        assert!(expected_melee_power == actual_melee_power, 0);
        assert!(expected_melee_type == actual_melee_type, 0);
        unequip_melee_weapon(player);

        let ranged_weapon = ranged_weapon::mint(player);
        let (expected_ranged_power, expected_ranged_type) = ranged_weapon::get_ranged_weapon_data(ranged_weapon);
        equip_ranged_weapon(player, ranged_weapon);
        let (actual_ranged_power, actual_ranged_type) = player::get_player_ranged_weapon(signer::address_of(player));
        assert!(expected_ranged_power == actual_ranged_power, 0);
        assert!(expected_ranged_type == actual_ranged_type, 0);
        unequip_ranged_weapon(player);

        create_collection_and_transfer(aptos_arena, player);

        let (creator_address, collection_name, token_name) = player::get_player_character(signer::address_of(player));
        assert!(creator_address == @0x0, 0);
        assert!(collection_name == string::utf8(b""), 0);
        assert!(token_name == string::utf8(b""), 0);

        equip_character(
            player,
            signer::address_of(aptos_arena),
            string::utf8(TEST_COLLECTION_NAME),
            string::utf8(TEST_TOKEN_NAME),
            0
        );

        let (creator_address, collection_name, token_name) = player::get_player_character(signer::address_of(player));
        assert!(creator_address == signer::address_of(aptos_arena), 0);
        assert!(collection_name == string::utf8(TEST_COLLECTION_NAME), 0);
        assert!(token_name == string::utf8(TEST_TOKEN_NAME), 0);

        unequip_character(player);
    }

    #[test(aptos_arena = @aptos_arena, player = @0x50)]
    fun test_mint_and_equip(aptos_arena: &signer, player: &signer) {
        genesis::setup();
        initialize(aptos_arena);

        mint_player(player);

        mint_and_equip_melee_weapon(player);

        mint_and_equip_ranged_weapon(player);
    }

    #[test(aptos_arena = @aptos_arena, player = @0x50)]
    fun test_mint_entry_functions(aptos_arena: &signer, player: &signer) {
        genesis::setup();
        initialize(aptos_arena);

        mint_player(player);

        mint_melee_weapon(player);

        mint_ranged_weapon(player);
    }

    #[test(aptos_arena = @aptos_arena, player = @0x50, player2 = @0x51)]
    #[expected_failure(abort_code=player::EINVALID_CHARACTER_TOKEN)]
    fun test_equip_invalid_character(aptos_arena: &signer, player: &signer, player2: &signer) {
        genesis::setup();
        initialize(aptos_arena);

        account::create_account_for_test(signer::address_of(aptos_arena));
        account::create_account_for_test(signer::address_of(player));
        account::create_account_for_test(signer::address_of(player2));

        mint_player(player);

        create_collection_and_transfer(aptos_arena, player);

        mint_player(player2);

        equip_character(
            player,
            signer::address_of(player2),
            string::utf8(TEST_COLLECTION_NAME),
            string::utf8(TEST_TOKEN_NAME),
            0
        );
    }

    #[test(aptos_arena = @aptos_arena, player = @0x50, player2 = @0x51)]
    fun test_equip_after_equipped(aptos_arena: &signer, player: &signer, player2: &signer)
    {
        genesis::setup();
        initialize(aptos_arena);

        mint_player(player);
        mint_player(player2);

        let melee_weapon1 = melee_weapon::mint(player);
        let melee_weapon2 = melee_weapon::mint(player2);
        equip_melee_weapon(player, melee_weapon1);
        object::transfer(player2, melee_weapon2, signer::address_of(player));
        equip_melee_weapon(player, melee_weapon2);

        let ranged_weapon1 = ranged_weapon::mint(player);
        let ranged_weapon2 = ranged_weapon::mint(player2);
        equip_ranged_weapon(player, ranged_weapon1);
        object::transfer(player2, ranged_weapon2, signer::address_of(player));
        equip_ranged_weapon(player, ranged_weapon2);
    }

}
