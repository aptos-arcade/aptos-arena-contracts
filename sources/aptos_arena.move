module aptos_arena::aptos_arena {

    use std::string::String;
    use std::option::Option;

    use aptos_framework::object::ConstructorRef;

    use aptos_token_objects::royalty::Royalty;

    use aptos_arcade::game_admin::{Self, GameAdminCapability, PlayerCapability};


    struct AptosArena has drop {}

    // public functions

    public fun initialize(aptos_arena: &signer) {
        game_admin::initialize(aptos_arena, AptosArena {});
    }

    public fun create_collection(
        game_admin: &signer,
        descripion: String,
        name: String,
        royalty: Option<Royalty>,
        uri: String
    ): ConstructorRef {
        game_admin::create_collection<AptosArena>(
            &create_game_admin_capability(game_admin),
            descripion,
            name,
            royalty,
            uri
        )
    }

    public fun mint_token_player(
        player: &signer,
        collection_name: String,
        token_description: String,
        token_name: String,
        royalty: Option<Royalty>,
        uri: String,
        soulbound: bool
    ): ConstructorRef {
        game_admin::mint_token_player<AptosArena>(
            &create_player_capability(player),
            collection_name,
            token_description,
            token_name,
            royalty,
            uri,
            soulbound
        )
    }

    public fun mint_token_game_admin(
        game_admin: &signer,
        collection_name: String,
        token_description: String,
        token_name: String,
        royalty: Option<Royalty>,
        uri: String,
    ): ConstructorRef {
        game_admin::mint_token_game_admin<AptosArena>(
            &create_game_admin_capability(game_admin),
            collection_name,
            token_description,
            token_name,
            royalty,
            uri
        )
    }

    // access control

    fun create_game_admin_capability(game_admin: &signer): GameAdminCapability<AptosArena> {
        game_admin::create_game_admin_capability(game_admin, AptosArena {})
    }

    fun create_player_capability(player: &signer): PlayerCapability<AptosArena> {
        game_admin::create_player_capability(player, AptosArena {})
    }

    // view functions

    public fun get_game_account_address(): address {
        game_admin::get_game_account_address<AptosArena>()
    }

    // tests

    #[test_only]
    use std::string;
    #[test_only]
    use std::option;
    #[test_only]
    use std::signer;
    #[test_only]
    use aptos_framework::object;
    #[test_only]
    use aptos_token_objects::token::Token;


    #[test(aptos_arena=@aptos_arena, player=@0x100)]
    fun test_e2e(aptos_arena: &signer, player: &signer) {

        let collection_name = string::utf8(b"test_collection");
        let collection_description = string::utf8(b"test_collection_description");
        let colelction_uri = string::utf8(b"test_collection_uri");

        initialize(aptos_arena);
        create_collection(
            aptos_arena,
            collection_description,
            collection_name,
            option::none(),
            colelction_uri
        );

        let token_name = string::utf8(b"test_token_name");
        let token_description = string::utf8(b"test_token_description");
        let token_uri = string::utf8(b"test_token_uri");

        let constructor_ref = mint_token_game_admin(
            aptos_arena,
            collection_name,
            token_description,
            token_name,
            option::none(),
            token_uri
        );
        assert!(object::is_owner(
            object::object_from_constructor_ref<Token>(&constructor_ref),
            get_game_account_address()
        ), 0);

        let constructor_ref = mint_token_player(
            player,
            collection_name,
            token_description,
            token_name,
            option::none(),
            token_uri,
            false
        );
        assert!(object::is_owner(
            object::object_from_constructor_ref<Token>(&constructor_ref),
            signer::address_of(player)
        ), 0);
    }

}
