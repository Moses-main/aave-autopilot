# AAVE Autopilot Vault - Deployment Guide

This guide provides step-by-step instructions for deploying the AAVE Autopilot Vault to Polygon Amoy testnet.

## Prerequisites

1. **Environment Setup**
   - [Foundry](https://book.getfoundry.org/getting-started/installation) installed
   - [Git](https://git-scm.com/downloads) installed
   - [Node.js](https://nodejs.org/) (v16+ recommended)
   - A wallet with test MATIC on Polygon Amoy (get some from [Polygon Amoy Faucet](https://faucet.polygon.technology/))
   - [Polygonscan API Key](https://polygonscan.com/register) for contract verification

2. **Repository Setup**
   ```bash
   git clone https://github.com/your-username/aave-autopilot.git
   cd aave-autopilot
   forge install
   ```

## Configuration

1. **Environment Variables**
   Create a `.env` file in the project root:
   ```bash
   # Deployment
   PRIVATE_KEY=your_wallet_private_key_here
   RPC_URL=https://rpc-amoy.polygon.technology/  # Polygon Amoy RPC URL
   
   # Verification
   POLYGONSCAN_API_KEY=your_polygonscan_api_key_here
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

### 2. Deploy to Polygon Amoy (Testnet)

```bash
# Deploy the contract
forge script script/DeployAmoy.s.sol:DeployAmoy \
  --rpc-url $RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $POLYGONSCAN_API_KEY \
  -vvvv
```

### 3. Verify on Polygonscan (if needed)

```bash
# Save constructor arguments to a file
echo '{
  "_asset": "0x9c3C9283D3e44854697Cd22D3FAA240Cfb032889",
  "_name": "Wrapped Matic Vault",
  "_symbol": "WMATIC-VAULT",
  "_aavePool": "0x6C9fB0D5bD9429eb9Cd96B85B81d872281771AB6",
  "_aaveDataProvider": "0x2d8A3C5677189723C4cB8873CfC9C8976FDF38Af",
  "_aToken": "0x1E4b7B4B2E4aB5eB8e0aF89840ac02c2458dEbd",
  "_ethUsdPriceFeed": "0xd0D5e3DB44DE05E9F294BB0a3bEEaF030DE24Ada",
  "_linkToken": "0x326C977E6efc84E512bB9C30f76E30c160eD06FB"
}' > constructor-args.json

# Run verification
forge verify-contract \
  --chain-id 80002 \
  --num-of-optimizations 200 \
  --watch \
  --constructor-args $(cat constructor-args.json) \
  --compiler-version v0.8.19 \
  <YOUR_CONTRACT_ADDRESS> \
  src/AaveAutopilot.sol:AaveAutopilot

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
