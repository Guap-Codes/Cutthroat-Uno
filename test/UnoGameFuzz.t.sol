// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {UnoTypes} from "../src/UnoTypes.sol";
import {CutthroatUnoFactory} from "../src/CutthroatUnoFactory.sol";
import {UnoGameTestHelper} from "./helpers/UnoGameTestHelper.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2Mock.sol";

/// @title UnoGameFuzz
/// @notice Fuzzing tests for the Uno game contract
/// @dev Uses Foundry's built-in fuzzing capabilities to test card validation and scoring
contract UnoGameFuzz is Test {
    UnoGameTestHelper public game;
    CutthroatUnoFactory public factory;
    VRFCoordinatorV2Mock public vrfCoordinator;

    /// @notice Sets up the test environment with a mock VRF coordinator and game instance
    /// @dev Creates a VRF subscription, funds it, and initializes the game factory and instance
    function setUp() public {
        // Setup VRF coordinator mock with reasonable base fee and gas price
        vrfCoordinator = new VRFCoordinatorV2Mock(
            100000, // base fee
            1000000 // gas price link
        );

        // Create and fund VRF subscription with 1 LINK
        uint64 subId = vrfCoordinator.createSubscription();
        vrfCoordinator.fundSubscription(subId, 1000000000000000000);

        // Initialize factory with VRF configuration in test mode
        factory = new CutthroatUnoFactory(
            address(vrfCoordinator),
            bytes32(0), // keyHash (not used in test mode)
            subId,
            100000, // callback gas limit
            true // Enable test mode
        );

        // Deploy game instance and configure VRF consumer
        game = UnoGameTestHelper(factory.createGame(4));
        vrfCoordinator.addConsumer(subId, address(game));
    }

    /// @notice Fuzz test for card play validation rules
    /// @param color Random color value to test
    /// @param cardType Random card type value to test
    /// @param number Random card number to test
    /// @dev Tests all valid card play combinations against a fixed top card
    function testFuzz_CardValidation(uint8 color, uint8 cardType, uint8 number) public {
        // Bound inputs to valid enum ranges
        color = uint8(bound(color, 0, uint8(type(UnoTypes.Color).max) - 1));
        cardType = uint8(bound(cardType, 0, uint8(type(UnoTypes.CardType).max) - 1));
        number = uint8(bound(number, 0, 9));

        // Create test cards
        UnoTypes.Card memory playedCard =
            UnoTypes.Card({color: UnoTypes.Color(color), cardType: UnoTypes.CardType(cardType), number: number});
        UnoTypes.Card memory topCard =
            UnoTypes.Card({color: UnoTypes.Color.RED, cardType: UnoTypes.CardType.NUMBER, number: 5});

        // Setup game state for testing
        game.setGameStateForTest(2, 0, true);
        game.setTopCardForTest(topCard);

        bool isValid = game.validatePlay(playedCard);

        // Test all valid play conditions:
        // 1. Wild cards are always playable
        // 2. Same color is valid
        // 3. Same special card type (except numbers) is valid
        // 4. Same number for number cards is valid
        if (
            playedCard.cardType == UnoTypes.CardType.WILD || playedCard.cardType == UnoTypes.CardType.WILD_DRAW_FOUR
                || playedCard.cardType == UnoTypes.CardType.WILD_REVERSE
        ) {
            assertTrue(isValid, "Wild cards should always be valid");
        } else if (playedCard.color == topCard.color) {
            assertTrue(isValid, "Same color should be valid");
        } else if (playedCard.cardType == topCard.cardType && playedCard.cardType != UnoTypes.CardType.NUMBER) {
            assertTrue(isValid, "Same special card type should be valid");
        } else if (
            playedCard.cardType == UnoTypes.CardType.NUMBER && topCard.cardType == UnoTypes.CardType.NUMBER
                && playedCard.number == topCard.number
        ) {
            assertTrue(isValid, "Same number should be valid");
        } else {
            assertFalse(isValid, "Play should be invalid");
        }
    }

    /// @notice Fuzz test for card point calculation
    /// @param color Random color value to test
    /// @param cardType Random card type value to test
    /// @param number Random card number to test
    /// @dev Verifies point calculation for all card types
    function testFuzz_ScoreCalculation(uint8 color, uint8 cardType, uint8 number) public view {
        // Bound inputs to valid enum ranges
        color = uint8(bound(color, 0, uint8(type(UnoTypes.Color).max)));
        cardType = uint8(bound(cardType, 0, uint8(type(UnoTypes.CardType).max)));
        number = uint8(bound(number, 0, 9));

        UnoTypes.Card memory card =
            UnoTypes.Card({color: UnoTypes.Color(color), cardType: UnoTypes.CardType(cardType), number: number});

        uint256 points = game.calculateCardPointsForTest(card);

        // Verify points based on card type:
        // - Number cards: number * multiplier
        // - Wild cards: fixed wild card points
        // - Special cards: fixed special card points
        if (card.cardType == UnoTypes.CardType.NUMBER) {
            assertEq(points, card.number * UnoTypes.NUMBER_CARD_MULTIPLIER, "Invalid number card points");
        } else if (
            card.cardType == UnoTypes.CardType.WILD || card.cardType == UnoTypes.CardType.WILD_DRAW_FOUR
                || card.cardType == UnoTypes.CardType.WILD_REVERSE
        ) {
            assertEq(points, UnoTypes.WILD_CARD_POINTS, "Invalid wild card points");
        } else {
            assertEq(points, UnoTypes.SPECIAL_CARD_POINTS, "Invalid special card points");
        }
    }
}
