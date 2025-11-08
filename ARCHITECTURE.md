# 🏗️ Aave Autopilot Architecture

## System Overview

```mermaid
graph TB
    %% User Layer
    User[User] -->|1. Deposit/Withdraw| Vault[AaveAutopilot<br><small>ERC-4626 Vault</small>]
    
    %% Core Components
    subgraph AaveAutopilot[Aave Autopilot System]
        Vault -->|2. Manage Assets| AaveV3[Aave V3 Protocol]
        Vault -->|3. Monitor Position| HealthCheck[Health Monitor]
        Vault -->|4. Track Prices| Oracle[Price Oracle]
        HealthCheck -->|5. Trigger| Rebalancer[Rebalancer]
        Rebalancer -->|6. Adjust Position| Vault
    end

    %% External Services
    subgraph External[External Services]
        Chainlink[Chainlink Keepers]
        AaveV3
        PriceFeed[Chainlink Price Feeds]
    end

    %% Data Flows
    Vault <-->|7. Supply/Redeem| AaveV3
    Vault <-->|8. Get Prices| PriceFeed
    Chainlink -->|9. Check Health| HealthCheck
    Chainlink -->|10. Trigger Rebalance| Rebalancer

    %% Styling
    classDef userNode fill:#e1f5fe,stroke:#0288d1,color:#000,stroke-width:2px;
    classDef vaultNode fill:#e8f5e9,stroke:#388e3c,color:#000,stroke-width:2px;
    classDef externalNode fill:#f3e5f5,stroke:#8e24aa,color:#000,stroke-width:2px;
    classDef component fill:#fff,stroke:#555,stroke-width:1.5px,stroke-dasharray: 3 3;
    
    class User userNode;
    class Vault vaultNode;
    class AaveV3,Chainlink,PriceFeed externalNode;
    class AaveAutopilot,External component;
```

*Figure 1: High-level system architecture and data flow*

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
