// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {AaveAutopilot} from "../src/AaveAutopilot.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Simple AaveAutopilot Deployment Script
 * @notice This script deploys the AaveAutopilot contract with pre-defined addresses
 * @dev Uses string constants and vm.parseAddress() to avoid checksum issues
 */
contract DeploySimple is Script {
    // Address constants as strings to avoid checksum issues
    string constant USDC_STR = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
    string constant AAVE_POOL_STR = "0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2";
    string constant AAVE_DATA_PROVIDER_STR = "0x7B4EB56E7CD4b454BA8fF71E4518426369a138a3";
    string constant A_USDC_STR = "0x98C23E9d8f34FEfb1B7Bd6a91B7bB122F4E16f5c";
    string constant ETH_USD_PRICE_FEED_STR = "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419";
    string constant LINK_TOKEN_STR = "0x514910771AF9Ca656af840dff83E8264EcF986CA";
    string constant KEEPER_REGISTRY_STR = "0xE16Df59B403e9B01F5f28a3b09a4e71c9F3509dF";

    function run() external {
        // Load deployer private key
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // Parse all addresses from strings
        address usdc = vm.parseAddress(USDC_STR);
        address aavePool = vm.parseAddress(AAVE_POOL_STR);
        address aaveDataProvider = vm.parseAddress(AAVE_DATA_PROVIDER_STR);
        address aUsdc = vm.parseAddress(A_USDC_STR);
        address ethUsdPriceFeed = vm.parseAddress(ETH_USD_PRICE_FEED_STR);
        address linkToken = vm.parseAddress(LINK_TOKEN_STR);
        address keeperRegistry = vm.parseAddress(KEEPER_REGISTRY_STR);
        
        // Log deployment configuration
        console2.log("\n=== Deployment Configuration ===");
        console2.log("Deployer:", deployer);
        console2.log("USDC:", usdc);
        console2.log("Aave Pool:", aavePool);
        console2.log("Aave Data Provider:", aaveDataProvider);
        console2.log("aUSDC:", aUsdc);
        console2.log("ETH/USD Price Feed:", ethUsdPriceFeed);
        console2.log("LINK Token:", linkToken);
        console2.log("Keeper Registry:", keeperRegistry);
        
        console2.log("\nStarting deployment of AaveAutopilot...");
        
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy the AaveAutopilot contract
        AaveAutopilot aaveAutopilot = new AaveAutopilot(
            IERC20(usdc),             // USDC
            "Aave Autopilot USDC",    // Name
            "apUSDC",                 // Symbol
            aavePool,                 // Aave Pool
            aaveDataProvider,         // Aave Data Provider
            aUsdc,                    // aUSDC
            ethUsdPriceFeed,          // ETH/USD Price Feed
            linkToken,                // LINK Token
            deployer                  // Owner
        );
        
        // Grant keeper role to the Keeper Registry
        aaveAutopilot.grantRole(
            aaveAutopilot.KEEPER_ROLE(),
            keeperRegistry
        );
        
        console2.log("\n=== Deployment Successful ===");
        console2.log("AaveAutopilot deployed to:", address(aaveAutopilot));
        console2.log("Owner:", aaveAutopilot.owner());
        console2.log("Keeper Role granted to:", keeperRegistry);
        
        vm.stopBroadcast();
    }
}
