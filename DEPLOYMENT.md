# AAVE Autopilot Vault - Deployment Guide

This guide provides step-by-step instructions for deploying the AAVE Autopilot Vault to Base network.

## Prerequisites

1. **Environment Setup**
   - [Foundry](https://book.getfoundry.org/getting-started/installation) installed
   - [Git](https://git-scm.com/downloads) installed
   - [Node.js](https://nodejs.org/) (v16+ recommended)
   - A wallet with test ETH on Base Sepolia (get some from [Base Faucet](https://www.coinbase.com/faucets/base-sepolly-faucet))
   - [Basescan API Key](https://basescan.org/myapikey) for contract verification

2. **Repository Setup**
   ```bash
   git clone https://github.com/Moses-main/aave-autopilot.gi
   cd aave-autopilot
   forge install
   ```

## Configuration

1. **Environment Variables**
   Create a `.env` file in the project root:
   ```bash
   # Deployment
   PRIVATE_KEY=your_wallet_private_key_here
   RPC_URL=https://sepolia.base.org  # Or your preferred RPC URL
   
   # Verification
   BASESCAN_API_KEY=your_basescan_api_key_here
   
   # Optional: For mainnet deployment
   # RPC_URL=https://mainnet.base.org
   ```

   ⚠️ **Security Note**: Add `.env` to your `.gitignore` to prevent committing sensitive information.

## Deployment Steps

### 1. Test Deployment (Recommended)

```bash
# Run tests to ensure everything works
forge test -vvv

# Simulate deployment (dry run)
forge script script/Deploy.s.sol:DeployScript --rpc-url $RPC_URL -vvv
```

### 2. Deploy to Base Sepolia (Testnet)

```bash
# Deploy the contract
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url $RPC_URL \
  --broadcast \
  --verify \
  --verifier-url https://api-sepolia.basescan.org/api \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  -vvvv
```

### 3. Deploy to Base Mainnet

```bash
# Update RPC_URL in .env to mainnet
# RPC_URL=https://mainnet.base.org

# Deploy with verification
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url $RPC_URL \
  --broadcast \
  --verify \
  --verifier-url https://api.basescan.org/api \
  --etherscan-api-key $BASESCAN_API_KEY \
  -vvvv
```

## Post-Deployment

1. **Verify Deployment**
   - Check the transaction on [Basescan](https://basescan.org/) (or [Base Sepolia Explorer](https://sepolia.basescan.org/) for testnet)
   - Verify the contract was deployed correctly

2. **Set Up Keepers (Optional)**
   - Go to [Chainlink Keepers](https://keepers.chain.link/)
   - Register a new upkeep for your contract
   - Fund the upkeep with LINK tokens

## Common Issues & Solutions

1. **Verification Fails**
   - Ensure your `ETHERSCAN_API_KEY` is correct
   - Check that the contract was deployed successfully before verifying
   - Try adding `--force` to the verification command

2. **Insufficient Funds**
   - Ensure your wallet has enough ETH for gas fees
   - Get test ETH from the [Base Faucet](https://www.coinbase.com/faucets/base-sepolly-faucet) if on testnet

3. **RPC Issues**
   - Try a different RPC URL if you encounter connection issues
   - Consider using a service like [Alchemy](https://www.alchemy.com/) or [Infura](https://infura.io/) for reliable RPC endpoints

## Upgrading

If you need to upgrade the contract in the future:

1. Deploy the new implementation
2. Use the proxy's upgrade function (if using a proxy pattern)
3. Verify the new implementation on Basescan

## Security Considerations

- Never share your private key
- Always deploy to testnet first
- Consider getting an audit before mainnet deployment
- Monitor the contract after deployment

## Support

For issues or questions, please [open an issue](https://github.com/your-username/aave-autopilot/issues) on GitHub.
