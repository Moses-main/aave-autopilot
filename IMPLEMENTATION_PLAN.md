# Aave Autopilot - Implementation Plan (Mainnet)

## Phase 1: Core Contract Implementation ✅
- [x] Set up project structure with Foundry
- [x] Implement AaveAutopilot.sol with ERC4626, Ownable, and ReentrancyGuard
- [x] Add Aave V3 integration
- [x] Implement health factor monitoring
- [x] Add Chainlink Keeper integration
- [x] Implement rebalancing logic
- [x] Add LINK token support for Chainlink Automation
- [x] Update contract with gas optimizations and safety checks

## Phase 2: Testing Environment Setup (Mainnet Fork) ✅
- [x] Set up test files
- [x] Configure forked testing environment with Mainnet using Tenderly
- [x] Write unit tests for core functionality
- [x] Write integration tests with forked mainnet
- [x] Test edge cases and failure modes
- [x] Remove Sepolia test configurations
- [x] Fix checksum issues in test files
- [x] Update test environment to use USDC whale for testing

## Phase 3: Deployment & Verification (Mainnet)
- [x] Create deployment scripts
- [ ] Update deployment scripts with LINK token support
- [ ] Deploy to Ethereum Mainnet
- [ ] Verify contracts on Etherscan
- [ ] Set up Chainlink Keepers
- [ ] Test end-to-end on Mainnet

## Phase 4: Documentation & Finalization
- [x] Update README with Mainnet deployment instructions
- [ ] Add NatSpec comments
- [ ] Create deployment checklists
- [ ] Document known limitations

## Current Focus: Mainnet Deployment
We are preparing for deployment to Ethereum Mainnet using Tenderly for forked testing and verification. The contract has been updated with LINK token support and gas optimizations.

## Next Steps
1. Update deployment scripts to include LINK token address
2. Test deployment on Tenderly fork
3. Deploy contracts to Ethereum Mainnet
4. Verify contracts on Etherscan
5. Set up Chainlink Keepers with proper LINK token funding
6. Perform end-to-end testing on Mainnet fork

## Important Notes
- The deployment scripts need to be updated to include the LINK token address in the constructor
- All tests should be run against the Tenderly fork before mainnet deployment
- Ensure sufficient LINK token balance for Chainlink Keepers registration

## Testing Commands
```bash
# Run all tests with Mainnet forking
forge test -vvv --fork-url $RPC_URL

# Run specific test file with forking
forge test --match-path test/AaveAutopilotMainnetFork.t.sol -vvv --fork-url $RPC_URL

# Run with specific block number for consistency
forge test -vvv --fork-url $RPC_URL --fork-block-number 20000000
```

## Environment Variables
Update your `.env` file with Mainnet configuration:
```bash
# Tenderly RPC URL for Mainnet forking
RPC_URL=https://virtual.mainnet.eu.rpc.tenderly.co/82c86106-662e-4d7f-a974-c311987358ff

# Mainnet Addresses
USDC=0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
AAVE_POOL=0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2
AAVE_DATA_PROVIDER=0x7B4EB56E7CD4b454BA8fF71E4518426369a138a3
A_USDC=0x98C23E9d8f34FEFb1B7BD6a91B7BB122F4e16F5c
ETH_USD_PRICE_FEED=0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
KEEPER_REGISTRY=0xE16Df59B403e9B01F5f28a3b09a4e71c9F3509dF
LINK_TOKEN=0x514910771AF9Ca656af840dff83E8264EcF986CA

# Deployment
PRIVATE_KEY=your_private_key_here
ETHERSCAN_API_KEY=your_etherscan_api_key_here

# Testing Accounts (for forked testing)
USDC_WHALE=0x47ac0Fb4F2D84898e4D9E7b4DaB3C24507a6D503  # USDC whale for testing
```

## Last Updated
2025-11-06 - Updated for Mainnet deployment with Tenderly RPC
