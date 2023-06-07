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

    #[test(aptos_arena = @aptos_arena, player = @0x50)]
    fun e2e_tests(aptos_arena: &signer, player: &signer) {
        genesis::setup();
        initialize(aptos_arena);
        mint_player(player);
        let melee_weapon = melee_weapon::mint(player);
        equip_melee_weapon(player, melee_weapon);
    }
}
