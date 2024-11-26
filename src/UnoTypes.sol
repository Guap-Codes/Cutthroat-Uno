// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title UnoTypes Library
/// @notice Contains all type definitions and events for the Uno game
/// @dev This library defines the core data structures and events used throughout the Uno game implementation
library UnoTypes {
    /// @notice Represents the current state of the game
    enum GameStatus {
        WAITING, // Game is waiting for players to join
        ACTIVE, // Game is currently being played
        FINISHED // Game has concluded

    }

    /// @notice Represents the possible colors in the game
    enum Color {
        RED,
        GREEN,
        BLUE,
        YELLOW,
        WILD // Used for wild cards before color is chosen

    }

    /// @notice Represents the different types of cards in the game
    enum CardType {
        NUMBER, // Regular number cards (0-9)
        REVERSE, // Reverses the direction of play
        SKIP, // Skips the next player's turn
        DRAW_TWO, // Forces next player to draw 2 cards
        WILD, // Player can choose the color
        WILD_DRAW_FOUR, // Choose color and next player draws 4
        WILD_REVERSE // Choose color and reverse direction

    }

    /// @notice Defines when shuffling occurs in the game
    enum ShuffleType {
        INITIAL_SHUFFLE, // First shuffle when game starts
        RESHUFFLE // Reshuffling when deck is depleted

    }

    /// @notice Represents a single Uno card
    /// @dev For number cards, the number field contains 0-9. For special cards, it's unused
    struct Card {
        Color color;
        CardType cardType;
        uint8 number;
    }

    /// @notice Stores the current state of a player
    struct PlayerState {
        bool isActive; // Whether the player is still in the game
        Card[] hand; // Cards in player's hand
        bool hasCalledUno; // Whether player has called Uno
    }

    /// @notice Contains the complete state of an Uno game
    struct GameState {
        GameStatus status;
        uint8 playerCount;
        mapping(address => PlayerState) players;
        mapping(address => uint256) playerScores;
        Card[] deck;
        Card topCard;
        uint8 currentPlayerIndex;
        bool isClockwise;
        uint8 stackedDraws;
        mapping(uint256 => ShuffleRequest) shuffleRequests;
        uint256 roundNumber;
        address[] playerIndices;
    }

    /// @notice Stores information about a shuffle request
    struct ShuffleRequest {
        bool pending;
        uint256 randomWord; // Random number from VRF
        ShuffleType shuffleType;
    }

    // Game Events
    /// @notice Emitted when a new game is created
    event GameInitialized(uint256 indexed gameId, address creator, uint8 maxPlayers);
    /// @notice Emitted when a player joins the game
    event PlayerJoined(uint256 indexed gameId, address player);
    /// @notice Emitted when the game begins
    event GameStarted(uint256 indexed gameId);
    /// @notice Emitted when a round is finished
    event GameFinished(uint256 indexed gameId);
    /// @notice Emitted when the entire game ends with a winner
    event GameEnded(uint256 indexed gameId, address winner);

    // Gameplay Events
    /// @notice Emitted when a player's turn is skipped
    event PlayerSkipped(uint256 indexed gameId, address player);
    /// @notice Emitted when play direction changes
    event DirectionChanged(uint256 indexed gameId, bool isClockwise);
    /// @notice Emitted when active color changes (e.g., after wild card)
    event ColorChanged(uint256 indexed gameId, Color newColor);
    /// @notice Emitted when a card is played
    event CardPlayed(uint256 indexed gameId, address player, Card card);
    /// @notice Emitted when a player draws cards
    event CardsDrawn(uint256 indexed gameId, address player, uint8 count);
    /// @notice Emitted when a player calls Uno
    event UnoCalled(uint256 indexed gameId, address player);

    // VRF Events
    /// @notice Emitted when requesting a shuffle from Chainlink VRF
    event ShuffleRequested(uint256 indexed gameId, uint256 requestId, ShuffleType shuffleType);
    /// @notice Emitted when shuffle is completed
    event ShuffleCompleted(uint256 indexed gameId, ShuffleType shuffleType);

    // Scoring Constants
    /// @notice Points multiplier for number cards
    uint8 constant NUMBER_CARD_MULTIPLIER = 1;
    /// @notice Points for special cards (Skip, Reverse, Draw Two)
    uint8 constant SPECIAL_CARD_POINTS = 20;
    /// @notice Points for wild cards
    uint8 constant WILD_CARD_POINTS = 50;

    // Round Events
    /// @notice Emitted when a round ends
    event RoundEnded(uint256 indexed gameId, uint256 roundNumber);
    /// @notice Emitted when a player's score is updated
    event ScoreUpdated(uint256 indexed gameId, address player, uint256 score);
}
