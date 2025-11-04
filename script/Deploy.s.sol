// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import "../src/AaveAutopilot.sol";

contract DeployScript is Script {
    // Base Sepolia addresses
    address constant USDC = 0x036CbD53842c5426634e7929541eC2318f3dCF7e; // Base Sepolia USDC
    address constant AAVE_POOL = 0x6dcb6D1E0D487EDAE6B45D1d1B86e1A4AD8d4a2C; // Base Sepolia Aave Pool
    address constant AAVE_DATA_PROVIDER = 0x2d8A3C5677189723C4cB8873CfC9C8976FDF38Ac; // Base Sepolia Aave Data Provider
    address constant A_USDC = 0x4C5aE35b3f16fAcaA5a41f4Ba145D9aD887e8a5a; // Base Sepolia aUSDC
    address constant ETH_USD_PRICE_FEED = 0x71041DDDAd094AE566B4d4cd0FA6C97e45B01E60; // Base Sepolia ETH/USD Price Feed
    
    function run() external {
        // Get deployer private key from env
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy the vault
        AaveAutopilot vault = new AaveAutopilot(
            IERC20(USDC), // USDC token
            "Aave Autopilot USDC", // Vault name
            "apUSDC", // Vault symbol
            AAVE_POOL, // Aave Pool
            AAVE_DATA_PROVIDER, // Aave Data Provider
            A_USDC, // aUSDC token
            ETH_USD_PRICE_FEED // ETH/USD price feed
        );
        
        console.log("AaveAutopilot deployed at:", address(vault));
        
        vm.stopBroadcast();
    }
}
