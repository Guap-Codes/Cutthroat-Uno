// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "./UnoTypes.sol";
import "./UnoGameLogic.sol";

/// @title CutthroatUnoGame
/// @notice A decentralized implementation of Uno card game using Chainlink VRF for shuffling
/// @dev Inherits from Initializable, ReentrancyGuard, and VRFConsumerBaseV2
contract CutthroatUnoGame is Initializable, ReentrancyGuard, VRFConsumerBaseV2 {
    using UnoGameLogic for UnoTypes.GameState;
    using UnoTypes for UnoTypes.Card;

    /// @notice Chainlink VRF configuration variables used for secure random number generation
    /// @dev These variables are immutable and set during contract deployment

    /// @dev Interface for interacting with Chainlink's VRF Coordinator contract
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;

    /// @dev The gas lane key hash value that determines the maximum gas price you are willing to pay for a request in wei
    bytes32 private immutable i_gasLane;

    /// @dev Your subscription ID for funding VRF requests
    uint64 private immutable i_subscriptionId;

    /// @dev Maximum gas limit allowed for the VRF callback function
    uint32 private immutable i_callbackGasLimit;

    /// @dev Number of confirmations required before the VRF response is considered valid
    /// @dev Higher values mean more security but longer waiting times
    uint16 private constant REQUEST_CONFIRMATIONS = 3;

    /// @dev Number of random values to request from the VRF service
    /// @dev Set to 1 as we only need a single random number for shuffling
    uint32 private constant NUM_WORDS = 1;

    /// @notice Events emitted during deck shuffling operations
    /// @param gameId The unique identifier for the game
    /// @param requestId The Chainlink VRF request identifier
    /// @param shuffleType The type of shuffle being performed (initial or reshuffle)
    event ShuffleRequested(uint256 indexed gameId, uint256 requestId, UnoTypes.ShuffleType shuffleType);
    event ShuffleCompleted(uint256 indexed gameId, UnoTypes.ShuffleType shuffleType);

    // Game state
    /// @notice Unique identifier for the current game instance
    uint256 public gameId;

    /// @notice Address of the factory contract that created this game instance
    address public factory;

    /// @notice Address of the player who created this game
    address public creator;

    /// @notice Maximum number of players allowed in this game (2-4 players)
    uint8 public maxPlayers;

    /// @notice Main game state containing all game-related data
    /// @dev Includes player information, deck, current turn, and game status
    UnoTypes.GameState public gameState;

    /// @notice Core game events
    /// @notice Emitted when a new game is initialized
    /// @param gameId The unique identifier for the game
    /// @param creator Address of the game creator
    /// @param maxPlayers Maximum number of players allowed
    event GameInitialized(uint256 indexed gameId, address creator, uint8 maxPlayers);

    /// @notice Emitted when a player joins the game
    /// @param gameId The unique identifier for the game
    /// @param player Address of the player joining
    event PlayerJoined(uint256 indexed gameId, address player);

    /// @notice Emitted when the game starts
    /// @param gameId The unique identifier for the game
    event GameStarted(uint256 indexed gameId);

    /// @notice Emitted when the game finishes
    /// @param gameId The unique identifier for the game
    event GameFinished(uint256 indexed gameId);

    // Modifiers
    /// @notice Restricts function access to only the factory contract that created this game instance
    /// @dev Used to prevent unauthorized initialization and configuration of game instances
    /// @custom:throws "Only factory can call" if called by any address other than the factory
    modifier onlyFactory() {
        require(msg.sender == factory, "Only factory can call");
        _;
    }

    /// @notice Ensures functions can only be called when the game is in an active state
    /// @dev Active state means the game has started and hasn't finished yet
    /// @custom:throws "Game not active" if the game status is not GameStatus.ACTIVE
    modifier onlyActive() {
        require(gameState.status == UnoTypes.GameStatus.ACTIVE, "Game not active");
        _;
    }

    // Constants for deck composition
    /// @notice Constants defining the deck composition and initial game setup
    /// @dev Total cards per color (25) breakdown:
    ///      - One '0' card (1)
    ///      - Two each of '1' through '9' cards (18)
    ///      - Two each of Skip, Reverse, and Draw Two cards (6)
    uint8 private constant CARDS_PER_COLOR = 25;

    /// @notice Number of standard Wild cards in the deck
    /// @dev These cards allow players to change the active color without additional effects
    uint8 private constant WILD_CARDS = 8;

    /// @notice Number of Wild Draw Four cards in the deck
    /// @dev These cards force the next player to draw 4 cards and lose their turn
    uint8 private constant WILD_DRAW_FOUR_CARDS = 4;

    /// @notice Number of Wild Reverse cards in the deck
    /// @dev These cards change the direction of play and allow color change
    uint8 private constant WILD_REVERSE_CARDS = 4;

    /// @notice Number of cards dealt to each player at the start of a round
    uint8 private constant INITIAL_HAND_SIZE = 7;

    /// @notice Mapping to track player scores
    /// @dev Scores persist across multiple rounds until game end
    mapping(address => uint256) public playerScores;
    /// @notice Maximum score limit for the game
    /// @dev When any player reaches or exceeds this score, the game ends
    /// @dev Scoring: Number cards = face value, Action cards = 20 points,
    ///      Wild cards = 50 points, Wild Draw Four/Reverse = 50 points
    uint256 public constant SCORE_LIMIT = 500;

    constructor(address vrfCoordinator, bytes32 gasLane, uint64 subscriptionId, uint32 callbackGasLimit)
        VRFConsumerBaseV2(vrfCoordinator)
    {
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
    }

    /// @notice Initializes a new game instance
    /// @param _gameId Unique identifier for this game
    /// @param _maxPlayers Maximum number of players allowed
    /// @param _creator Address of the game creator
    function initialize(uint256 _gameId, uint8 _maxPlayers, address _creator) external initializer {
        gameId = _gameId;
        factory = msg.sender;
        creator = _creator;
        maxPlayers = _maxPlayers;
        gameState.status = UnoTypes.GameStatus.WAITING;
        gameState.isClockwise = true;
        emit GameInitialized(_gameId, _creator, _maxPlayers);
    }

    /// @notice Allows a player to join the game
    /// @dev Automatically starts the game when maximum players are reached
    function joinGame() external virtual nonReentrant {
        require(gameState.status == UnoTypes.GameStatus.WAITING, "Game not joinable");
        require(gameState.playerCount < maxPlayers, "Game full");
        require(!gameState.players[msg.sender].isActive, "Already joined");

        // Add player
        gameState.players[msg.sender].isActive = true;
        gameState.playerCount++;

        emit PlayerJoined(gameId, msg.sender);

        // Start game if full
        if (gameState.playerCount == maxPlayers) {
            _startGame();
        }
    }

    // Internal functions
    /// @notice Starts a new game when enough players have joined
    /// @dev Initializes game state, creates deck, and requests initial shuffle
    function _startGame() internal {
        require(gameState.status == UnoTypes.GameStatus.WAITING, "Game not in waiting state");
        require(gameState.playerCount >= 2, "Not enough players");

        gameState.status = UnoTypes.GameStatus.ACTIVE;
        gameState.isClockwise = true;
        gameState.currentPlayerIndex = 0;
        gameState.stackedDraws = 0;

        _initializeDeck();
        _requestShuffle(UnoTypes.ShuffleType.INITIAL_SHUFFLE);
    }

    /// @notice Requests a new random number from Chainlink VRF for deck shuffling
    /// @dev Creates a shuffle request and emits event for tracking
    /// @param shuffleType The type of shuffle being requested (initial or reshuffle)
    function _requestShuffle(UnoTypes.ShuffleType shuffleType) internal {
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane, i_subscriptionId, REQUEST_CONFIRMATIONS, i_callbackGasLimit, NUM_WORDS
        );

        gameState.shuffleRequests[requestId] =
            UnoTypes.ShuffleRequest({pending: true, randomWord: 0, shuffleType: shuffleType});

        emit ShuffleRequested(gameId, requestId, shuffleType);
    }

    /// @notice Callback function for Chainlink VRF to provide random numbers
    /// @dev Handles both initial shuffle (with dealing) and regular reshuffles
    /// @param requestId The ID of the random number request
    /// @param randomWords Array of random values provided by Chainlink
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        UnoTypes.ShuffleRequest storage request = gameState.shuffleRequests[requestId];
        require(request.pending, "Request not found");

        request.pending = false;
        request.randomWord = randomWords[0];

        if (request.shuffleType == UnoTypes.ShuffleType.INITIAL_SHUFFLE) {
            _shuffleDeck(randomWords[0]);
            _dealInitialHands();
            _setInitialTopCard();
            emit GameStarted(gameId);
        } else {
            _shuffleDeck(randomWords[0]);
        }

        emit ShuffleCompleted(gameId, request.shuffleType);
    }

    /// @notice Creates a new complete Uno deck with all card types
    /// @dev Adds number cards (0-9), action cards, and wild cards for each color
    function _initializeDeck() internal {
        // Clear existing deck if any
        delete gameState.deck;

        // Add number cards (0-9) for each color
        for (uint8 colorIndex = 0; colorIndex < 4; colorIndex++) {
            UnoTypes.Color color = UnoTypes.Color(colorIndex);

            // Add one 0 card
            gameState.deck.push(UnoTypes.Card({color: color, cardType: UnoTypes.CardType.NUMBER, number: 0}));

            // Add two of each number 1-9
            for (uint8 number = 1; number <= 9; number++) {
                for (uint8 i = 0; i < 2; i++) {
                    gameState.deck.push(
                        UnoTypes.Card({color: color, cardType: UnoTypes.CardType.NUMBER, number: number})
                    );
                }
            }

            // Add special cards (2 each per color)
            for (uint8 i = 0; i < 2; i++) {
                // Skip cards
                gameState.deck.push(UnoTypes.Card({color: color, cardType: UnoTypes.CardType.SKIP, number: 0}));

                // Reverse cards
                gameState.deck.push(UnoTypes.Card({color: color, cardType: UnoTypes.CardType.REVERSE, number: 0}));

                // Draw Two cards
                gameState.deck.push(UnoTypes.Card({color: color, cardType: UnoTypes.CardType.DRAW_TWO, number: 0}));
            }
        }

        // Add Wild cards
        for (uint8 i = 0; i < WILD_CARDS; i++) {
            gameState.deck.push(
                UnoTypes.Card({color: UnoTypes.Color.WILD, cardType: UnoTypes.CardType.WILD, number: 0})
            );
        }

        // Add Wild Draw Four cards
        for (uint8 i = 0; i < WILD_DRAW_FOUR_CARDS; i++) {
            gameState.deck.push(
                UnoTypes.Card({color: UnoTypes.Color.WILD, cardType: UnoTypes.CardType.WILD_DRAW_FOUR, number: 0})
            );
        }

        // Add Wild Reverse cards
        for (uint8 i = 0; i < WILD_REVERSE_CARDS; i++) {
            gameState.deck.push(
                UnoTypes.Card({color: UnoTypes.Color.WILD, cardType: UnoTypes.CardType.WILD_REVERSE, number: 0})
            );
        }
    }

    /// @notice Shuffles the deck using Fisher-Yates algorithm
    /// @dev Uses provided seed from Chainlink VRF for randomization
    /// @param seed Random value used as basis for shuffle
    function _shuffleDeck(uint256 seed) internal {
        uint256 deckSize = gameState.deck.length;

        for (uint256 i = deckSize - 1; i > 0; i--) {
            uint256 j = uint256(keccak256(abi.encode(seed, i))) % (i + 1);

            UnoTypes.Card memory temp = gameState.deck[i];
            gameState.deck[i] = gameState.deck[j];
            gameState.deck[j] = temp;
        }
    }

    /// @notice Deals initial hands to all active players
    /// @dev Iterates through all possible addresses to find active players
    /// @dev Each player receives INITIAL_HAND_SIZE cards
    function _dealInitialHands() internal {
        uint8 playerIndex = 0;

        // Iterate through all possible addresses to find active players
        for (uint160 i = 0; i < type(uint160).max; i++) {
            address playerAddress = address(i);
            if (gameState.players[playerAddress].isActive) {
                // Deal INITIAL_HAND_SIZE cards to each player
                for (uint8 j = 0; j < INITIAL_HAND_SIZE; j++) {
                    _drawCardToPlayer(playerAddress);
                }
                playerIndex++;

                // Break if we've dealt to all players
                if (playerIndex >= gameState.playerCount) {
                    break;
                }
            }
        }
    }

    /// @notice Sets the initial top card for the game
    /// @dev Draws cards until finding a non-wild card
    /// @dev Requests reshuffle if wild card is drawn
    function _setInitialTopCard() internal {
        while (gameState.deck.length > 0) {
            UnoTypes.Card memory card = _drawCard();
            if (card.color != UnoTypes.Color.WILD) {
                gameState.topCard = card;
                return;
            }
            // If we drew a wild card, request new random number for position
            _requestShuffle(UnoTypes.ShuffleType.RESHUFFLE);
            gameState.deck.push(card);
        }
        revert("No valid initial card found");
    }

    /// @notice Draws a card from the deck and adds it to player's hand
    /// @dev Requires non-empty deck
    /// @param player Address of the player receiving the card
    function _drawCardToPlayer(address player) internal {
        require(gameState.deck.length > 0, "Deck is empty");
        UnoTypes.Card memory drawnCard = _drawCard();
        gameState.players[player].hand.push(drawnCard);
    }

    /// @notice Draws a single card from the deck
    /// @dev Requests reshuffle when deck is running low (≤10 cards)
    /// @return UnoTypes.Card The drawn card
    function _drawCard() internal returns (UnoTypes.Card memory) {
        require(gameState.deck.length > 0, "Deck is empty");

        // Request reshuffle if deck is running low
        if (gameState.deck.length <= 10) {
            _requestShuffle(UnoTypes.ShuffleType.RESHUFFLE);
        }

        uint256 lastIndex = gameState.deck.length - 1;
        UnoTypes.Card memory drawnCard = gameState.deck[lastIndex];
        gameState.deck.pop();
        return drawnCard;
    }

    /// @notice Allows a player to play a card from their hand
    /// @param handIndex Index of the card in player's hand
    /// @param declaredColor Color to be declared when playing a wild card
    function playCard(uint8 handIndex, UnoTypes.Color declaredColor) external virtual onlyActive nonReentrant {
        require(gameState.isCurrentPlayer(msg.sender), "Not your turn");
        require(gameState.isValidPlayer(msg.sender), "Not a valid player");

        UnoTypes.Card memory cardToPlay = gameState.players[msg.sender].hand[handIndex];
        require(gameState.isValidPlay(cardToPlay), "Invalid play");

        gameState.handleSpecialCard(cardToPlay, declaredColor, gameId);
        gameState.removeCardFromHand(msg.sender, handIndex);

        if (gameState.checkRoundEnd(msg.sender)) {
            gameState.handleRoundEnd(gameId);

            if (gameState.checkGameEnd()) {
                gameState.status = UnoTypes.GameStatus.FINISHED;
                emit GameFinished(gameId);
            } else {
                _startNewRound();
            }
        }
    }

    /// @notice Allows a player to call "Uno" when they have one card remaining
    /// @dev Must be called before playing the second-to-last card to avoid penalties
    function callUno() external virtual onlyActive nonReentrant {
        require(gameState.isValidPlayer(msg.sender), "Not a valid player");
        require(gameState.players[msg.sender].hand.length == 1, "Too many cards");
        gameState.players[msg.sender].hasCalledUno = true;
    }

    function _startNewRound() internal {
        gameState.isClockwise = true;
        gameState.currentPlayerIndex = 0;
        gameState.stackedDraws = 0;

        for (uint160 i = 0; i < type(uint160).max; i++) {
            address playerAddress = address(i);
            if (gameState.players[playerAddress].isActive) {
                delete gameState.players[playerAddress].hand;
                gameState.players[playerAddress].hasCalledUno = false;
            }
        }

        _initializeDeck();
        _requestShuffle(UnoTypes.ShuffleType.INITIAL_SHUFFLE);
    }

    /// @notice Validates if a card can be played on the current top card
    /// @param card The card to validate
    /// @return bool Returns true if the play is valid
    function validatePlay(UnoTypes.Card memory card) public view returns (bool) {
        return UnoGameLogic.isValidPlay(gameState, card);
    }
}
