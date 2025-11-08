# 🏗️ Aave Autopilot Architecture

## System Overview

```
┌─────────────┐    ┌───────────────────┐    ┌─────────────┐
│             │    │                   │    │             │
│   User      │───▶│  AaveAutopilot    │◀──▶│  Aave V3    │
│             │    │  (ERC-4626 Vault) │    │  Protocol   │
└─────────────┘    └────────┬──────────┘    └─────────────┘
                           │
                           ▼
                   ┌───────────────────┐    ┌─────────────┐
                   │                   │    │             │
                   │  Chainlink        │◀──▶│  Price      │
                   │  Keepers          │    │  Feeds      │
                   └───────────────────┘    └─────────────┘
```

## Key Components

### 1. AaveAutopilot (ERC-4626 Vault)
- Manages user deposits/withdrawals
- Tracks user shares and assets
- Implements rebalancing logic
- Handles interest accrual through Aave V3

### 2. Chainlink Keepers
- Monitors health factor in real-time
- Triggers rebalancing when thresholds are breached
- Handles automation execution in a decentralized manner

### 3. Aave V3 Integration
- Interacts with Aave Pool for lending/borrowing
- Manages aToken balances
- Handles interest rate calculations

### 4. Price Oracle
- Uses Chainlink Price Feeds for accurate asset pricing
- Provides real-time price data for collateral valuation
- Ensures accurate health factor calculations

## Data Flow

1. **Deposit Flow**
   - User deposits USDC into the vault
   - Vault supplies USDC to Aave V3
   - User receives vault shares
   - Position health is monitored

2. **Withdrawal Flow**
   - User redeems vault shares
   - Vault withdraws USDC from Aave V3 if needed
   - User receives USDC

3. **Rebalancing Flow**
   - Chainlink Keeper detects health factor below threshold
   - Keeper triggers rebalance function
   - Vault adjusts position to maintain target health factor

## Security Considerations

- All external calls use OpenZeppelin's SafeERC20 for safe token transfers
- Reentrancy guards on all state-changing functions
- Access control for sensitive operations
- Comprehensive test coverage for all critical paths
