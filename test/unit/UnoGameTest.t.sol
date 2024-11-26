// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {UnoTypes} from "../../src/UnoTypes.sol";
import {UnoGameLogic} from "../../src/UnoGameLogic.sol";
import {CutthroatUnoFactory} from "../../src/CutthroatUnoFactory.sol";
import {UnoGameTestHelper} from "../helpers/UnoGameTestHelper.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2Mock.sol";

/// @title UnoGame Test Suite
/// @notice Comprehensive test suite for the CutthroatUno game contract
/// @dev Uses Foundry's Test contract and various test helpers
contract UnoGameTest is Test {
    using UnoGameLogic for UnoTypes.GameState;

    CutthroatUnoFactory factory;
    UnoGameTestHelper game;
    VRFCoordinatorV2Mock vrfCoordinator;
    uint64 subscriptionId;

    address player1;
    address player2;
    address player3;

    /// @notice Sets up the test environment before each test
    /// @dev Initializes VRF coordinator, creates game factory, and sets up initial player
    function setUp() public {
        // Setup VRF coordinator mock
        vrfCoordinator = new VRFCoordinatorV2Mock(
            100000, // base fee
            1000000 // gas price link
        );

        // Create and fund subscription
        subscriptionId = vrfCoordinator.createSubscription();
        vrfCoordinator.fundSubscription(subscriptionId, 1000000000000000000);

        // Create factory with VRF configuration
        factory = new CutthroatUnoFactory(
            address(vrfCoordinator),
            keccak256("test"), // gas lane
            subscriptionId,
            1000000, // callback gas limit
            true // Enable test mode
        );

        // Create game and cast to UnoGameTestHelper
        game = UnoGameTestHelper(factory.createGame(4));

        // Add consumer to VRF subscription
        vrfCoordinator.addConsumer(subscriptionId, address(game));

        // Setup test players
        player1 = makeAddr("player1");
        player2 = makeAddr("player2");
        player3 = makeAddr("player3");

        vm.prank(player1);
        game.joinGame();
    }

    /// @notice Helper to setup a game with multiple players and initialize it
    /// @dev Adds players, starts game, and fulfills VRF request
    function _setupActiveGame() internal {
        vm.prank(player2);
        game.joinGame();

        vm.prank(player3);
        game.joinGame();

        vm.prank(player1);
        game.startGameForTest();

        // Fulfill the VRF request
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 12345;
        vm.txGasPrice(0); // Set gas price to 0 for the next transaction
        vrfCoordinator.fulfillRandomWords(1, address(game));

        // Verify game is properly initialized
        require(game.getPlayerCountForTest() > 0, "Game not properly initialized");
    }

    /// @notice Tests initial game state after creation
    /// @dev Verifies game status, player count, direction, and current player
    function test_GameInitialization() public view {
        // Verify initial game state
        assertEq(uint8(game.getGameStatusForTest()), uint8(UnoTypes.GameStatus.WAITING));
        assertEq(game.getPlayerCountForTest(), 1);
        assertTrue(game.getGameDirectionForTest()); // isClockwise should be true
        assertEq(game.getCurrentPlayerIndexForTest(), 0);
    }

    /// @notice Tests player joining functionality
    /// @dev Verifies player state and count after joining
    function test_PlayerJoining() public {
        vm.prank(player2);
        game.joinGame();

        (bool isActive,) = game.getPlayerStateForTest(player2);
        assertTrue(isActive);

        // Update the expected player count to 2 (player1 from setUp + player2)
        assertEq(game.getPlayerCountForTest(), 2);
    }

    /// @notice Tests card validation logic
    /// @dev Verifies valid card plays are correctly identified
    function test_CardValidation() public {
        // Setup game state for testing
        game.setGameStateForTest(2, 0, true);

        UnoTypes.Card memory validCard =
            UnoTypes.Card({color: UnoTypes.Color.RED, cardType: UnoTypes.CardType.NUMBER, number: 5});

        // Add validation tests using the card validation helper
        assertTrue(game.validatePlay(validCard));
    }

    /// @notice Tests handling of special cards (e.g., Reverse)
    /// @dev Verifies game state changes after special card plays
    function test_SpecialCardHandling() public {
        _setupActiveGame();

        // Test REVERSE card
        UnoTypes.Card memory reverseCard =
            UnoTypes.Card({color: UnoTypes.Color.RED, cardType: UnoTypes.CardType.REVERSE, number: 0});

        bool initialDirection = game.getGameDirectionForTest();
        game.handleSpecialCardForTest(reverseCard, UnoTypes.Color.RED);
        assertEq(game.getGameDirectionForTest(), !initialDirection, "Direction should be reversed");
    }

    /// @notice Tests score calculation for different card types
    /// @dev Verifies points for number, special, and wild cards
    function test_ScoreCalculation() public view {
        // Test number card
        UnoTypes.Card memory numberCard =
            UnoTypes.Card({color: UnoTypes.Color.RED, cardType: UnoTypes.CardType.NUMBER, number: 5});
        assertEq(game.calculateCardPointsForTest(numberCard), 5);

        // Test special card
        UnoTypes.Card memory specialCard =
            UnoTypes.Card({color: UnoTypes.Color.BLUE, cardType: UnoTypes.CardType.SKIP, number: 0});
        assertEq(game.calculateCardPointsForTest(specialCard), UnoTypes.SPECIAL_CARD_POINTS);

        // Test wild card
        UnoTypes.Card memory wildCard =
            UnoTypes.Card({color: UnoTypes.Color.WILD, cardType: UnoTypes.CardType.WILD_DRAW_FOUR, number: 0});
        assertEq(game.calculateCardPointsForTest(wildCard), UnoTypes.WILD_CARD_POINTS);
    }

    /// @notice Tests game end conditions based on player scores
    /// @dev Verifies game ends at correct score thresholds
    function test_GameEndCondition() public {
        // Setup basic game state without VRF
        vm.prank(player2);
        game.joinGame();
        vm.prank(player3);
        game.joinGame();

        // Create a dynamic array for player indices
        address[] memory players = new address[](3);
        players[0] = player1;
        players[1] = player2;
        players[2] = player3;

        // Set player indices
        game.setPlayerIndicesForTest(players);

        // Test score below threshold
        game.setPlayerScoreForTest(player1, 400);
        assertFalse(game.checkGameEndForTest(), "Game should not end with score < 500");

        // Test score at threshold
        game.setPlayerScoreForTest(player1, 500);
        assertTrue(game.checkGameEndForTest(), "Game should end with score >= 500");

        // Test score above threshold
        game.setPlayerScoreForTest(player1, 600);
        assertTrue(game.checkGameEndForTest(), "Game should end with score > 500");
    }

    /// @notice Tests player turn rotation mechanics in both clockwise and counter-clockwise directions
    /// @dev This test verifies that:
    ///      1. Player turns advance correctly in clockwise direction (default)
    ///      2. Player turns advance correctly in counter-clockwise direction
    ///      3. Player index wraps around correctly using modulo arithmetic
    /// @dev Test steps:
    ///      1. Sets up active game with multiple players via _setupActiveGame()
    ///      2. Stores initial player index
    ///      3. Advances to next player
    ///      4. Verifies new player index based on game direction:
    ///         - Clockwise: (currentIndex + 1) % playerCount
    ///         - Counter-clockwise: (currentIndex + playerCount - 1) % playerCount
    function test_PlayerRotation() public {
        _setupActiveGame();

        uint8 initialIndex = game.getCurrentPlayerIndexForTest();
        game.advanceToNextPlayerForTest();

        if (game.getGameDirectionForTest()) {
            assertEq(
                game.getCurrentPlayerIndexForTest(),
                (initialIndex + 1) % game.getPlayerCountForTest(),
                "Player rotation clockwise failed"
            );
        } else {
            assertEq(
                game.getCurrentPlayerIndexForTest(),
                (initialIndex + game.getPlayerCountForTest() - 1) % game.getPlayerCountForTest(),
                "Player rotation counter-clockwise failed"
            );
        }
    }

    /// @notice Tests game start functionality
    /// @dev Verifies game state after initialization
    function test_GameStart() public {
        // Setup players
        vm.prank(player2);
        game.joinGame();
        vm.prank(player3);
        game.joinGame();

        // Start game
        game.startGameForTest();

        assertEq(uint8(game.getGameStatusForTest()), uint8(UnoTypes.GameStatus.ACTIVE), "Game status should be ACTIVE");
        assertTrue(game.getGameDirectionForTest(), "Game should start clockwise");
        assertEq(game.getCurrentPlayerIndexForTest(), 0, "First player should start");
    }

    /// @notice Tests the validity of the initial top card in the game
    /// @dev Ensures the initial top card follows Uno rules:
    ///      1. Cannot be a wild card (WILD or WILD_DRAW_FOUR)
    ///      2. Must be either a number card or a basic action card
    ///      This prevents starting the game with complex cards that
    ///      could create unfair initial game states
    function test_TopCard() public {
        _setupActiveGame();
        UnoTypes.Card memory topCard = game.getTopCardForTest();

        // Verify the top card is not a wild card
        assertTrue(topCard.color != UnoTypes.Color.WILD, "Initial top card should never be wild");

        // Verify the top card is either a number or a basic action card
        // Valid cards: NUMBER, SKIP, REVERSE, DRAW_TWO
        assertTrue(
            topCard.cardType == UnoTypes.CardType.NUMBER || topCard.cardType == UnoTypes.CardType.SKIP
                || topCard.cardType == UnoTypes.CardType.REVERSE || topCard.cardType == UnoTypes.CardType.DRAW_TWO,
            "Initial top card should be a number or special card"
        );
    }
}
