module aptos_arena::player {

    use std::string::{Self, String};
    use std::option::{Self, Option};
    use std::signer;

    use aptos_std::smart_table::{Self, SmartTable};
    use aptos_std::string_utils;

    use aptos_framework::object::{Self, Object};

    use aptos_token::token::{Self as token_v1, TokenDataId, TokenId};

    use aptos_token_objects::collection::{Self};
    use aptos_token_objects::token;

    use aptos_arena::game_admin;
    use aptos_arena::melee_weapon::{Self, MeleeWeapon};
    use aptos_arena::ranged_weapon::{Self, RangedWeapon};

    // errors

    /// player collection already initialized
    const EALREADY_INITIALIZED: u64 = 1;

    /// player collection not initialized
    const ENOT_INITIALIZED: u64 = 2;

    /// player has already claimed a token
    const EALREADY_CLAIMED: u64 = 3;

    /// invalid weapon unequip
    const EINVALID_WEAPON_UNEQUIP: u64 = 4;

    /// invalid character token
    const EINVALID_CHARACTER_TOKEN: u64 = 5;

    // constants

    const COLLECTION_NAME: vector<u8> = b"Player";
    const COLLECTION_DESCRIPTION: vector<u8> = b"Represents a player in Aptos Arena, moddable with a melee weapon, ranged weapon, and armour";
    const COLLECTION_URI: vector<u8> = b"https://aptosarena.com";

    const TOKEN_NAME_PREFIX: vector<u8> = b"Player ";
    const TOKEN_DESCRIPTION: vector<u8> = b"Player";
    const TOKEN_BASE_URI: vector<u8> = b"https://aptosarena.com/player/";

    // structs

    struct PlayerCollection has key {
        player_token_mapping: SmartTable<address, address>
    }

    struct Player has key {
        character: Option<TokenDataId>,
        melee_weapon: Option<Object<MeleeWeapon>>,
        ranged_weapon: Option<Object<RangedWeapon>>,
        wins: u64,
        losses: u64,
    }

    // entry functions

    /// initializes the player collection under the creator resource account
    /// `deployer` - signer of the transaction; must be the package deployer
    public fun initialize(deployer: &signer) {
        game_admin::assert_signer_is_deployer(deployer);
        assert_collection_not_initialized();
        let creator = game_admin::get_signer();
        let constructor_ref = collection::create_unlimited_collection(
            &creator,
            string::utf8(COLLECTION_DESCRIPTION),
            string::utf8(COLLECTION_NAME),
            option::none(),
            string::utf8(COLLECTION_URI)
        );
        let object_signer = object::generate_signer(&constructor_ref);
        move_to(&object_signer, PlayerCollection {
            player_token_mapping: smart_table::new()
        });
    }

    /// mints a player token for the given player
    /// `player` - signer of the transaction; only one mint per account
    public fun mint_player(player: &signer) acquires PlayerCollection {
        let player_address = signer::address_of(player);
        assert_player_has_not_claimed(player_address);
        let creator = game_admin::get_signer();
        let constructor_ref = token::create_from_account(
            &creator,
            string::utf8(COLLECTION_NAME),
            string::utf8(TOKEN_DESCRIPTION),
            string_utils::to_string_with_canonical_addresses(&player_address),
            option::none(),
            string::utf8(TOKEN_BASE_URI),
        );

        let object_signer = object::generate_signer(&constructor_ref);

        // create player object and move to token
        let aptos_token = Player {
            character: option::none(),
            melee_weapon: option::none(),
            ranged_weapon: option::none(),
            wins: 0,
            losses: 0,
        };
        move_to(&object_signer, aptos_token);

        // update player token mapping
        let player_collection = borrow_global_mut<PlayerCollection>(get_collection_address());
        smart_table::add(&mut player_collection.player_token_mapping, player_address, signer::address_of(&object_signer));

        // issue to player and disable transfer
        let transfer_ref = object::generate_transfer_ref(&constructor_ref);
        let linear_transfer_ref = object::generate_linear_transfer_ref(&transfer_ref);
        object::transfer_with_ref(linear_transfer_ref, player_address);
        object::disable_ungated_transfer(&transfer_ref);
    }

    // equip and unqeip functions

    /// equips a character token to the player
    /// `player` - signer of the transaction; must be the owner of the character token
    /// `character` - character token to equip
    public fun equip_character(player: &signer, character: TokenId) acquires Player, PlayerCollection {
        let player_address = signer::address_of(player);
        assert_player_has_character_token(player_address, character);
        let player_obj_address = get_player_token_address(signer::address_of(player));
        let player_data = borrow_global_mut<Player>(player_obj_address);
        player_data.character = option::some(token_v1::get_tokendata_id(character));
    }

    /// unequips a character token from the player
    /// `player` - signer of the transaction
    public fun unequip_character(player: &signer) acquires Player, PlayerCollection {
        let player_obj_address = get_player_token_address(signer::address_of(player));
        let player_data = borrow_global_mut<Player>(player_obj_address);
        player_data.character = option::none();
    }

    /// equips a melee weapon to the player
    /// `player` - signer of the transaction; must be the owner of the player token
    /// `weapon` - melee weapon to equip
    public fun equip_melee_weapon(player: &signer, weapon: Object<MeleeWeapon>)
    acquires Player, PlayerCollection {
        let player_obj_address = get_player_token_address(signer::address_of(player));
        let player_data = borrow_global_mut<Player>(player_obj_address);
        option::fill(&mut player_data.melee_weapon, weapon);
        object::transfer_to_object(player, weapon, object::address_to_object<Player>(player_obj_address));
    }

    /// unequips a melee weapon from the player
    /// `player` - signer of the transaction; must be the owner of the player token
    /// `weapon` - melee weapon to unequip
    public fun unequip_melee_weapon(player: &signer)
    acquires Player, PlayerCollection {
        let player_address = signer::address_of(player);
        let player_obj_address = get_player_token_address(player_address);
        let player_data = borrow_global_mut<Player>(player_obj_address);
        let stored_weapon = option::extract(&mut player_data.melee_weapon);
        object::transfer(player, stored_weapon, player_address);
    }

    /// equips a ranged weapon to the player
    /// `player` - signer of the transaction; must be the owner of the player token
    /// `weapon` - ranged weapon to equip
    public fun equip_ranged_weapon(player: &signer, weapon: Object<RangedWeapon>)
    acquires Player, PlayerCollection {
        let player_obj_address = get_player_token_address(signer::address_of(player));
        let player_data = borrow_global_mut<Player>(player_obj_address);
        option::fill(&mut player_data.ranged_weapon, weapon);
        object::transfer_to_object(player, weapon, object::address_to_object<Player>(player_obj_address));
    }

    /// unequips a ranged weapon from the player
    /// `player` - signer of the transaction; must be the owner of the player token
    /// `weapon` - ranged weapon to unequip
    public fun unequip_ranged_weapon(player: &signer)
    acquires Player, PlayerCollection {
        let player_address = signer::address_of(player);
        let player_obj_address = get_player_token_address(player_address);
        let player_data = borrow_global_mut<Player>(player_obj_address);
        let stored_weapon = option::extract(&mut player_data.ranged_weapon);
        object::transfer(player, stored_weapon, player_address);
    }

    // helper functions

    // views

    #[view]
    /// returns the address of the player collection
    public fun get_collection_address(): address {
        collection::create_collection_address(&game_admin::get_creator_address(), &string::utf8(COLLECTION_NAME))
    }

    #[view]
    /// returns the player token address for the given player
    /// `player` - player address
    public fun get_player_token_address(player: address): address acquires PlayerCollection {
        let player_collection = borrow_global<PlayerCollection>(get_collection_address());
        *smart_table::borrow(&player_collection.player_token_mapping, player)
    }

    #[view]
    /// returns the player data for the given player
    /// `player` - player address
    public fun get_player_data(player: address): (Option<TokenDataId>, Option<Object<MeleeWeapon>>, u64, u64)
    acquires PlayerCollection, Player {
        let player = borrow_global<Player>(get_player_token_address(player));
        (
            player.character,
            player.melee_weapon,
            player.wins,
            player.losses
        )
    }

    #[view]
    /// returns the character data for the player
    /// `player` - player address
    public fun get_player_character(player: address): (address, String, String) acquires PlayerCollection, Player {
        let player = borrow_global<Player>(get_player_token_address(player));
        if(!option::is_some(&player.character)) {
            (@0x0, string::utf8(b""), string::utf8(b""))
        } else {
            token_v1::get_token_data_id_fields(option::borrow(&player.character))
        }
    }

    #[view]
    /// returns the melee weapon data for the player
    /// `player` - player address
    public fun get_player_melee_weapon(player: address): (u64, u64) acquires PlayerCollection, Player {
        let player = borrow_global_mut<Player>(get_player_token_address(player));
        if(!option::is_some(&player.melee_weapon)) {
            (0, 0)
        } else {
            melee_weapon::get_melee_weapon_data(option::extract(&mut player.melee_weapon))
        }
    }

    #[view]
    /// returns the ranged weapon data for the player
    /// `player` - player address
    public fun get_player_ranged_weapon(player: address): (u64, u64) acquires PlayerCollection, Player {
        let player = borrow_global_mut<Player>(get_player_token_address(player));
        if(!option::is_some(&player.ranged_weapon)) {
            (0, 0)
        } else {
            ranged_weapon::get_ranged_weapon_data(option::extract(&mut player.ranged_weapon))
        }
    }

    // assert statements

    /// asserts that the player collection does not exist
    fun assert_collection_not_initialized() {
        assert!(!exists<PlayerCollection>(get_collection_address()), EALREADY_INITIALIZED)
    }

    /// asserts that the player collection exists
    fun assert_player_collection_initialized() {
        assert!(exists<PlayerCollection>(get_collection_address()), ENOT_INITIALIZED)
    }

    /// asserts that the player has not already claimed a token
    /// `player` - player address
    fun assert_player_has_not_claimed(player: address) acquires PlayerCollection {
        let player_collection = borrow_global<PlayerCollection>(get_collection_address());
        assert!(!smart_table::contains(&player_collection.player_token_mapping, player), EALREADY_CLAIMED);
    }

    /// asserts that a player owns a character token
    /// `player` - player address
    /// `character_token_id` - TokenId of the character
    fun assert_player_has_character_token(player: address, character_token_id: TokenId) {
        assert!(token_v1::balance_of(player, character_token_id) > 0, EINVALID_CHARACTER_TOKEN);
    }


    // tests

    #[test(aptos_arena = @aptos_arena)]
    fun test_initialize(aptos_arena: &signer) {
        game_admin::initialize(aptos_arena);
        initialize(aptos_arena);
        assert_player_collection_initialized();
    }

    #[test(aptos_arena = @aptos_arena)]
    #[expected_failure(abort_code=EALREADY_INITIALIZED)]
    fun test_initialize_twice(aptos_arena: &signer) {
        game_admin::initialize(aptos_arena);
        initialize(aptos_arena);
        initialize(aptos_arena);
    }

    #[test(aptos_arena = @aptos_arena, not_aptos_arena = @0x1)]
    #[expected_failure(abort_code=game_admin::ENOT_DEPLOYER)]
    fun test_initialize_not_deployer(aptos_arena: &signer, not_aptos_arena: &signer) {
        game_admin::initialize(aptos_arena);
        initialize(not_aptos_arena);
    }

    #[test(aptos_arena = @aptos_arena, player = @0x5)]
    fun test_mint_player(aptos_arena: &signer, player: &signer) acquires PlayerCollection, Player {
        game_admin::initialize(aptos_arena);
        initialize(aptos_arena);
        mint_player(player);
        let player_address = signer::address_of(player);
        assert!(exists<Player>(get_player_token_address(player_address)), 0);
        let (
            character,
            melee_weapon,
            wins,
            losses
        ) = get_player_data(player_address);
        assert!(character == option::none(), 0);
        assert!(melee_weapon == option::none(), 0);
        assert!(wins == 0, 0);
        assert!(losses == 0, 0);
    }

    #[test(aptos_arena = @aptos_arena, player = @0x5)]
    #[expected_failure(abort_code=EALREADY_CLAIMED)]
    fun test_mint_player_twice(aptos_arena: &signer, player: &signer) acquires PlayerCollection {
        game_admin::initialize(aptos_arena);
        initialize(aptos_arena);
        mint_player(player);
        mint_player(player);
    }
}
