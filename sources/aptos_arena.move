module aptos_arena::aptos_arena {

    use std::string::String;
    use std::option::Option;

    use aptos_framework::object::{ConstructorRef, Object};

    use aptos_token_objects::royalty::Royalty;

    use aptos_arcade::scripts;
    use aptos_arcade::game_admin::{Self, GameAdminCapability, PlayerCapability};
    use aptos_arcade::elo;
    use aptos_arcade::match::{Match};

    struct AptosArena has drop {}

    // public functions

    /// initializes the game admin account, elo rating collection, and matches collection
    /// `aptos_arena` - the signer of the aptos arena account
    public fun initialize(aptos_arena: &signer) {
        scripts::initialize(aptos_arena, AptosArena {});
    }

    /// creates a collection under the game admin account
    /// `game_admin` - the signer of the game admin account
    /// `descripion` - the description of the collection
    /// `name` - the name of the collection
    /// `royalty` - the royalty of the collection
    /// `uri` - the uri of the collection
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

    /// creates a one-to-one collection under the game admin account
    /// `game_admin` - the signer of the game admin account
    /// `descripion` - the description of the collection
    /// `name` - the name of the collection
    /// `royalty` - the royalty of the collection
    /// `uri` - the uri of the collection
    public fun create_one_to_one_collection(
        game_admin: &signer,
        descripion: String,
        name: String,
        royalty: Option<Royalty>,
        uri: String
    ): ConstructorRef {
        game_admin::create_one_to_one_collection<AptosArena>(
            &create_game_admin_capability(game_admin),
            descripion,
            name,
            royalty,
            uri
        )
    }

    /// mints a token to a player
    /// `player` - the signer of the player account
    /// `collection_name` - the name of the collection
    /// `token_description` - the description of the token
    /// `token_name` - the name of the token
    /// `royalty` - the royalty of the token
    /// `uri` - the uri of the token
    /// `soulbound` - whether the token is soulbound
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

    /// mints a token to the game admin
    /// `game_admin` - the signer of the game admin account
    /// `collection_name` - the name of the collection
    /// `token_description` - the description of the token
    /// `token_name` - the name of the token
    /// `royalty` - the royalty of the token
    /// `uri` - the uri of the token
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

    /// mints an EloRating token for `GameType`
    /// `player` - the signer of the player account
    public fun mint_elo_token(player: &signer) {
        scripts::mint_elo_token(player, AptosArena {});
    }

    /// creates a match between `teams`
    /// `game_admin` - the signer of the game admin account
    /// `teams` - the teams of the match
    public fun create_match(game_admin: &signer, teams: vector<vector<address>>): Object<Match<AptosArena>> {
        scripts::create_match(game_admin, AptosArena {}, teams)
    }

    /// sets the result of a match
    /// `game_admin` - the signer of the game admin account
    /// `match` - the match object
    /// `winner_index` - the index of the winning team
    public fun set_match_result(game_admin: &signer, match: Object<Match<AptosArena>>, winner_index: u64) {
        scripts::set_match_result(game_admin, AptosArena {}, match, winner_index);
    }

    // access control

    /// creates a GameAdminCapability
    /// `game_admin` - the signer of the game admin account
    fun create_game_admin_capability(game_admin: &signer): GameAdminCapability<AptosArena> {
        game_admin::create_game_admin_capability(game_admin, AptosArena {})
    }

    /// creates a PlayerCapability
    /// `player` - the signer of the player account
    fun create_player_capability(player: &signer): PlayerCapability<AptosArena> {
        game_admin::create_player_capability(player, AptosArena {})
    }

    // view functions

    #[view]
    /// returns the address of the game account
    public fun get_game_account_address(): address {
        game_admin::get_game_account_address<AptosArena>()
    }

    #[view]
    /// returns the collection address for a given collection name
    /// `collection_name` - the name of the collection
    public fun get_collection_address(collection_name: String): address {
        game_admin::get_collection_address<AptosArena>(collection_name)
    }

    #[view]
    /// returns whether a player has minted from a one-to-one collection
    /// `collection_name` - the name of the collection
    /// `player_address` - the address of the player
    public fun has_player_minted(collection_name: String, player_address: address): bool {
        game_admin::has_player_received_token<AptosArena>(collection_name, player_address)
    }

    #[view]
    /// returns the token address for a player in a one-to-one collection
    /// `collection_name` - the name of the collection
    /// `player_address` - the address of the player
    public fun get_player_token_address(collection_name: String, player_address: address): address {
        game_admin::get_player_token_address<AptosArena>(collection_name, player_address)
    }

    #[view]
    /// returns the ELO rating data for a given player address
    /// `player_address` - the address of the player
    public fun get_player_elo_rating(player_address: address): (u64, u64, u64) {
        elo::get_player_elo_rating<AptosArena>(player_address)
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


    #[test(aptos_arena=@aptos_arena, player1=@0x100, player2=@0x101)]
    fun test_e2e(aptos_arena: &signer, player1: &signer, player2: &signer) {

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
            player1,
            collection_name,
            token_description,
            token_name,
            option::none(),
            token_uri,
            false
        );
        assert!(object::is_owner(
            object::object_from_constructor_ref<Token>(&constructor_ref),
            signer::address_of(player1)
        ), 0);

        mint_elo_token(player1);
        mint_elo_token(player2);

        let (elo_rating, wins, losses) = get_player_elo_rating(signer::address_of(player1));
        assert!(elo_rating == 100, 0);
        assert!(wins == 0, 0);
        assert!(losses == 0, 0);

        let teams = vector<vector<address>> [
            vector<address>[signer::address_of(player1)],
            vector<address>[signer::address_of(player2)]
        ];
        let match_object = create_match(aptos_arena, teams);
        set_match_result(aptos_arena, match_object, 0);
    }

}
