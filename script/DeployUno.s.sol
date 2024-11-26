// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Script.sol";
import "../src/CutthroatUnoFactory.sol";
import "../src/CutthroatUnoGame.sol";

/// @title Cutthroat UNO Deployment Script
/// @notice Script to deploy the Cutthroat UNO Factory contract with Chainlink VRF configuration
/// @dev Uses Foundry's Script contract for deployment automation
contract DeployUno is Script {
    // Chainlink VRF Configuration Constants
    /// @dev Chainlink VRF Coordinator address for Sepolia testnet
    address constant VRF_COORDINATOR = 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625;

    /// @dev Chainlink VRF gas lane key hash for Sepolia
    /// @notice Determines the gas price ceiling for VRF requests
    bytes32 constant GAS_LANE = 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;

    /// @dev Your Chainlink VRF subscription ID
    /// @notice Must be updated with a valid subscription ID before deployment
    uint64 constant SUBSCRIPTION_ID = 0;

    /// @dev Maximum gas allowed for the VRF callback
    /// @notice Ensures VRF callbacks have enough gas to complete
    uint32 constant CALLBACK_GAS_LIMIT = 2500000;

    /// @notice Main deployment function
    /// @dev Deploys the CutthroatUnoFactory contract with VRF configuration
    function run() external {
        // Retrieve deployer's private key from environment variables
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Start broadcasting transactions from the deployer's address
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the factory contract with VRF parameters
        new CutthroatUnoFactory(
            VRF_COORDINATOR, // VRF coordinator contract address
            GAS_LANE, // VRF gas lane key hash
            SUBSCRIPTION_ID, // Chainlink VRF subscription ID
            CALLBACK_GAS_LIMIT, // Maximum gas for VRF callback
            false // Production mode flag (false for testing)
        );

        // Stop broadcasting transactions
        vm.stopBroadcast();
    }
}
