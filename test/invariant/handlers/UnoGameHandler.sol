// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import "../../../src/UnoTypes.sol";
import "../../helpers/UnoGameTestHelper.sol";

/// @title UnoGame Invariant Test Handler
/// @notice Handler contract for invariant testing of the UnoGame contract
/// @dev Used in conjunction with forge-std's invariant testing framework
contract UnoGameHandler is Test {
    UnoGameTestHelper public game;
    address[] public players;

    /// @notice Initializes the handler with game instance and player addresses
    /// @param _game The UnoGame test helper instance
    /// @param _players Array of player addresses to use in tests
    constructor(UnoGameTestHelper _game, address[] memory _players) {
        game = _game;
        players = _players;
    }

    /// @notice Simulates a player joining the game
    /// @param playerSeed Random seed to select a player from the players array
    function joinGame(uint256 playerSeed) public {
        address player = players[bound(playerSeed, 0, players.length - 1)];
        vm.prank(player);
        try game.joinGame() {} catch {}
    }

    /// @notice Simulates a player playing a card from their hand
    /// @param playerSeed Random seed to select a player from the players array
    /// @param handIndex Index of the card in player's hand to play
    /// @param colorSeed Random seed to select a color (used for wild cards)
    function playCard(uint256 playerSeed, uint8 handIndex, uint8 colorSeed) public {
        address player = players[bound(playerSeed, 0, players.length - 1)];
        UnoTypes.Color declaredColor = UnoTypes.Color(bound(colorSeed, 0, 4));

        vm.prank(player);
        try game.playCard(handIndex, declaredColor) {} catch {}
    }

    /// @notice Simulates a player calling "Uno"
    /// @param playerSeed Random seed to select a player from the players array
    function callUno(uint256 playerSeed) public {
        address player = players[bound(playerSeed, 0, players.length - 1)];
        vm.prank(player);
        try game.callUno() {} catch {}
    }

    /// @notice Simulates a player drawing a card
    /// @param playerSeed Random seed to select a player from the players array
    function drawCard(uint256 playerSeed) public {
        address player = players[bound(playerSeed, 0, players.length - 1)];
        vm.prank(player);
        try game.drawCard() {} catch {}
    }

    /// @notice Simulates handling of special card effects
    /// @param cardTypeSeed Random seed to select a special card type
    /// @param colorSeed Random seed to select a color
    function handleSpecialCard(uint8 cardTypeSeed, uint8 colorSeed) public {
        UnoTypes.Card memory card = UnoTypes.Card({
            cardType: UnoTypes.CardType(bound(cardTypeSeed, 0, 6)),
            color: UnoTypes.Color(bound(colorSeed, 0, 4)),
            number: 0
        });

        UnoTypes.Color declaredColor = UnoTypes.Color(bound(colorSeed, 0, 4));
        try game.handleSpecialCardForTest(card, declaredColor) {} catch {}
    }

    /// @notice Advances the game to the next player
    function advancePlayer() public {
        try game.advanceToNextPlayerForTest() {} catch {}
    }

    /// @notice Bounds a value within a specified range
    /// @param value The value to bound
    /// @param min The minimum allowed value
    /// @param max The maximum allowed value
    /// @return The bounded value
    function bound(uint256 value, uint256 min, uint256 max) internal pure override returns (uint256) {
        require(min <= max, "Min must be <= max");
        return min + (value % (max - min + 1));
    }
}
