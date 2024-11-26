// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./UnoTypes.sol";

/// @title UnoGameLogic Library
/// @notice Implements the core game logic for an on-chain UNO game
/// @dev Contains all game mechanics, card validation, and scoring logic
library UnoGameLogic {
    using UnoGameLogic for UnoTypes.GameState;

    /// @notice Validates if a card can be legally played on the current top card
    /// @param gameState Current game state
    /// @param card Card being played
    /// @return bool True if the card can be played
    function isValidPlay(UnoTypes.GameState storage gameState, UnoTypes.Card memory card)
        internal
        view
        returns (bool)
    {
        UnoTypes.Card memory topCard = gameState.topCard;

        // Wild cards can always be played
        if (
            card.cardType == UnoTypes.CardType.WILD || card.cardType == UnoTypes.CardType.WILD_DRAW_FOUR
                || card.cardType == UnoTypes.CardType.WILD_REVERSE
        ) {
            return true;
        }

        // Match color or card type
        return card.color == topCard.color
            || (card.cardType == topCard.cardType && card.cardType != UnoTypes.CardType.NUMBER)
            || (card.cardType == UnoTypes.CardType.NUMBER && card.number == topCard.number);
    }

    /// @notice Handles the effects of playing special cards (e.g., Reverse, Skip, Draw Two)
    /// @param gameState Current game state
    /// @param card The special card being played
    /// @param declaredColor The color declared when playing a wild card
    /// @param gameId The unique identifier for the current game
    function handleSpecialCard(
        UnoTypes.GameState storage gameState,
        UnoTypes.Card memory card,
        UnoTypes.Color declaredColor,
        uint256 gameId
    ) internal {
        if (card.cardType == UnoTypes.CardType.REVERSE) {
            gameState.isClockwise = !gameState.isClockwise;
            emit UnoTypes.DirectionChanged(gameId, gameState.isClockwise);
            advanceToNextPlayer(gameState);
        } else if (card.cardType == UnoTypes.CardType.SKIP) {
            address skippedPlayer =
                getPlayerAddress(gameState, getNextPlayerIndex(gameState, gameState.currentPlayerIndex));
            advanceToNextPlayer(gameState);
            advanceToNextPlayer(gameState);
            emit UnoTypes.PlayerSkipped(gameId, skippedPlayer);
        } else if (card.cardType == UnoTypes.CardType.DRAW_TWO) {
            gameState.stackedDraws += 2;
            advanceToNextPlayer(gameState);
        } else if (card.cardType == UnoTypes.CardType.WILD_DRAW_FOUR) {
            gameState.stackedDraws += 4;
            gameState.topCard.color = declaredColor;
            emit UnoTypes.ColorChanged(gameId, declaredColor);
            advanceToNextPlayer(gameState);
        } else if (card.cardType == UnoTypes.CardType.WILD) {
            gameState.topCard.color = declaredColor;
            emit UnoTypes.ColorChanged(gameId, declaredColor);
            advanceToNextPlayer(gameState);
        } else if (card.cardType == UnoTypes.CardType.WILD_REVERSE) {
            gameState.isClockwise = !gameState.isClockwise;
            gameState.topCard.color = declaredColor;
            emit UnoTypes.DirectionChanged(gameId, gameState.isClockwise);
            emit UnoTypes.ColorChanged(gameId, declaredColor);
            advanceToNextPlayer(gameState);
        }
    }

    /// @notice Calculates points for a single card
    /// @param card The card to calculate points for
    /// @return uint256 The point value of the card
    function calculateCardPoints(UnoTypes.Card memory card) internal pure returns (uint256) {
        if (card.cardType == UnoTypes.CardType.NUMBER) {
            return uint256(card.number) * UnoTypes.NUMBER_CARD_MULTIPLIER;
        } else if (
            card.cardType == UnoTypes.CardType.WILD || card.cardType == UnoTypes.CardType.WILD_DRAW_FOUR
                || card.cardType == UnoTypes.CardType.WILD_REVERSE
        ) {
            return UnoTypes.WILD_CARD_POINTS;
        } else {
            return UnoTypes.SPECIAL_CARD_POINTS;
        }
    }

    /// @notice Calculates the total score of cards in a player's hand
    /// @param gameState Current game state
    /// @param player Address of the player
    /// @return uint256 Total score of the hand
    function calculateHandScore(UnoTypes.GameState storage gameState, address player) internal view returns (uint256) {
        uint256 score = 0;
        UnoTypes.Card[] storage hand = gameState.players[player].hand;

        for (uint256 i = 0; i < hand.length; i++) {
            score += calculateCardPoints(hand[i]);
        }

        return score;
    }

    /// @notice Processes the end of a round, calculating and updating scores
    /// @param gameState Current game state
    /// @param gameId The unique identifier for the current game
    function handleRoundEnd(UnoTypes.GameState storage gameState, uint256 gameId) internal {
        // Calculate and update scores for all players
        for (uint160 i = 0; i < type(uint160).max; i++) {
            address playerAddress = address(i);
            if (gameState.players[playerAddress].isActive) {
                uint256 roundScore = calculateHandScore(gameState, playerAddress);
                gameState.playerScores[playerAddress] += roundScore;
                emit UnoTypes.ScoreUpdated(gameId, playerAddress, gameState.playerScores[playerAddress]);
            }
        }

        gameState.roundNumber++;
        emit UnoTypes.RoundEnded(gameId, gameState.roundNumber);
    }

    /// @notice Checks if a player has won the round by emptying their hand
    /// @param gameState Current game state
    /// @param player Address of the player to check
    /// @return bool True if the player has no cards left
    function checkRoundEnd(UnoTypes.GameState storage gameState, address player) internal view returns (bool) {
        return gameState.players[player].hand.length == 0;
    }

    /// @notice Checks if any player has reached the winning score (500 points)
    /// @param gameState Current game state
    /// @return bool True if a player has won the game
    function checkGameEnd(UnoTypes.GameState storage gameState) internal view returns (bool) {
        // If game hasn't started or no players have joined, return false instead of reverting
        if (gameState.playerIndices.length == 0 || gameState.playerCount == 0) {
            return false;
        }

        // Loop through active players using their indices
        for (uint8 i = 0; i < gameState.playerCount; i++) {
            address playerAddress = gameState.playerIndices[i];
            if (gameState.playerScores[playerAddress] >= 500) {
                return true;
            }
        }
        return false;
    }

    /// @notice Adds a new player to the game
    /// @param gameState Current game state
    /// @param player Address of the player to add
    function addPlayer(UnoTypes.GameState storage gameState, address player) internal {
        gameState.players[player].isActive = true;
        gameState.playerIndices.push(player);
        gameState.playerCount++;
    }

    /// @notice Advances the game to the next player
    /// @param gameState Current game state
    function advanceToNextPlayer(UnoTypes.GameState storage gameState) internal {
        gameState.currentPlayerIndex = getNextPlayerIndex(gameState, gameState.currentPlayerIndex);
    }

    /// @notice Calculates the index of the next player based on game direction
    /// @param gameState Current game state
    /// @param currentIndex Index of the current player
    /// @return uint8 Index of the next player
    function getNextPlayerIndex(UnoTypes.GameState storage gameState, uint8 currentIndex)
        internal
        view
        returns (uint8)
    {
        if (gameState.isClockwise) {
            return uint8((currentIndex + 1) % gameState.playerCount);
        } else {
            return uint8((currentIndex + gameState.playerCount - 1) % gameState.playerCount);
        }
    }

    /// @notice Gets the address of a player at a specific index
    /// @param gameState Current game state
    /// @param index Player index to lookup
    /// @return address The player's address
    function getPlayerAddress(UnoTypes.GameState storage gameState, uint8 index) internal view returns (address) {
        require(index < gameState.playerCount, "Invalid player index");
        return gameState.playerIndices[index];
    }

    /// @notice Removes a card from a player's hand
    /// @param gameState Current game state
    /// @param player Address of the player
    /// @param handIndex Index of the card in the player's hand
    function removeCardFromHand(UnoTypes.GameState storage gameState, address player, uint8 handIndex) internal {
        UnoTypes.PlayerState storage playerState = gameState.players[player];
        require(handIndex < playerState.hand.length, "Invalid card index");

        // Move the last card to the removed position and pop
        playerState.hand[handIndex] = playerState.hand[playerState.hand.length - 1];
        playerState.hand.pop();
    }

    /// @notice Checks if an address is the current player
    /// @param gameState Current game state
    /// @param player Address to check
    /// @return bool True if the address is the current player
    function isCurrentPlayer(UnoTypes.GameState storage gameState, address player) internal view returns (bool) {
        return getPlayerAddress(gameState, gameState.currentPlayerIndex) == player;
    }

    /// @notice Checks if an address is a valid player in the game
    /// @param gameState Current game state
    /// @param player Address to check
    /// @return bool True if the address is a valid player
    function isValidPlayer(UnoTypes.GameState storage gameState, address player) internal view returns (bool) {
        return gameState.players[player].isActive;
    }
}
