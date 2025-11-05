// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {AaveAutopilot} from "../src/AaveAutopilot.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {IPoolDataProvider} from "@aave/core-v3/contracts/interfaces/IPoolDataProvider.sol";
import {IAToken} from "@aave/core-v3/contracts/interfaces/IAToken.sol";

contract DeployForked is Script {
    // Sepolia testnet addresses
    address public constant USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238; // USDC on Sepolia
    address public constant AAVE_POOL = 0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951; // Aave V3 Pool
    address public constant AAVE_DATA_PROVIDER = 0x91C0EA31b49B69eA18607702C5D903A4cFfC412f; // Aave V3 Data Provider
    address public constant A_USDC = 0x16dA4541aD1807f4443d92D26044C1147406EB80; // aSepoliaUSDC
    address public constant ETH_USD_PRICE_FEED = 0x694AA1769357215DE4FAC081bf1f309aDC325306; // ETH/USD Chainlink on Sepolia
    address public constant KEEPER_REGISTRY = 0xE16Df59B887e3Caa439E0b29B42bA2e7976FD8b2; // Chainlink Automation Registry on Sepolia
    address public constant LINK = 0x779877A7B0D9E8603169DdbD7836e478b4624789; // LINK token on Sepolia
    
    function run() external {
        // Load environment variables
        string memory rpcUrl = vm.envString("RPC_URL");
        string memory privateKey = vm.envString("PRIVATE_KEY");
        
        // Start broadcasting transactions
        uint256 deployerPrivateKey = vm.parseUint(privateKey);
        address deployer = vm.rememberKey(deployerPrivateKey);
        
        console2.log("Deploying AaveAutopilot...");
        console2.log("Deployer:", deployer);
        console2.log("RPC URL:", rpcUrl);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy the AaveAutopilot contract
        AaveAutopilot aaveAutopilot = new AaveAutopilot(
            IERC20(USDC),
            "Aave Autopilot Vault",
            "aAP-VAULT",
            AAVE_POOL,
            AAVE_DATA_PROVIDER,
            A_USDC,
            ETH_USD_PRICE_FEED,
            msg.sender
        );
        
        console2.log("AaveAutopilot deployed to:", address(aaveAutopilot));
        
        // Register with Chainlink Automation
        console2.log("\n=== Next Steps ===");
        console2.log("1. Fund the contract with LINK tokens for automation:");
        console2.log("   - LINK Token:", LINK);
        console2.log("   - Contract:", address(aaveAutopilot));
        console2.log("\n2. Register with Chainlink Automation Registry:");
        console2.log("   - Registry:", KEEPER_REGISTRY);
        console2.log("   - Contract:", address(aaveAutopilot));
        console2.log("   - Gas Limit: 500000");
        console2.log("   - Admin Address:", deployer);
        
        // Save deployment info
        string memory deploymentInfo = string(abi.encodePacked(
            '{\n  "network": "sepolia",\n',
            '  "contract": "AaveAutopilot",\n',
            '  "address": "', vm.toString(address(aaveAutopilot)), '",\n',
            '  "deployer": "', vm.toString(deployer), '",\n',
            '  "deployedAt": ', vm.toString(block.timestamp), ',\n',
            '  "aavePool": "', vm.toString(AAVE_POOL), '",\n',
            '  "aToken": "', vm.toString(A_USDC), '",\n',
            '  "priceFeed": "', vm.toString(ETH_USD_PRICE_FEED), '"\n',
            '}'
        ));
        
        vm.writeFile("deployment.json", deploymentInfo);
        console2.log("\nDeployment info saved to deployment.json");
        
        vm.stopBroadcast();
        
        string memory path = string(abi.encodePacked("deployment-", vm.toString(block.chainid), "-", vm.toString(block.timestamp), ".json"));
        string memory config = string(abi.encodePacked(
            '{\n                "network": "sepolia",\n',
                '"vault": "', vm.toString(address(aaveAutopilot)), '",\n',
                '"usdc": "', vm.toString(USDC), '",\n',
                '"aavePool": "', vm.toString(AAVE_POOL), '",\n',
                '"aaveDataProvider": "', vm.toString(AAVE_DATA_PROVIDER), '",\n',
                '"aUSDC": "', vm.toString(A_USDC), '",\n',
                '"ethUsdPriceFeed": "', vm.toString(ETH_USD_PRICE_FEED), '",\n',
                '"keeperRegistry": "', vm.toString(KEEPER_REGISTRY), '",\n',
                '"linkToken": "', vm.toString(LINK), '"\n',
            '}'
        ));
        vm.writeFile(path, config);
        console2.log("\nDeployment config saved to:", path);
        
        vm.stopBroadcast();
        
        // Log deployment details
        console2.log("\n=== Deployment Summary ===");
        console2.log("Network: Base Sepolia");
        console2.log("AaveAutopilot:", address(aaveAutopilot));
        console2.log("Asset: USDC", USDC);
        console2.log("Aave Pool:", AAVE_POOL);
        console2.log("Keeper Registry:", KEEPER_REGISTRY);
        console2.log("Owner:", msg.sender);
    }
}
