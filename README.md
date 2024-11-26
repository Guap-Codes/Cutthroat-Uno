# Cutthroat UNO Smart Contract 🎴

A fully on-chain implementation of the classic UNO card game with a competitive twist, built using Solidity and Chainlink VRF for verifiable randomness.

## Overview 🎯

Cutthroat UNO is a blockchain-based version of UNO where players compete to reach 500 points. The game uses Chainlink VRF (Verifiable Random Function) for fair card shuffling and implements all classic UNO rules with additional special cards.

### Features ✨

- Full UNO ruleset implementation
- Chainlink VRF for verifiable random card shuffling
- Support for 2-8 players
- Factory pattern for easy game creation
- Comprehensive testing suite with fuzzing
- Special cards including Wild Reverse
- Point-based scoring system

## Technical Stack 🛠

- Solidity ^0.8.24
- Foundry (for testing and deployment)
- OpenZeppelin Contracts
- Chainlink VRF v2
- Minimal Proxy Pattern (EIP-1167)

## Game Rules 📜

- Players take turns playing cards matching by color, number, or type
- Special cards: Skip, Reverse, Draw Two, Wild, Wild Draw Four, Wild Reverse
- First player to reach 500 points wins
- Points are calculated based on cards remaining in opponents' hands:
  - Number cards: Face value
  - Special cards (Skip, Reverse, Draw Two): 20 points
  - Wild cards: 50 points

## Installation 🔧

1. Clone the repository:

```git clone https://github.com/guap-codes/cutthroat-uno.git```

2. Install dependencies:

```bash
forge install
```

3. Copy the environment file and fill in your values:

```bash
cp .env.example .env
```

## Configuration ⚙️

Create a `.env` file with the following variables:

```env
PRIVATE_KEY=your_wallet_private_key_here
SEPOLIA_RPC_URL=your_sepolia_rpc_url_here
MAINNET_RPC_URL=your_mainnet_rpc_url_here
ETHERSCAN_API_KEY=your_etherscan_api_key_here
VRF_SUBSCRIPTION_ID=your_vrf_subscription_id_here
```

## Testing 🧪

Run the comprehensive test suite:

```bash
# Run all tests
forge test

# Run tests with verbosity
forge test -vvv

# Run specific test file
forge test --match-path test/UnoGameTest.t.sol

# Run fuzzing tests
forge test --match-path test/UnoGameFuzz.t.sol
```

## Deployment 🚀

1. Configure your Chainlink VRF subscription ID in `script/DeployUno.s.sol`

2. Deploy to testnet (Sepolia):

```bash
forge script script/DeployUno.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
```

## Contract Architecture 📐

- `CutthroatUnoFactory.sol`: Factory contract for creating game instances
- `CutthroatUnoGame.sol`: Main game implementation
- `UnoTypes.sol`: Type definitions and events
- `UnoGameLogic.sol`: Core game mechanics and validation

## Testing Coverage 🎯

The project includes:
- Unit tests
- Fuzz tests
- Invariant tests
- Integration tests with Chainlink VRF (coming soon!!)

## Security Considerations 🔒

- Chainlink VRF for verifiable randomness
- Access control for game actions
- Validation for all player moves
- Protection against common attack vectors

## Contributing 🤝

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License 📄

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments 🙏

- Chainlink VRF for random number generation
- OpenZeppelin for contract standards
- Foundry for development framework


