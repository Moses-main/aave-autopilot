# 🏗️ Aave Autopilot Architecture

## System Overview

## System Architecture

### Overview

![System Architecture](public/Overview.png)
*Figure 1: High-level system architecture*

## Core Flows

### Deposit Flow

![Deposit Flow](public/Deposit%20Flow.png)
*Figure 2: Deposit flow sequence*

### Withdraw Flow

![Withdraw Flow](public/Withdraw%20Flow.png)
*Figure 3: Withdraw flow sequence*

### Rebalancing Flow

![Rebalancing Flow](public/rebalancing_flow.png)
*Figure 4: Rebalancing flow sequence*

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

### 1. Deposit Flow
```mermaid
sequenceDiagram
    participant U as User
    participant V as AaveAutopilot
    participant A as Aave V3
    
    U->>V: deposit(assets, receiver)
    V->>A: supply(asset, amount, onBehalfOf, referralCode)
    A-->>V: aToken minted
    V-->>U: shares minted
    Note over V: Update user balance and total supply
```

### 2. Withdrawal Flow
```mermaid
sequenceDiagram
    participant U as User
    participant V as AaveAutopilot
    participant A as Aave V3
    
    U->>V: redeem(shares, receiver, owner)
    V->>A: withdraw(asset, amount, to)
    A-->>V: aToken burned
    V-->>U: assets transferred
    Note over V: Update user balance and total supply
```

### 3. Rebalancing Flow
```mermaid
sequenceDiagram
    participant K as Chainlink Keeper
    participant V as AaveAutopilot
    participant A as Aave V3
    participant O as Price Feed
    
    K->>V: checkUpkeep()
    V->>O: latestRoundData()
    O-->>V: price
    V->>V: calculateHealthFactor()
    alt Health Factor < Threshold
        K->>V: performUpkeep()
        V->>A: withdraw() or supply()
        V->>V: updatePosition()
    end
```

## Security Considerations

- All external calls use OpenZeppelin's SafeERC20 for safe token transfers
- Reentrancy guards on all state-changing functions
- Access control for sensitive operations
- Comprehensive test coverage for all critical paths
