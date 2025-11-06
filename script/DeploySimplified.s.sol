// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {AaveAutopilot} from "../src/AaveAutopilot.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Simplified AaveAutopilot Deployment Script
 * @notice Script to deploy AaveAutopilot to a forked Mainnet environment
 */
contract DeploySimplified is Script {
    function run() external {
        // Load environment variables
        string memory rpcUrl = vm.envString("RPC_URL");
        string memory privateKey = vm.envString("PRIVATE_KEY");
        
        // Parse private key
        uint256 deployerPrivateKey = vm.parseUint(privateKey);
        address deployer = vm.addr(deployerPrivateKey);
        
        console2.log("Deploying AaveAutopilot...");
        console2.log("Deployer:", deployer);
        console2.log("RPC URL:", rpcUrl);
        
        // Define addresses as strings first to avoid checksum issues
        string memory usdcStr = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
        string memory aavePoolStr = "0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2";
        string memory aaveDataProviderStr = "0x7B4EB56E7CD4b454BA8fF71E4518426369a138a3";
        string memory aUsdcStr = "0x98C23E9d8f34FEfb1B7Bd6a91B7bB122F4E16f5c";
        string memory ethUsdPriceFeedStr = "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419";
        string memory linkTokenStr = "0x514910771AF9Ca656af840dff83E8264EcF986CA";
        string memory keeperRegistryStr = "0xE16Df59B403e9B01F5f28a3b09a4e71c9F3509dF";
        
        // Parse addresses
        address usdc = vm.parseAddress(usdcStr);
        address aavePool = vm.parseAddress(aavePoolStr);
        address aaveDataProvider = vm.parseAddress(aaveDataProviderStr);
        address aUsdc = vm.parseAddress(aUsdcStr);
        address ethUsdPriceFeed = vm.parseAddress(ethUsdPriceFeedStr);
        address linkToken = vm.parseAddress(linkTokenStr);
        address keeperRegistry = vm.parseAddress(keeperRegistryStr);
        
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy AaveAutopilot with parsed addresses
        AaveAutopilot aaveAutopilot = new AaveAutopilot(
            IERC20(usdc), // USDC
            "Aave Autopilot USDC",
            "apUSDC",
            aavePool, // AAVE_POOL
            aaveDataProvider, // AAVE_DATA_PROVIDER
            aUsdc, // A_USDC
            ethUsdPriceFeed, // ETH_USD_PRICE_FEED
            linkToken, // LINK_TOKEN
            deployer // Owner
        );
        
        // Grant keeper role to the Keeper Registry
        aaveAutopilot.grantRole(
            aaveAutopilot.KEEPER_ROLE(), 
            keeperRegistry // KEEPER_REGISTRY
        );
        
        console2.log("\n=== Deployment Successful ===");
        console2.log("AaveAutopilot deployed to:", address(aaveAutopilot));
        
        vm.stopBroadcast();
    }
}
