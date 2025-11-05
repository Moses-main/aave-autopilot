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
    // Base Sepolia addresses
    address constant USDC = 0x036CbD53842c5426634e7929541eC2318f3dCF7e; // Base Sepolia USDC
    address constant AAVE_POOL = 0x6dcb6D1E0D487EDAE6B45D1d1B86e1A4AD8d4a2C; // Base Sepolia Aave Pool
    address constant AAVE_DATA_PROVIDER = 0x2d8A3C5677189723C4cB8873CfC9C8976FDF38Ac; // Base Sepolia Aave Data Provider
    address constant A_USDC = 0x4C5aE35b3f16fAcaA5a41f4Ba145D9aD887e8a5a; // Base Sepolia aUSDC
    address constant ETH_USD_PRICE_FEED = 0x71041DDDAd094AE566B4d4cd0FA6C97e45B01E60; // Base Sepolia ETH/USD Price Feed
    
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
     * @param contractAddress The address of the deployed contract
     */
    function verifyContract(address contractAddress) external {
        string[] memory verifyParams = new string[](2);
        verifyParams[0] = "verify:verify";
        verifyParams[1] = "--network";
        verifyParams[2] = "base-sepolia";
        verifyParams[3] = "--constructor-args";
        verifyParams[4] = "script/arguments.js";
        
        // This would be called with: forge verify-contract --constructor-args script/arguments.js --verifier etherscan --etherscan-api-key $ETHERSCAN_API_KEY $CONTRACT_ADDRESS src/AaveAutopilot.sol:AaveAutopilot
        // Note: You'll need to create script/arguments.js with the constructor arguments
    }
}
