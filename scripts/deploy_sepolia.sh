#!/bin/bash

# Load environment variables from .env file
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Check if PRIVATE_KEY is set
if [ -z "$PRIVATE_KEY" ]; then
    echo "Error: PRIVATE_KEY environment variable not set"
    exit 1
fi

# Check if ETHERSCAN_API_KEY is set
if [ -z "$ETHERSCAN_API_KEY" ]; then
    echo "Warning: ETHERSCAN_API_KEY environment variable not set, verification will be skipped"
fi

# Deploy the contract
echo "Deploying AaveAutopilot to Sepolia..."
forge script script/DeploySepolia.s.sol:DeploySepolia \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --verify \
    -vvvv

# Extract the deployed contract address from the broadcast file
CONTRACT_ADDRESS=$(jq -r '.returns["0:"].value' broadcast/DeploySepolia.s.sol/11155111/run-latest.json | tail -n 1)

if [ -z "$CONTRACT_ADDRESS" ] || [ "$CONTRACT_ADDRESS" = "null" ]; then
    echo "Error: Failed to extract contract address from deployment"
    exit 1
fi

echo "\n=== Deployment Complete ==="
echo "AaveAutopilot deployed to: $CONTRACT_ADDRESS"

# Save the contract address to .env
echo "CONTRACT_ADDRESS=$CONTRACT_ADDRESS" >> .env

# Verify the contract if ETHERSCAN_API_KEY is set
if [ -n "$ETHERSCAN_API_KEY" ]; then
    echo "\nVerifying contract on Etherscan..."
    
    # Generate constructor arguments
    cast abi-encode "constructor(address,string,string,address,address,address,address,address)" \
        0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238 \
        "Aave Autopilot USDC" \
        "apUSDC" \
        0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951 \
        0x3e9708D80F7b3e431180130bF478987472f950aF \
        0x16dA4541aD1807f4443d92D26044C1147406EB80 \
        0x694AA1769357215DE4FAC081bf1f309aDC325306 \
        $(cast wallet address --private-key $PRIVATE_KEY) > constructor-args.txt
    
    # Verify the contract
    forge verify-contract \
        --chain-id 11155111 \
        --constructor-args-path constructor-args.txt \
        --compiler-version v0.8.20+commit.a1b79de6 \
        --optimizer-runs 200 \
        --watch \
        $CONTRACT_ADDRESS \
        src/AaveAutopilot.sol:AaveAutopilot \
        --etherscan-api-key $ETHERSCAN_API_KEY
    
    # Clean up
    rm -f constructor-args.txt
    
    echo "\nVerification submitted to Etherscan"
else
    echo "\nSkipping verification (ETHERSCAN_API_KEY not set)"
fi

echo "\nDeployment and verification complete!"
