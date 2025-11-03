# AAVE Autopilot Vault

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Built with Foundry](https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg)](https://getfoundry.sh/)

An ERC-4626 compliant vault that automates AAVE v3 positions with health factor monitoring and automatic rebalancing on Base network.

## 📖 Overview

The AAVE Autopilot Vault provides a simple interface for users to deposit USDC, which is then automatically supplied to AAVE v3 to earn yield. The vault manages the health factor of the position and automatically rebalances when necessary to prevent liquidations.

### Key Features

- **Automated Health Factor Management**: Monitors and maintains a healthy position on AAVE v3
- **Chainlink Price Feeds**: Uses real-time price data for accurate collateral valuation
- **Chainlink Keepers**: Automated rebalancing when health factor falls below threshold
- **Gas Optimized**: Optimized for Base network's gas efficiency
- **Secure**: Implements reentrancy protection and pausable functionality

## 🚀 Quick Start

### Prerequisites

- [Foundry](https://getfoundry.sh/)
- [Node.js](https://nodejs.org/) (for deployment scripts)
- [Git](https://git-scm.com/)

### Installation

```bash
# Clone the repository
git clone https://github.com/your-username/aave-autopilot.git
cd aave-autopilot

# Install dependencies
forge install
```

## 🏗️ Deployment

### Deploy to Base Sepolia

1. Set up your environment variables:

```bash
# In your .env file
PRIVATE_KEY=your_private_key_here
RPC_URL=https://sepolia.base.org
ETHERSCAN_API_KEY=your_etherscan_api_key
```

2. Deploy the contract:

```bash
forge script script/Deploy.s.sol:DeployScript --rpc-url $RPC_URL --broadcast --verify -vvvv
```

### Deployed Addresses (Base Sepolia)

- **AaveAutopilot**: `[Deploy to get address]`
- **USDC**: `0x036CbD53842c5426634e7929541eC2318f3dCF7e`
- **Aave Pool**: `0x6dcb6d1e0d487edae6b45d1d1b86e1a4ad8d4a2c`
- **ETH/USD Price Feed**: `0x71041dddad094ae566b4d4cd0fa6c97e45b01e60`

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

## 📝 Usage

### Deposit

```solidity
// Approve USDC to be spent by the vault
IERC20(USDC).approve(vaultAddress, amount);

// Deposit USDC into the vault
vault.deposit(amount, receiver);
```

### Withdraw

```solidity
// Withdraw USDC from the vault
vault.withdraw(amount, receiver, owner);
```

### Check Health Factor

```solidity
// Get current health factor (scaled by 1e18)
uint256 healthFactor = vault.getCurrentHealthFactor();
```

### Manual Rebalance

```solidity
// Manually trigger rebalance if needed
vault.checkAndAdjustPosition();
```

## 🔒 Security

### Audits

This code has not been audited. Use at your own risk.

### Security Features

- Reentrancy protection
- Pausable functionality
- Input validation
- Access control
- Health factor monitoring

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgements

- [AAVE](https://aave.com/)
- [Chainlink](https://chain.link/)
- [OpenZeppelin](https://openzeppelin.com/)
- [Base Network](https://base.org/)

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
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
