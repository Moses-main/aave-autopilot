// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {AaveAutopilot} from "../src/AaveAutopilot.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {IPoolDataProvider} from "@aave/core-v3/contracts/interfaces/IPoolDataProvider.sol";
import {IAToken} from "@aave/core-v3/contracts/interfaces/IAToken.sol";

/**
 * @title AaveAutopilot Forked Deployment Script
 * @notice Script to deploy AaveAutopilot to a forked Mainnet environment
 * @dev Uses Tenderly RPC for forking Mainnet
 */
contract DeployForked is Script {
    // Ethereum Mainnet addresses (using string parsing to avoid checksum issues)
    function getUsdc() internal view returns (address) {
        return vm.parseAddress(USDC_STR);
    }
    
    // Define all addresses as strings first to avoid checksum issues
    string constant USDC_STR = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
    string constant AAVE_POOL_STR = "0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2";
    string constant AAVE_DATA_PROVIDER_STR = "0x7B4EB56E7CD4b454BA8fF71E4518426369a138a3";
    string constant A_USDC_STR = "0x98C23E9d8f34FEfb1B7Bd6a91B7bB122F4E16f5c";
    string constant ETH_USD_PRICE_FEED_STR = "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419";
    string constant LINK_TOKEN_STR = "0x514910771AF9Ca656af840dff83E8264EcF986CA";
    string constant KEEPER_REGISTRY_STR = "0xE16Df59B403e9B01F5f28a3b09a4e71c9F3509dF";
    
    function getAavePool() internal view returns (address) {
        return vm.parseAddress(AAVE_POOL_STR);
    }
    
    function getAaveDataProvider() internal view returns (address) {
        return vm.parseAddress(AAVE_DATA_PROVIDER_STR);
    }
    
    function getAUsdc() internal view returns (address) {
        return vm.parseAddress(A_USDC_STR);
    }
    
    function getEthUsdPriceFeed() internal view returns (address) {
        return vm.parseAddress(ETH_USD_PRICE_FEED_STR);
    }
    
    function getKeeperRegistry() internal view returns (address) {
        return vm.parseAddress(KEEPER_REGISTRY_STR);
    }
    
    function getLinkToken() internal view returns (address) {
        return vm.parseAddress(LINK_TOKEN_STR);
    }
    
    function run() external {
        // Load environment variables
        string memory rpcUrl = vm.envString("RPC_URL");
        string memory privateKey = vm.envString("PRIVATE_KEY");
        
        // Start broadcasting transactions
        uint256 deployerPrivateKey = vm.parseUint(privateKey);
        address deployer = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);
        
        console2.log("Deploying AaveAutopilot...");
        console2.log("Deployer:", deployer);
        console2.log("RPC URL:", rpcUrl);
        
        
        // Deploy the AaveAutopilot contract using getter functions for all addresses
        AaveAutopilot aaveAutopilot = new AaveAutopilot(
            IERC20(getUsdc()),
            "Aave Autopilot USDC",
            "apUSDC",
            getAavePool(),
            getAaveDataProvider(),
            getAUsdc(),
            getEthUsdPriceFeed(),
            getLinkToken(),
            deployer // Set deployer as the initial owner
        );
        
        // Grant keeper role to the Keeper Registry
        aaveAutopilot.grantRole(aaveAutopilot.KEEPER_ROLE(), getKeeperRegistry());
        
        console2.log("\n=== Deployment Successful ===");
        console2.log("AaveAutopilot deployed to:", address(aaveAutopilot));
        console2.log("Deployer:", deployer);
        console2.log("Network: Mainnet Fork (Tenderly)");
        
        // Save deployment info
        string memory deploymentInfo = string(abi.encodePacked(
            '{\n  "network": "mainnet-fork",\n',
            '  "deploymentTime": ', vm.toString(block.timestamp), ',\n',
            '  "aaveAutopilot": {\n',
            '    "address": "', vm.toString(address(aaveAutopilot)), '",\n',
            '    "name": "Aave Autopilot USDC",\n',
            '    "symbol": "apUSDC",\n',
            '    "owner": "', vm.toString(deployer), '",\n',
            '    "keeperRoleGranted": true\n',
            '  },\n',
            '  "tokens": {\n',
            '    "USDC": "', vm.toString(getUsdc()), '",\n',
            '    "aUSDC": "', vm.toString(getAUsdc()), '",\n',
            '    "LINK": "', vm.toString(getLinkToken()), '"\n',
            '  },\n',
            '  "aave": {\n',
            '    "pool": "', vm.toString(getAavePool()), '",\n',
            '    "dataProvider": "', vm.toString(getAaveDataProvider()), '"\n',
            '  },\n',
            '  "chainlink": {\n',
            '    "ethUsdPriceFeed": "', vm.toString(getEthUsdPriceFeed()), '",\n',
            '    "keeperRegistry": "', vm.toString(getKeeperRegistry()), '",\n',
            '    "linkToken": "', vm.toString(getLinkToken()), '"\n',
            '  }\n',
            '}'
        ));

        // Create directory if it doesn't exist
        string memory dir = "deployments/mainnet-fork";
        if (!vm.isDir(dir)) {
            vm.createDir(dir, true);
        }
        
        // Save deployment info
        string memory filename = string(abi.encodePacked(dir, "/", vm.toString(block.timestamp), ".json"));
        vm.writeFile(filename, deploymentInfo);
        vm.writeFile(string(abi.encodePacked(dir, "/latest.json")), deploymentInfo);
        
        console2.log("\nDeployment info saved to:");
        console2.log("  - ", filename);
        console2.log("  - ", string(abi.encodePacked(dir, "/latest.json")));
        
        vm.stopBroadcast();
    }
    
    /**
     * @notice Helper function to get the encoded constructor arguments
     * @dev This can be used to generate the constructor arguments for verification
     */
    function getConstructorArgs() external view returns (bytes memory) {
        return abi.encode(
            getUsdc(),
            "Aave Autopilot USDC",
            "apUSDC",
            getAavePool(),
            getAaveDataProvider(),
            getAUsdc(),
            getEthUsdPriceFeed(),
            getLinkToken(),
            msg.sender
        );
    }
}
