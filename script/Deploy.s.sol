// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import "../src/AaveAutopilot.sol";

/**
 * @title AaveAutopilot Deploy Script
 * @notice Script to deploy AaveAutopilot contract to Base Sepolia
 * @dev Make sure to set the PRIVATE_KEY environment variable before running
 */
contract DeployScript is Script {
    // Ethereum Sepolia addresses
    address constant USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238; // Sepolia USDC
    address constant AAVE_POOL = 0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951; // Sepolia Aave Pool
    address constant AAVE_DATA_PROVIDER = 0x3e9708D80F7b3e431180130bF478987472f950aF; // Sepolia Aave Data Provider (checksummed)
    address constant A_USDC = 0x16dA4541aD1807f4443d92D26044C1147406EB80; // Sepolia aUSDC
    address constant ETH_USD_PRICE_FEED = 0x694AA1769357215DE4FAC081bf1f309aDC325306; // Sepolia ETH/USD Price Feed
    
    // Events for better logging
    event ContractDeployed(address indexed contractAddress, string contractName);
    event ConfigurationSet(address indexed contractAddress, string config, address value);
    
    function run() external {
        // Get deployer private key from env
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        if (deployerPrivateKey == 0) {
            revert("PRIVATE_KEY environment variable not set");
        }
        
        console.log("Starting deployment of AaveAutopilot...");
        
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy the vault
        AaveAutopilot vault = new AaveAutopilot(
            IERC20(USDC), // USDC token
            "Aave Autopilot USDC", // Vault name
            "apUSDC", // Vault symbol
            AAVE_POOL, // Aave Pool
            AAVE_DATA_PROVIDER, // Aave Data Provider
            A_USDC, // aUSDC token
            ETH_USD_PRICE_FEED, // ETH/USD price feed
            msg.sender // Owner
        );
        
        // Log deployment details
        console.log("\n=== Deployment Summary ===");
        console.log("Network:", block.chainid);
        console.log("Deployer:", vm.addr(deployerPrivateKey));
        console.log("AaveAutopilot deployed to:", address(vault));
        
        // Verify critical configurations
        console.log("\n=== Configuration ===");
        console.log("USDC Token:", USDC);
        console.log("Aave Pool:", AAVE_POOL);
        console.log("Aave Data Provider:", AAVE_DATA_PROVIDER);
        console.log("aUSDC Token:", A_USDC);
        console.log("ETH/USD Price Feed:", ETH_USD_PRICE_FEED);
        
        emit ContractDeployed(address(vault), "AaveAutopilot");
        
        // Stop broadcasting
        vm.stopBroadcast();
        
        console.log("\nDeployment completed successfully!");
    }
    
    /**
     * @notice Verify contract deployment on Etherscan
     */
    function verifyContract() external pure {
        string[] memory verifyParams = new string[](5);
        verifyParams[0] = "verify:verify";
        verifyParams[1] = "--network";
        verifyParams[2] = "base-sepolia";
        verifyParams[3] = "--constructor-args";
        verifyParams[4] = "script/arguments.js";
        
        // This would be called with: forge verify-contract --constructor-args script/arguments.js --verifier etherscan --etherscan-api-key $ETHERSCAN_API_KEY $CONTRACT_ADDRESS src/AaveAutopilot.sol:AaveAutopilot
        // Note: You'll need to create script/arguments.js with the constructor arguments
    }
}
