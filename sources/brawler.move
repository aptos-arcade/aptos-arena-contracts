module aptos_arena::brawler {

    use std::string::{Self, String};
    use std::option::{Self, Option};
    use std::signer;

    use aptos_std::smart_table::{Self, SmartTable};
    use aptos_std::string_utils;

    use aptos_framework::object::{Self, Object};

    use aptos_token::token::{Self as token_v1, TokenDataId, TokenId};

    use aptos_token_objects::collection::{Self};

    use aptos_arena::aptos_arena;
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

    const COLLECTION_NAME: vector<u8> = b"Brawler";
    const COLLECTION_DESCRIPTION: vector<u8> = b"Represents a brawler in Aptos Arena, moddable with a melee weapon, ranged weapon, and armour";
    const COLLECTION_URI: vector<u8> = b"https://aptosarena.com";

    const TOKEN_NAME_PREFIX: vector<u8> = b"Brawler ";
    const TOKEN_DESCRIPTION: vector<u8> = b"Brawler in Aptos Arena";
    const TOKEN_BASE_URI: vector<u8> = b"https://aptosarena.com/player/";

    // structs

    struct BrawlerCollection has key {
        address_token_mapping: SmartTable<address, address>
    }

    struct Brawler has key {
        character: Option<TokenDataId>,
        melee_weapon: Option<Object<MeleeWeapon>>,
        ranged_weapon: Option<Object<RangedWeapon>>,
    }

    // entry functions

    /// initializes the player collection under the creator resource account
    /// `game_admin` - signer of the transaction; must be the package deployer
    public fun initialize(game_admin: &signer) {
        assert_collection_not_initialized();
        let constructor_ref = aptos_arena::create_collection(
            game_admin,
            string::utf8(COLLECTION_DESCRIPTION),
            string::utf8(COLLECTION_NAME),
            option::none(),
            string::utf8(COLLECTION_URI)
        );
        let object_signer = object::generate_signer(&constructor_ref);
        move_to(&object_signer, BrawlerCollection {
            address_token_mapping: smart_table::new()
        });
    }

    /// mints a player token for the given player
    /// `player` - signer of the transaction; only one mint per account
    public fun mint_brawler(player: &signer) acquires BrawlerCollection {
        assert_player_collection_initialized();
        let player_address = signer::address_of(player);
        assert_player_has_not_claimed(player_address);
        let constructor_ref = aptos_arena::mint_token_player(
            player,
            string::utf8(COLLECTION_NAME),
            string::utf8(TOKEN_DESCRIPTION),
            string_utils::to_string_with_canonical_addresses(&player_address),
            option::none(),
            string::utf8(TOKEN_BASE_URI),
            true
        );

        let object_signer = object::generate_signer(&constructor_ref);

        // create player object and move to token
        let brawler = Brawler {
            character: option::none(),
            melee_weapon: option::none(),
            ranged_weapon: option::none(),
        };
        move_to(&object_signer, brawler);

        // update player token mapping
        let brawler_collection = borrow_global_mut<BrawlerCollection>(get_collection_address());
        smart_table::add(&mut brawler_collection.address_token_mapping, player_address, signer::address_of(&object_signer));
    }

    // equip and unqeip functions

    /// equips a character token to the player
    /// `player` - signer of the transaction; must be the owner of the character token
    /// `character` - character token to equip
    public fun equip_character(player: &signer, character: TokenId) acquires Brawler, BrawlerCollection {
        let player_address = signer::address_of(player);
        assert_player_has_character_token(player_address, character);
        let player_obj_address = get_player_token_address(signer::address_of(player));
        let player_data = borrow_global_mut<Brawler>(player_obj_address);
        player_data.character = option::some(token_v1::get_tokendata_id(character));
    }

    /// unequips a character token from the player
    /// `player` - signer of the transaction
    public fun unequip_character(player: &signer) acquires Brawler, BrawlerCollection {
        let player_obj_address = get_player_token_address(signer::address_of(player));
        let player_data = borrow_global_mut<Brawler>(player_obj_address);
        player_data.character = option::none();
    }

    /// equips a melee weapon to the player
    /// `player` - signer of the transaction; must be the owner of the player token
    /// `weapon` - melee weapon to equip
    public fun equip_melee_weapon(player: &signer, weapon: Object<MeleeWeapon>)
    acquires Brawler, BrawlerCollection {
        let player_obj_address = get_player_token_address(signer::address_of(player));
        let player_data = borrow_global_mut<Brawler>(player_obj_address);
        option::fill(&mut player_data.melee_weapon, weapon);
        object::transfer_to_object(player, weapon, object::address_to_object<Brawler>(player_obj_address));
    }

    /// unequips a melee weapon from the player
    /// `player` - signer of the transaction; must be the owner of the player token
    /// `weapon` - melee weapon to unequip
    public fun unequip_melee_weapon(player: &signer)
    acquires Brawler, BrawlerCollection {
        let player_address = signer::address_of(player);
        let player_obj_address = get_player_token_address(player_address);
        let player_data = borrow_global_mut<Brawler>(player_obj_address);
        let stored_weapon = option::extract(&mut player_data.melee_weapon);
        melee_weapon::transfer_melee_weapon(&stored_weapon, player_address);
    }

    /// equips a ranged weapon to the player
    /// `player` - signer of the transaction; must be the owner of the player token
    /// `weapon` - ranged weapon to equip
    public fun equip_ranged_weapon(player: &signer, weapon: Object<RangedWeapon>)
    acquires Brawler, BrawlerCollection {
        let player_obj_address = get_player_token_address(signer::address_of(player));
        let player_data = borrow_global_mut<Brawler>(player_obj_address);
        option::fill(&mut player_data.ranged_weapon, weapon);
        object::transfer_to_object(player, weapon, object::address_to_object<Brawler>(player_obj_address));
    }

    /// unequips a ranged weapon from the player
    /// `player` - signer of the transaction; must be the owner of the player token
    /// `weapon` - ranged weapon to unequip
    public fun unequip_ranged_weapon(player: &signer)
    acquires Brawler, BrawlerCollection {
        let player_address = signer::address_of(player);
        let player_obj_address = get_player_token_address(player_address);
        let player_data = borrow_global_mut<Brawler>(player_obj_address);
        let stored_weapon = option::extract(&mut player_data.ranged_weapon);
        ranged_weapon::transfer_ranged_weapon(&stored_weapon, player_address);
    }

    // helper functions

    // views

    #[view]
    /// returns the address of the player collection
    public fun get_collection_address(): address {
        collection::create_collection_address(
            &aptos_arena::get_game_account_address(), 
            &string::utf8(COLLECTION_NAME)
        )
    }

    #[view]
    /// returns the player token address for the given player
    /// `player` - player address
    public fun get_player_token_address(player: address): address acquires BrawlerCollection {
        let player_collection = borrow_global<BrawlerCollection>(get_collection_address());
        *smart_table::borrow(&player_collection.address_token_mapping, player)
    }

    #[view]
    /// returns the player data for the given player
    /// `player` - player address
    public fun get_player_data(player: address): (Option<TokenDataId>, Option<Object<MeleeWeapon>>)
    acquires BrawlerCollection, Brawler {
        let player = borrow_global<Brawler>(get_player_token_address(player));
        (
            player.character,
            player.melee_weapon
        )
    }

    #[view]
    /// returns the character data for the player
    /// `player` - player address
    public fun get_player_character(player: address): (address, String, String) acquires BrawlerCollection, Brawler {
        let player = borrow_global<Brawler>(get_player_token_address(player));
        if(!option::is_some(&player.character)) {
            (@0x0, string::utf8(b""), string::utf8(b""))
        } else {
            token_v1::get_token_data_id_fields(option::borrow(&player.character))
        }
    }

    #[view]
    /// returns the melee weapon data for the player
    /// `player` - player address
    public fun get_player_melee_weapon(player: address): (u64, u64) acquires BrawlerCollection, Brawler {
        let player = borrow_global_mut<Brawler>(get_player_token_address(player));
        if(!option::is_some(&player.melee_weapon)) {
            (0, 0)
        } else {
            let melee_weapon = option::extract(&mut player.melee_weapon);
            let (power, type) = melee_weapon::get_melee_weapon_data(melee_weapon);
            player.melee_weapon = option::some(melee_weapon);
            (power, type)
        }
    }

    #[view]
    /// returns the ranged weapon data for the player
    /// `player` - player address
    public fun get_player_ranged_weapon(player: address): (u64, u64) acquires BrawlerCollection, Brawler {
        let player = borrow_global_mut<Brawler>(get_player_token_address(player));
        if(!option::is_some(&player.ranged_weapon)) {
            (0, 0)
        } else {
            let ranged_weapon = option::extract(&mut player.ranged_weapon);
            let (power, type) = ranged_weapon::get_ranged_weapon_data(ranged_weapon);
            player.ranged_weapon = option::some(ranged_weapon);
            (power, type)
        }
    }

    // assert statements

    /// asserts that the player collection does not exist
    fun assert_collection_not_initialized() {
        assert!(!exists<BrawlerCollection>(get_collection_address()), EALREADY_INITIALIZED)
    }

    /// asserts that the player collection exists
    fun assert_player_collection_initialized() {
        assert!(exists<BrawlerCollection>(get_collection_address()), ENOT_INITIALIZED)
    }

    /// asserts that the player has not already claimed a token
    /// `player` - player address
    fun assert_player_has_not_claimed(player: address) acquires BrawlerCollection {
        let player_collection = borrow_global<BrawlerCollection>(get_collection_address());
        assert!(!smart_table::contains(&player_collection.address_token_mapping, player), EALREADY_CLAIMED);
    }

    /// asserts that a player owns a character token
    /// `player` - player address
    /// `character_token_id` - TokenId of the character
    fun assert_player_has_character_token(player: address, character_token_id: TokenId) {
        assert!(token_v1::balance_of(player, character_token_id) > 0, EINVALID_CHARACTER_TOKEN);
    }


    // tests

    #[test_only]
    use aptos_arcade::game_admin;

    #[test(aptos_arena = @aptos_arena)]
    fun test_initialize(aptos_arena: &signer) {
        aptos_arena::initialize(aptos_arena);
        initialize(aptos_arena);
        assert_player_collection_initialized();
    }

    #[test(aptos_arena = @aptos_arena)]
    #[expected_failure(abort_code=EALREADY_INITIALIZED)]
    fun test_initialize_twice(aptos_arena: &signer) {
        aptos_arena::initialize(aptos_arena);
        initialize(aptos_arena);
        initialize(aptos_arena);
    }

    #[test(aptos_arena = @aptos_arena, not_aptos_arena = @0x1)]
    #[expected_failure(abort_code=game_admin::ESIGNER_NOT_ADMIN)]
    fun test_initialize_not_deployer(aptos_arena: &signer, not_aptos_arena: &signer) {
        aptos_arena::initialize(aptos_arena);
        initialize(not_aptos_arena);
    }

    #[test(aptos_arena = @aptos_arena, player = @0x5)]
    fun test_mint_player(aptos_arena: &signer, player: &signer) acquires BrawlerCollection, Brawler {
        aptos_arena::initialize(aptos_arena);
        initialize(aptos_arena);
        mint_brawler(player);
        let player_address = signer::address_of(player);
        assert!(exists<Brawler>(get_player_token_address(player_address)), 0);
        let (character, melee_weapon) = get_player_data(player_address);
        assert!(character == option::none(), 0);
        assert!(melee_weapon == option::none(), 0);
    }

    #[test(aptos_arena = @aptos_arena, player = @0x5)]
    #[expected_failure(abort_code=EALREADY_CLAIMED)]
    fun test_mint_player_twice(aptos_arena: &signer, player: &signer) acquires BrawlerCollection {
        aptos_arena::initialize(aptos_arena);
        initialize(aptos_arena);
        mint_brawler(player);
        mint_brawler(player);
    }

    #[test(aptos_arena = @aptos_arena, player = @0x5)]
    #[expected_failure(abort_code=ENOT_INITIALIZED)]
    fun test_mint_player_not_initialized(aptos_arena: &signer, player: &signer) acquires BrawlerCollection {
        aptos_arena::initialize(aptos_arena);
        mint_brawler(player);
    }
}
