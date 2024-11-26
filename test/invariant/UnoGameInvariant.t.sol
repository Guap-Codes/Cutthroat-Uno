// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import "../../src/CutthroatUnoGame.sol";
import "../../src/UnoTypes.sol";
import "../helpers/UnoGameTestHelper.sol";
import "./handlers/UnoGameHandler.sol";

/// @title UnoGame Invariant Tests
/// @notice Contract containing invariant tests for the CutthroatUnoGame contract
/// @dev Uses Foundry's StdInvariant for fuzzing tests
contract UnoGameInvariant is StdInvariant, Test {
    UnoGameTestHelper public game;
    UnoGameHandler public handler;
    address[] public players;

    // Test constants
    uint8 constant MAX_PLAYERS = 4;
    uint256 constant SCORE_LIMIT = 500;

    /// @notice Sets up the test environment with mock VRF coordinator and test players
    /// @dev Deploys test contracts and targets the handler for fuzzing
    function setUp() public {
        // Deploy game with mock VRF coordinator
        game = new UnoGameTestHelper(
            address(1), // mock VRF coordinator
            bytes32(0), // mock gas lane
            0, // mock subscription id
            100000 // callback gas limit
        );

        // Setup test players
        for (uint160 i = 1; i <= MAX_PLAYERS; i++) {
            players.push(address(i));
        }

        // Create and setup handler
        handler = new UnoGameHandler(game, players);

        // Target the handler contract for fuzzing
        targetContract(address(handler));
    }

    /// @notice Verifies that active games always maintain at least 2 players
    /// @dev Only checks when game status is ACTIVE
    function invariant_playerCount() public view {
        if (game.getGameStatusForTest() == UnoTypes.GameStatus.ACTIVE) {
            assertTrue(game.getPlayerCountForTest() >= 2, "Active game should have at least 2 players");
        }
    }

    /// @notice Ensures the top card of the game is always valid
    /// @dev Checks both card type and color validity, with special handling for wild cards
    function invariant_validTopCard() public view {
        if (game.getGameStatusForTest() == UnoTypes.GameStatus.ACTIVE) {
            UnoTypes.Card memory topCard = game.getTopCardForTest();
            // Top card should never be null
            assertTrue(topCard.cardType <= UnoTypes.CardType.WILD_REVERSE, "Invalid card type");

            // If it's not a wild card, color should be valid
            if (
                topCard.cardType != UnoTypes.CardType.WILD && topCard.cardType != UnoTypes.CardType.WILD_DRAW_FOUR
                    && topCard.cardType != UnoTypes.CardType.WILD_REVERSE
            ) {
                assertTrue(topCard.color < UnoTypes.Color.WILD, "Non-wild card has invalid color");
            }
        }
    }

    /// @notice Validates player scores against game rules
    /// @dev Ensures scores are below limit during game and proper at game end
    function invariant_playerScores() public view {
        bool gameFinished = game.getGameStatusForTest() == UnoTypes.GameStatus.FINISHED;

        for (uint256 i = 0; i < players.length; i++) {
            uint256 score = game.playerScores(players[i]);
            if (gameFinished) {
                assertTrue(score >= SCORE_LIMIT || score == 0, "Winner should have score >= 500");
            } else {
                assertTrue(score < SCORE_LIMIT, "Game should end when score limit reached");
            }
        }
    }

    /// @notice Verifies the current player index is always valid
    /// @dev Ensures index is less than total player count in active games
    function invariant_validPlayerIndex() public view {
        if (game.getGameStatusForTest() == UnoTypes.GameStatus.ACTIVE) {
            uint8 currentIndex = game.getCurrentPlayerIndexForTest();
            uint8 playerCount = game.getPlayerCountForTest();
            assertTrue(currentIndex < playerCount, "Current player index exceeds player count");
        }
    }

    /// @notice Ensures the deck never becomes empty during active gameplay
    /// @dev Critical for maintaining game continuity
    function invariant_deckSize() public view {
        if (game.getGameStatusForTest() == UnoTypes.GameStatus.ACTIVE) {
            uint256 deckSize = game.getDeckSizeForTest();
            assertTrue(deckSize > 0, "Deck should never be empty in active game");
        }
    }

    /// @notice Verifies that active players always have cards in their hand
    /// @dev Checks hand size for each active player in the game
    function invariant_validHandSizes() public view {
        if (game.getGameStatusForTest() == UnoTypes.GameStatus.ACTIVE) {
            for (uint256 i = 0; i < players.length; i++) {
                (bool isActive,) = game.getPlayerStateForTest(players[i]);
                if (isActive) {
                    uint256 handSize = game.getPlayerHandSizeForTest(players[i]);
                    assertTrue(handSize > 0, "Active player should always have cards");
                }
            }
        }
    }

    /// @notice Ensures stacked draw cards don't exceed reasonable limits
    /// @dev Prevents potential overflow or game-breaking card stacking
    function invariant_stackedDraws() public view {
        uint8 stackedDraws = game.getStackedDrawsForTest();
        assertTrue(stackedDraws <= 20, "Stacked draws should not exceed reasonable limit");
    }

    /// @notice Validates that round numbers are always positive when game is active
    /// @dev Excludes checking during WAITING status
    function invariant_roundNumber() public view {
        if (game.getGameStatusForTest() != UnoTypes.GameStatus.WAITING) {
            uint256 roundNumber = game.getRoundNumberForTest();
            assertTrue(roundNumber > 0, "Round number should be positive");
        }
    }
}
