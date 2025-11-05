# 🚀 AAVE Autopilot Vault (Sepolia)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Built with Foundry](https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg)](https://getfoundry.sh/)
[![Test Status](https://github.com/Moses-main/aave-autopilot/actions/workflows/test.yml/badge.svg)](https://github.com/Moses-main/aave-autopilot/actions)
[![Coverage Status](https://coveralls.io/repos/github/Moses-main/aave-autopilot/badge.svg?branch=main)](https://coveralls.io/github/Moses-main/aave-autopilot?branch=main)

An ERC-4626 vault that automates Aave v3 position management on Sepolia with Chainlink Automation to prevent liquidations.

## Features

- **Automated Health Factor Management**: Monitors and maintains healthy positions on Aave v3 (Sepolia)
- **Chainlink Automation**: Uses Chainlink Keepers for automated rebalancing
- **Gas Efficient**: Optimized for minimal gas usage on Sepolia
- **Secure**: Implements OpenZeppelin's security patterns
- **Fork Testing**: Supports local forked testing on Ethereum Sepolia
- **Sepolia Deployment**: Pre-configured for Ethereum Sepolia testnet

## Architecture

```
┌─────────────┐    ┌───────────────────┐    ┌─────────────┐
│             │    │                   │    │             │
│   User      │───▶│  AaveAutopilot    │◀──▶│  Aave V3    │
│             │    │  (ERC-4626 Vault) │    │  Protocol   │
└─────────────┘    └────────┬──────────┘    └─────────────┘
                            │
                            │  Monitors
                            ▼
                   ┌───────────────────┐
                   │  Chainlink       │
                   │  Automation      │
                   └───────────────────┘
```

## Setup

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [jq](https://stedolan.github.io/jq/download/) (for deployment scripts)
- [Git](https://git-scm.com/)
- [Sepolia ETH](https://sepoliafaucet.com/)
- [Sepolia LINK](https://faucets.chain.link/sepolia)

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/Moses-main/aave-autopilot.git
   cd aave-autopilot
   ```

2. Install dependencies:
   ```bash
   forge install
   ```

3. Set up environment variables:
   ```bash
   cp .env.example .env
   # Edit .env with your private key and API keys
   ```

2. Install dependencies:
   ```bash
   forge install
   ```

3. Set up environment variables:
   Create a `.env` file in the root directory with the following content:
   ```bash
   # Network RPC URLs
   # RPC Configuration
   FORKED_URL=https://soft-distinguished-uranium.ethereum-sepolia.quiknode.pro/e28e07caa3efb8c50dc2a28854dd53578f91626c/
   RPC_URL=https://eth-sepolia.g.alchemy.com/v2/your-api-key
   
   # Deployment
   PRIVATE_KEY=your_private_key_here
   ETHERSCAN_API_KEY=your_etherscan_api_key
   
   # Contract addresses (Ethereum Sepolia)
   VAULT_ADDRESS=0xaE2202566bE5325e2A5746b66E13F0D6f7E248b6
   ```

## Testing

### Run Tests

```bash
# Run unit tests
forge test

# Run tests with gas report
forge test --gas-report

# Run forked tests against Sepolia
forge test --fork-url $SEPOLIA_RPC_URL -vvv

# Run with coverage report
forge coverage --fork-url $SEPOLIA_RPC_URL
```

## Deployment

### Deploy to Sepolia

1. Start a local Anvil node forked from Sepolia:
   ```bash
   anvil --fork-url $FORKED_URL
   ```

2. In a new terminal, deploy to the forked network:
   ```bash
   source .env
   forge script script/DeployForked.s.sol --rpc-url http://localhost:8545 --broadcast -vvvv --private-key $PRIVATE_KEY
   ```

### Deployment to Ethereum Sepolia Testnet

1. Deploy to Ethereum Sepolia:
   ```bash
   source .env
   forge script script/DeployForked.s.sol \
     --rpc-url $RPC_URL \
     --broadcast \
     --verify \
     -vvvv \
     --private-key $PRIVATE_KEY \
     --etherscan-api-key $ETHERSCAN_API_KEY
   ```

2. After deployment, update your `.env` with the deployed contract address:
   ```bash
   echo "VAULT_ADDRESS=0xDeployedContractAddress" >> .env
   ```

## Chainlink Automation Setup

After deployment, register your contract with Chainlink Automation:

1. Fund your contract with LINK tokens for payment
2. Register the contract with the Chainlink Automation Registry
3. Set up the appropriate trigger conditions (health factor threshold)

Example registration parameters:
- Name: AaveAutopilot Keeper
- Gas Limit: 500,000
- Trigger Type: Custom Logic
- Check Data: Encoded user address (or empty for all users)
- Gas Lane: 500 gwei
- Amount: 5 LINK

## Security

### Audits

This code has not been audited. Use at your own risk.

### Security Features

- Reentrancy protection with OpenZeppelin's ReentrancyGuard
- Role-based access control
- Pausable functionality for emergency stops
- Input validation
- Secure token handling with OpenZeppelin's SafeERC20

### Known Limitations

- The keeper may not be able to rebalance if gas prices are extremely high
- The contract doesn't handle all edge cases of Aave v3's complex liquidation mechanics
- The keeper may need to be topped up with ETH for gas costs

## License

MIT

## 📖 Overview

The AAVE Autopilot Vault provides a simple interface for users to deposit USDC, which is then automatically supplied to AAVE v3 to earn yield. The vault actively manages the health factor of the position and automatically rebalances when necessary to prevent liquidations, providing a hands-off DeFi experience.

### ✨ Key Features

- **Automated Health Factor Management**: Continuously monitors and maintains optimal health factor (target: 1.5x, minimum: 1.05x)
- **Chainlink Price Feeds**: Uses real-time ETH/USD price data for accurate collateral valuation
- **Chainlink Keepers Integration**: Automated rebalancing when health factor falls below threshold (1.1x)
- **Gas Optimization**: Optimized for Base network's gas efficiency with minimal external calls
- **Security First**: Implements reentrancy protection, pausable functionality, and access control
- **ERC-4626 Standard**: Fully compliant with the ERC-4626 tokenized vault standard
- **Comprehensive Testing**: Extensive test suite covering edge cases and security scenarios
- **Ethereum Sepolia Ready**: Pre-configured for Ethereum Sepolia testnet with easy mainnet deployment

## 🚀 Project Status

### Current Stage: Beta (Testnet)

- **Deployed Contract Address (Base Sepolia)**: [`0xb896DaacC1987B2A547e101EA8334Cf3aB0AC19a`](https://sepolia.basescan.org/address/0xb896DaacC1987B2A547e101EA8334Cf3aB0AC19a)
- **Test Coverage**: 85%+
- **Audit Status**: Pending
- **Mainnet Readiness**: Under Review

### Key Milestones

- [x] Core smart contract development
- [x] Comprehensive test suite
- [x] Ethereum Sepolia deployment
- [ ] Security audit
- [ ] Mainnet deployment
- [ ] Frontend integration
- [ ] DAO governance

## 🚀 Quick Start

### Prerequisites

- [Foundry](https://getfoundry.sh/) (latest version recommended)
- [Node.js](https://nodejs.org/) v16+ (for deployment scripts)
- [Git](https://git-scm.com/)
- [Slither](https://github.com/crytic/slither) (for static analysis, optional)

### Installation

```bash
# Clone the repository
git clone https://github.com/Moses-main/aave-autopilot.git
cd aave-autopilot

# Install Foundry (if not already installed)
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Install dependencies
forge install

# Build the project
forge build
```

### Running Tests

```bash
# Run all tests
forge test -vvv

# Run tests with gas reporting
forge test --gas-report

# Run specific test
forge test --match-test testDeposit -vvv
```

## 🏗️ Deployment

### Environment Setup

1. Create a `.env` file in the project root:

```bash
# Required
PRIVATE_KEY=your_private_key_here
RPC_URL=https://sepolia.base.org

# Optional (for verification)
ETHERSCAN_API_KEY=your_etherscan_api_key

# Testnet Configuration (Base Sepolia)
USDC=0x036CbD53842c5426634e7929541eC2318f3dCF7e
AAVE_POOL=0x6dcb6D1E0D487EDAE6B45D1d1B86e1A4AD8d4a2C
AAVE_DATA_PROVIDER=0x2d8A3C5677189723C4cB8873CfC9C8976FDF38Ac
A_USDC=0x4C5aE35b3f16fAcaA5a41f4Ba145D9aD887e8a5a
ETH_USD_PRICE_FEED=0x71041DDDAd094AE566B4d4cd0FA6C97e45B01E60
```

### Deployed Contract Details

#### Base Sepolia

```
Contract Address: 0xb896DaacC1987B2A547e101EA8334Cf3aB0AC19a
Constructor Parameters:
  - USDC: 0x036CbD53842c5426634e7929541eC2318f3dCF7e
  - AAVE_POOL: 0x6dcb6D1E0D487EDAE6B45D1d1B86e1A4AD8d4a2C
  - AAVE_DATA_PROVIDER: 0x2d8A3C5677189723C4cB8873CfC9C8976FDF38Ac
  - A_USDC: 0x4C5aE35b3f16fAcaA5a41f4Ba145D9aD887e8a5a
  - ETH_USD_PRICE_FEED: 0x71041DDDAd094AE566B4d4cd0FA6C97e45B01E60
  - Keeper Registry: TBD
  - Keeper Update Interval: 1 hour
  - Health Factor Target: 1.5x
  - Health Factor Threshold: 1.1x
  - Max Slippage: 1%
```

### Deploy to Base Sepolia

1. Deploy the contract:

```bash
# Load environment variables
source .env

# Deploy using Forge Script
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  -vvvv
```

### Mainnet Deployment

For mainnet deployment, update the contract addresses in the deployment script to the mainnet addresses and run:

```bash
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url $MAINNET_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --slow
```

## 🔍 Verification

The contract is already verified on Etherscan:
- [AaveAutopilot on Etherscan](https://sepolia.etherscan.io/address/0xaE2202566bE5325e2A5746b66E13F0D6f7E248b6#code)

To verify the contract manually, use:

```bash
forge verify-contract \
  --chain-id 11155111 \
  --compiler-version v0.8.20+commit.a1b79de6 \
  --constructor-args $(cast abi-encode "constructor(address,string,string,address,address,address,address)" \
    0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238 \
    "Aave Autopilot USDC" \
    "apUSDC" \
    0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951 \
    0x3e9708D80F7b3e431180130bF478987472f950aF \
    0x16dA4541aD1807f4443d92D26044C1147406EB80 \
    0x694AA1769357215DE4FAC081bf1f309aDC325306 \
    0x03a33E8A69f1A5b61178f70BC5c8E674aB571334) \
  --num-of-optimizations 200 \
  AaveAutopilot \
  0xaE2202566bE5325e2A5746b66E13F0D6f7E248b6 \
  --verifier etherscan \
  --etherscan-api-key $ETHERSCAN_API_KEY

2. Deploy the contract:

```bash
forge script script/Deploy.s.sol:DeployScript --rpc-url $RPC_URL --broadcast --verify -vvvv
```

### Deployed Addresses (Base Sepolia)

- **AaveAutopilot**: `0xb896DaacC1987B2A547e101EA8334Cf3aB0AC19a`
- **USDC**: `0x036CbD53842c5426634e7929541eC2318f3dCF7e`
- **Aave Pool**: `0x6dcb6d1e0d487edae6b45d1d1b86e1a4ad8d4a2c`
- **ETH/USD Price Feed**: `0x71041dddad094ae566b4d4cd0fa6c97e45b01e60`

## 🔄 Workflow

### Deposit Flow
1. User approves USDC spending by the vault
2. User deposits USDC into the vault
3. Vault supplies USDC to AAVE v3
4. Vault receives aUSDC tokens in return
5. User receives vault shares representing their deposit

### Withdrawal Flow
1. User requests withdrawal of USDC
2. Vault calculates the share of aUSDC to redeem
3. Vault withdraws USDC from AAVE v3
4. USDC is transferred to the user's wallet
5. User's vault shares are burned

### Rebalancing Flow (Automated)
1. Chainlink Keeper calls `checkUpkeep()` at regular intervals
2. If health factor < threshold, `performUpkeep()` is triggered
3. Vault automatically repays debt or adjusts collateral to maintain target health factor
4. Transaction is submitted by the Keeper network

## 📊 Architecture

```
┌─────────────────┐     ┌─────────────┐     ┌───────────────┐
│                 │     │             │     │               │
│  AAVE Autopilot │◄───►│  AAVE v3    │◄───►│  Chainlink    │
│  Vault (ERC4626)│     │  Protocol   │     │  Price Feeds  │
│                 │     │             │     │               │
└────────┬────────┘     └─────────────┘     └───────────────┘
         │
         │  ┌───────────────────────────────┐
         │  │                               │
         └─►│  Chainlink Keepers Network    │
            │  (Automated Rebalancing)      │
            │                               │
            └───────────────────────────────┘
```

## 🔍 Core Functions

### Deposit & Withdraw
- `deposit(uint256 assets, address receiver)` - Deposit USDC and receive vault shares
- `mint(uint256 shares, address receiver)` - Mint vault shares by depositing USDC
- `withdraw(uint256 assets, address receiver, address owner)` - Withdraw USDC by burning vault shares
- `redeem(uint256 shares, address receiver, address owner)` - Redeem vault shares for USDC

### Keeper Functions
- `checkUpkeep(bytes calldata)` - Checks if the vault needs rebalancing
- `performUpkeep(bytes calldata)` - Executes the rebalancing logic
- `getCurrentHealthFactor()` - Returns the current health factor
- `getCurrentPosition()` - Returns the current position details

### Admin Functions
- `pause()` - Pause all deposits and withdrawals (emergency only)
- `unpause()` - Unpause the contract
- `setKeeper(address)` - Update the keeper address
- `setHealthFactorThresholds(uint256, uint256)` - Update health factor thresholds

## 🔒 Security Considerations

### Audits & Testing
- Comprehensive test coverage (>85%)
- Automated security analysis with Slither and MythX
- Formal verification of critical functions

### Risk Factors
- Smart contract risks
- Oracle risks (price feed manipulation)
- AAVE protocol risks
- Keeper network reliability

### Emergency Procedures
- Pause functionality for critical issues
- Timelock for parameter updates
- Multi-sig admin controls

## 📈 Performance Metrics

### Gas Optimization
- Average deposit: ~150k gas
- Average withdrawal: ~180k gas
- Rebalancing: ~250k-500k gas (varies with position size)

### APY Simulation
Based on current AAVE v3 rates and historical performance:
- Estimated Base APY: 2-4% (USDC supply)
- Additional yield from leverage: 3-6%
- Net APY after fees: 4-8%

## 📅 Development Roadmap

### Short-term (Q4 2023)
- [ ] Complete security audit
- [ ] Deploy to Base mainnet
- [ ] Implement frontend dashboard
- [ ] Add multi-collateral support

### Medium-term (Q1 2024)
- [ ] Cross-chain deployment (Optimism, Arbitrum)
- [ ] Advanced strategies (LP positions, yield optimization)
- [ ] DAO governance

### Long-term (2024+)
- [ ] Permissionless strategy marketplace
- [ ] Advanced risk management
- [ ] Institutional features

## 🛠 Development

### Build

```bash
forge build
```

### Test

```bash
# Run all tests
forge test -vvv

# Run tests with gas reporting
forge test --gas-report

# Run specific test
forge test --match-test testDeposit -vvv
```

### Deploy

```bash
# Deploy to Base Sepolia
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  -vvvv
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgements

- [AAVE](https://aave.com/) team for the amazing lending protocol
- [Chainlink](https://chain.link/) for price feeds and keepers
- [Base](https://base.org/) team for the scaling solution
- [OpenZeppelin](https://openzeppelin.com/) for battle-tested contracts
- All contributors and testers
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
