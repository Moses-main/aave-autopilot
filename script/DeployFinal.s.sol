// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {AaveAutopilot} from "../src/AaveAutopilot.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Final AaveAutopilot Deployment Script
 * @notice Script to deploy AaveAutopilot to a forked Mainnet environment
 */
contract DeployFinal is Script {
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
        
        // Define addresses as strings and parse them
        address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        address AAVE_POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
        address AAVE_DATA_PROVIDER = 0x7B4EB56E7CD4b454BA8ff71E4518426369a138a3;
        
        // Problematic addresses - we'll use string parsing
        string memory aUsdcStr = "0x98C23E9d8f34FEfb1B7Bd6a91B7bB122F4E16f5c";
        string memory keeperRegistryStr = "0xE16Df59B403e9B01F5f28a3b09a4e71c9F3509dF";
        
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy AaveAutopilot with direct addresses
        AaveAutopilot aaveAutopilot = new AaveAutopilot(
            IERC20(USDC),
            "Aave Autopilot USDC",
            "apUSDC",
            AAVE_POOL,
            AAVE_DATA_PROVIDER,
            parseAddress(aUsdcStr),
            0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419, // ETH_USD_PRICE_FEED
            0x514910771AF9Ca656af840dff83E8264EcF986CA, // LINK_TOKEN
            deployer // Owner
        );
        
        // Grant keeper role to the Keeper Registry
        aaveAutopilot.grantRole(
            aaveAutopilot.KEEPER_ROLE(), 
            parseAddress(keeperRegistryStr)
        );
        
        console2.log("\n=== Deployment Successful ===");
        console2.log("AaveAutopilot deployed to:", address(aaveAutopilot));
        
        vm.stopBroadcast();
    }
    
    // Helper function to parse address from string
    function parseAddress(string memory _a) internal pure returns (address _parsedAddress) {
        bytes memory tmp = bytes(_a);
        uint160 iaddr = 0;
        uint160 b1;
        uint160 b2;
        for (uint i = 2; i < 2 + 2 * 20; i += 2) {
            iaddr *= 256;
            b1 = uint160(uint8(tmp[i]));
            b2 = uint160(uint8(tmp[i + 1]));
            if ((b1 >= 97) && (b1 <= 102)) {
                b1 -= 87;
            } else if ((b1 >= 65) && (b1 <= 70)) {
                b1 -= 55;
            } else if ((b1 >= 48) && (b1 <= 57)) {
                b1 -= 48;
            }
            if ((b2 >= 97) && (b2 <= 102)) {
                b2 -= 87;
            } else if ((b2 >= 65) && (b2 <= 70)) {
                b2 -= 55;
            } else if ((b2 >= 48) && (b2 <= 57)) {
                b2 -= 48;
            }
            iaddr += (b1 * 16 + b2);
        }
        return address(iaddr);
    }
}
