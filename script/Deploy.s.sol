// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import "../src/AaveAutopilot.sol";

/**
 * @title AaveAutopilot Deploy Script
 * @notice Script to deploy AaveAutopilot contract to Ethereum Mainnet
 * @dev Make sure to set the PRIVATE_KEY environment variable before running
 */
contract DeployScript is Script {
    // Ethereum Mainnet addresses as strings to avoid checksum issues
    string constant USDC_STR = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"; // Mainnet USDC
    string constant AAVE_POOL_STR = "0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2"; // Mainnet Aave Pool
    string constant AAVE_DATA_PROVIDER_STR = "0x7B4EB56E7CD4b454BA8fF71E4518426369a138a3"; // Mainnet Aave Data Provider
    string constant A_USDC_STR = "0x98C23E9d8f34FEfb1B7Bd6a91B7bB122F4E16f5c"; // Mainnet aUSDC
    string constant ETH_USD_PRICE_FEED_STR = "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419"; // Mainnet ETH/USD Price Feed
    string constant LINK_TOKEN_STR = "0x514910771AF9Ca656af840dff83E8264EcF986CA"; // Mainnet LINK Token
    string constant KEEPER_REGISTRY_STR = "0xE16Df59B403e9B01F5f28a3b09a4e71c9F3509dF"; // Mainnet Chainlink Keeper Registry
    
    // Address variables
    address USDC;
    address AAVE_POOL;
    address AAVE_DATA_PROVIDER;
    address A_USDC;
    address ETH_USD_PRICE_FEED;
    address LINK_TOKEN;
    address KEEPER_REGISTRY;
    
    // Events for better logging
    event ContractDeployed(address indexed contractAddress, string contractName);
    event ConfigurationSet(address indexed contractAddress, string config, address value);
    
    function run() external {
        // Parse all addresses from strings
        USDC = vm.parseAddress(USDC_STR);
        AAVE_POOL = vm.parseAddress(AAVE_POOL_STR);
        AAVE_DATA_PROVIDER = vm.parseAddress(AAVE_DATA_PROVIDER_STR);
        A_USDC = vm.parseAddress(A_USDC_STR);
        ETH_USD_PRICE_FEED = vm.parseAddress(ETH_USD_PRICE_FEED_STR);
        LINK_TOKEN = vm.parseAddress(LINK_TOKEN_STR);
        KEEPER_REGISTRY = vm.parseAddress(KEEPER_REGISTRY_STR);
        
        // Get deployer private key from env
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        if (deployerPrivateKey == 0) {
            revert("PRIVATE_KEY environment variable not set");
        }
        
        // Get deployer address
        address deployer = vm.addr(deployerPrivateKey);
        
        // Log deployment configuration
        console.log("\n=== Deployment Configuration ===");
        console.log("Deployer:", deployer);
        console.log("USDC:", USDC);
        console.log("Aave Pool:", AAVE_POOL);
        console.log("Aave Data Provider:", AAVE_DATA_PROVIDER);
        console.log("aUSDC:", A_USDC);
        console.log("ETH/USD Price Feed:", ETH_USD_PRICE_FEED);
        console.log("LINK Token:", LINK_TOKEN);
        console.log("Keeper Registry:", KEEPER_REGISTRY);
        
        console.log("\nStarting deployment of AaveAutopilot...");
        
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy the AaveAutopilot contract
        AaveAutopilot aaveAutopilot = new AaveAutopilot(
            IERC20(USDC), // USDC token
            "Aave Autopilot USDC", // Vault name
            "apUSDC", // Vault symbol
            AAVE_POOL, // Aave Pool
            AAVE_DATA_PROVIDER, // Aave Data Provider
            A_USDC, // aUSDC token
            ETH_USD_PRICE_FEED, // ETH/USD price feed
            LINK_TOKEN, // LINK token for Chainlink Keepers
            deployer // Owner
        );
        
        // Grant keeper role to the Keeper Registry
        aaveAutopilot.grantRole(
            aaveAutopilot.KEEPER_ROLE(),
            KEEPER_REGISTRY
        );
        
        // Transfer ownership if needed
        if (aaveAutopilot.owner() != deployer) {
            aaveAutopilot.transferOwnership(deployer);
        }
        
        vm.stopBroadcast();
        
        // Log deployment summary
        console.log("\n=== Deployment Successful ===");
        console.log("AaveAutopilot deployed to:", address(aaveAutopilot));
        console.log("Owner:", aaveAutopilot.owner());
        console.log("Chain ID:", block.chainid);
        
        // Log next steps
        console.log("\n=== Next Steps ===");
        console.log("1. Fund the contract with LINK tokens for Chainlink Automation");
        console.log("2. Register the contract with Chainlink Keepers");
        console.log("3. Test the contract on a forked mainnet");
        
        // Emit events for better integration with other tools
        emit ContractDeployed(address(aaveAutopilot), "AaveAutopilot");
        emit ConfigurationSet(address(aaveAutopilot), "KEEPER_REGISTRY", KEEPER_REGISTRY);
        emit ConfigurationSet(address(aaveAutopilot), "LINK_TOKEN", LINK_TOKEN);
        
        console.log("\nDeployment completed successfully!");
    }
    
    /**
     * @notice Verify contract deployment on Etherscan
     * @dev To use this function, run:
     * forge verify-contract --constructor-args $(cast abi-encode "constructor(address,string,string,address,address,address,address,address,address)" \
     *   0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48 \
     *   "Aave Autopilot USDC" \
     *   "apUSDC" \
     *   0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2 \
     *   0x7B4EB56E7CD4b454BA8fF71E4518426369a138a3 \
     *   0x98C23E9d8f34FEFb1B7BD6a91B7BB122F4e16F5c \
     *   0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419 \
     *   0x514910771AF9Ca656af840dff83E8264EcF986CA \
     *   $YOUR_DEPLOYER_ADDRESS) \
     *   --verifier etherscan \
     *   --etherscan-api-key $ETHERSCAN_API_KEY \
     *   $CONTRACT_ADDRESS \
     *   src/AaveAutopilot.sol:AaveAutopilot
     */
    function verifyContract() external pure {}
    
    /**
     * @notice Helper function to get the encoded constructor arguments
     * @dev This can be used to generate the constructor arguments for verification
     */
    function getConstructorArgs() external view returns (bytes memory) {
        return abi.encode(
            USDC,
            "Aave Autopilot USDC",
            "apUSDC",
            AAVE_POOL,
            AAVE_DATA_PROVIDER,
            A_USDC,
            ETH_USD_PRICE_FEED,
            LINK_TOKEN,
            msg.sender
        );
    }
}
