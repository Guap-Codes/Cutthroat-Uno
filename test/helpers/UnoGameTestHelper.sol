// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../src/CutthroatUnoGame.sol";
import "../../src/UnoTypes.sol";

/// @title UnoGameTestHelper
/// @notice Test helper contract that extends CutthroatUnoGame with additional functions for testing
/// @dev Exposes internal functions and adds helper methods to facilitate testing of game mechanics
contract UnoGameTestHelper is CutthroatUnoGame {
    constructor(address vrfCoordinator, bytes32 gasLane, uint64 subscriptionId, uint32 callbackGasLimit)
        CutthroatUnoGame(vrfCoordinator, gasLane, subscriptionId, callbackGasLimit)
    {}

    /// @notice Sets the basic game state parameters for testing
    /// @param _playerCount Number of players in the game
    /// @param _currentIndex Current player's turn index
    /// @param _isClockwise Direction of play
    function setGameStateForTest(uint8 _playerCount, uint8 _currentIndex, bool _isClockwise) public {
        gameState.playerCount = _playerCount;
        gameState.currentPlayerIndex = _currentIndex;
        gameState.isClockwise = _isClockwise;
        gameState.status = UnoTypes.GameStatus.ACTIVE;
    }

    /// @notice Gets the next player's index based on current game direction
    /// @param currentIndex The current player's index
    /// @return The index of the next player
    function getNextPlayerIndexForTest(uint8 currentIndex) public view returns (uint8) {
        return UnoGameLogic.getNextPlayerIndex(gameState, currentIndex);
    }

    /// @notice Sets a player's score for testing purposes
    /// @param player Address of the player
    /// @param score Score to set for the player
    function setPlayerScoreForTest(address player, uint256 score) public {
        gameState.playerScores[player] = score;
    }

    /// @notice Checks if the game has ended based on current game state
    /// @return bool True if game has ended, false otherwise
    function checkGameEndForTest() public view returns (bool) {
        return UnoGameLogic.checkGameEnd(gameState);
    }

    /// @notice Retrieves the current status of the game
    /// @return UnoTypes.GameStatus Current game status (WAITING, ACTIVE, or FINISHED)
    function getGameStatusForTest() public view returns (UnoTypes.GameStatus) {
        return gameState.status;
    }

    /// @notice Gets the total number of players in the game
    /// @return uint8 Number of players currently in the game
    function getPlayerCountForTest() public view returns (uint8) {
        return gameState.playerCount;
    }

    /// @notice Gets the active status and UNO call status for a specific player
    /// @param player Address of the player to check
    /// @return isActive Whether the player is active in the game
    /// @return hasCalledUno Whether the player has called UNO
    function getPlayerStateForTest(address player) public view returns (bool isActive, bool hasCalledUno) {
        return (gameState.players[player].isActive, gameState.players[player].hasCalledUno);
    }

    /// @notice Gets the index of the player whose turn it currently is
    /// @return uint8 Current player's index in the game
    function getCurrentPlayerIndexForTest() public view returns (uint8) {
        return gameState.currentPlayerIndex;
    }

    /// @notice Gets the number of cards in a player's hand
    /// @param player Address of the player to check
    /// @return uint256 Number of cards in the player's hand
    function getPlayerHandSizeForTest(address player) public view returns (uint256) {
        return gameState.players[player].hand.length;
    }

    /// @notice Gets the number of cards remaining in the deck
    /// @return uint256 Number of cards in the deck
    function getDeckSizeForTest() public view returns (uint256) {
        return gameState.deck.length;
    }

    /// @notice Gets the current direction of play
    /// @return bool True if clockwise, false if counter-clockwise
    function getGameDirectionForTest() public view returns (bool) {
        return gameState.isClockwise;
    }

    /// @notice Gets the number of accumulated draw cards that must be drawn by the next player
    /// @return uint8 Number of stacked draw cards
    function getStackedDrawsForTest() public view returns (uint8) {
        return gameState.stackedDraws;
    }

    /// @notice Gets the current round number
    /// @return uint256 Current round number
    function getRoundNumberForTest() public view returns (uint256) {
        return gameState.roundNumber;
    }

    /// @notice Gets the card currently on top of the discard pile
    /// @return UnoTypes.Card The current top card
    function getTopCardForTest() public view returns (UnoTypes.Card memory) {
        return gameState.topCard;
    }

    /// @notice Processes the effects of a special card (Skip, Reverse, Draw Two, etc.)
    /// @param card The special card being played
    /// @param declaredColor The color declared when playing a wild card
    function handleSpecialCardForTest(UnoTypes.Card memory card, UnoTypes.Color declaredColor) public {
        UnoGameLogic.handleSpecialCard(gameState, card, declaredColor, gameId);
    }

    /// @notice Calculates the point value of a specific card
    /// @param card The card to calculate points for
    /// @return uint256 Point value of the card
    function calculateCardPointsForTest(UnoTypes.Card memory card) public pure returns (uint256) {
        return UnoGameLogic.calculateCardPoints(card);
    }

    /// @notice Advances the game to the next player's turn
    function advanceToNextPlayerForTest() public {
        UnoGameLogic.advanceToNextPlayer(gameState);
    }

    /// @notice Initiates the game, dealing cards and setting initial game state
    function startGameForTest() public {
        _startGame();
    }

    /// @notice Sets the top card of the discard pile
    /// @param card The card to set as the top card
    function setTopCardForTest(UnoTypes.Card memory card) public {
        gameState.topCard = card;
    }

    /// @notice Sets the order of players in the game
    /// @param players Array of player addresses in desired order
    function setPlayerIndicesForTest(address[] memory players) public {
        for (uint256 i = 0; i < players.length; i++) {
            gameState.playerIndices.push(players[i]);
        }
    }

    /// @notice Simulates drawing a single card for the calling player
    /// @dev Emits a CardsDrawn event after drawing
    function drawCard() public {
        _drawCardToPlayer(msg.sender);
        emit UnoTypes.CardsDrawn(gameId, msg.sender, 1);
    }

    /// @notice Allows a player to play a card from their hand
    /// @param handIndex Index of the card in the player's hand
    /// @param declaredColor Color to declare if playing a wild card
    /// @dev Overrides the base contract's playCard function
    function playCard(uint8 handIndex, UnoTypes.Color declaredColor) public override {
        require(UnoGameLogic.isCurrentPlayer(gameState, msg.sender), "Not your turn");
        require(UnoGameLogic.isValidPlayer(gameState, msg.sender), "Not a valid player");

        UnoTypes.Card memory cardToPlay = gameState.players[msg.sender].hand[handIndex];
        require(UnoGameLogic.isValidPlay(gameState, cardToPlay), "Invalid play");

        UnoGameLogic.handleSpecialCard(gameState, cardToPlay, declaredColor, gameId);
        UnoGameLogic.removeCardFromHand(gameState, msg.sender, handIndex);

        if (UnoGameLogic.checkRoundEnd(gameState, msg.sender)) {
            UnoGameLogic.handleRoundEnd(gameState, gameId);

            if (UnoGameLogic.checkGameEnd(gameState)) {
                gameState.status = UnoTypes.GameStatus.FINISHED;
                emit GameFinished(gameId);
            } else {
                _startNewRound();
            }
        }
    }

    /// @notice Allows a player to join the game
    /// @dev Overrides the base contract's joinGame function
    function joinGame() public override {
        require(gameState.status == UnoTypes.GameStatus.WAITING, "Game not joinable");
        require(gameState.playerCount < maxPlayers, "Game full");
        require(!gameState.players[msg.sender].isActive, "Already joined");

        gameState.players[msg.sender].isActive = true;
        gameState.playerCount++;

        emit PlayerJoined(gameId, msg.sender);

        if (gameState.playerCount == maxPlayers) {
            _startGame();
        }
    }

    /// @notice Allows a player to call "UNO" when they have one card remaining
    /// @dev Overrides the base contract's callUno function
    function callUno() public override {
        require(UnoGameLogic.isValidPlayer(gameState, msg.sender), "Not a valid player");
        require(gameState.players[msg.sender].hand.length == 1, "Too many cards");
        gameState.players[msg.sender].hasCalledUno = true;
    }

    /// @notice Draws multiple cards for testing purposes
    /// @param count Number of cards to draw
    /// @dev Emits a single CardsDrawn event after drawing all cards
    function drawMultipleCards(uint8 count) public {
        for (uint8 i = 0; i < count; i++) {
            _drawCardToPlayer(msg.sender);
        }
        emit UnoTypes.CardsDrawn(gameId, msg.sender, count);
    }

    /// @notice Gets the current hand of a specified player
    /// @param player Address of the player whose hand to retrieve
    /// @return Array of Card structs representing the player's hand
    function getPlayerHand(address player) public view returns (UnoTypes.Card[] memory) {
        return gameState.players[player].hand;
    }
}
