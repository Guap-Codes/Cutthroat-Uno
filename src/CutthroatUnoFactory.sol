// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./CutthroatUnoGame.sol";
import "../test/helpers/UnoGameTestHelper.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

/// @title CutthroatUno Factory Contract
/// @notice Factory contract for creating and managing CutthroatUno game instances
/// @dev Uses the Minimal Proxy Pattern (EIP-1167) to create cheap clone instances of the game
contract CutthroatUnoFactory {
    using Clones for address;

    /// @notice The address of the main game implementation contract
    address public immutable gameImplementation;
    /// @notice The address of the test implementation (same as gameImplementation in test mode)
    address public immutable testImplementation;
    /// @notice The address of the Chainlink VRF Coordinator
    address public immutable vrfCoordinator;
    /// @notice The gas lane key hash used for VRF requests
    bytes32 public immutable gasLane;
    /// @notice The subscription ID for Chainlink VRF
    uint64 public immutable subscriptionId;
    /// @notice The gas limit for the VRF callback
    uint32 public immutable callbackGasLimit;
    /// @notice Flag indicating if the contract is in test mode
    bool public immutable isTestMode;

    /// @notice Mapping of game IDs to their deployed clone addresses
    mapping(uint256 => address) public games;
    /// @notice Total number of games created
    uint256 public gameCount;

    /// @notice Initializes the factory with VRF configuration and deploys implementation contracts
    /// @param _vrfCoordinator Address of the VRF Coordinator
    /// @param _gasLane The gas lane key hash
    /// @param _subscriptionId Chainlink VRF subscription ID
    /// @param _callbackGasLimit Gas limit for VRF callback
    /// @param _isTestMode Whether to deploy in test mode
    constructor(
        address _vrfCoordinator,
        bytes32 _gasLane,
        uint64 _subscriptionId,
        uint32 _callbackGasLimit,
        bool _isTestMode
    ) {
        vrfCoordinator = _vrfCoordinator;
        gasLane = _gasLane;
        subscriptionId = _subscriptionId;
        callbackGasLimit = _callbackGasLimit;
        isTestMode = _isTestMode;

        // Deploy implementation contracts
        if (_isTestMode) {
            gameImplementation =
                address(new UnoGameTestHelper(_vrfCoordinator, _gasLane, _subscriptionId, _callbackGasLimit));
            testImplementation = gameImplementation;
        } else {
            gameImplementation =
                address(new CutthroatUnoGame(_vrfCoordinator, _gasLane, _subscriptionId, _callbackGasLimit));
            testImplementation = address(0);
        }
    }

    /// @notice Creates a new game instance
    /// @param maxPlayers Maximum number of players allowed in the game (2-8)
    /// @return Address of the newly created game
    /// @dev Creates a minimal proxy clone of the implementation and initializes it
    function createGame(uint8 maxPlayers) external returns (address) {
        require(maxPlayers >= 2 && maxPlayers <= 8, "Invalid player count");

        address clone = gameImplementation.clone();
        uint256 newGameId = ++gameCount;
        games[newGameId] = clone;

        // Initialize the game
        CutthroatUnoGame(clone).initialize(newGameId, maxPlayers, msg.sender);

        return clone;
    }

    /// @notice Retrieves the address of a game by its ID
    /// @param gameId The ID of the game to look up
    /// @return The address of the requested game
    function getGame(uint256 gameId) external view returns (address) {
        return games[gameId];
    }
}
