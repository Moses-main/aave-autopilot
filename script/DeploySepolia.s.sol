// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import "../src/AaveAutopilot.sol";

/**
 * @title AaveAutopilot Sepolia Deploy Script
 * @notice Script to deploy AaveAutopilot contract to Ethereum Sepolia
 * @dev Make sure to set the PRIVATE_KEY environment variable before running
 */
contract DeploySepolia is Script {
    // Sepolia addresses
    address constant USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238; // Sepolia USDC
    address constant AAVE_POOL = 0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951; // Sepolia Aave Pool
    address constant AAVE_DATA_PROVIDER = 0x3e9708D80F7b3e431180130bF478987472f950aF; // Sepolia Aave Data Provider
    address constant A_USDC = 0x16dA4541aD1807f4443d92D26044C1147406EB80; // Sepolia aUSDC
    address constant ETH_USD_PRICE_FEED = 0x694AA1769357215DE4FAC081bf1f309aDC325306; // Sepolia ETH/USD Price Feed
    
    // Chainlink Keeper Registry (Sepolia)
    address constant KEEPER_REGISTRY = 0xE16Df59B403e9b01f5F28a3b09a4e71c9f3509dF;
    address constant LINK_TOKEN = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
    
    // Events for better logging
    event ContractDeployed(address indexed contractAddress, string contractName);
    event ConfigurationSet(address indexed contractAddress, string config, address value);
    
    function run() external {
        // Get deployer private key from env
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        if (deployerPrivateKey == 0) {
            revert("PRIVATE_KEY environment variable not set");
        }
        
        address deployer = vm.addr(deployerPrivateKey);
        console.log("Starting deployment of AaveAutopilot to Sepolia...");
        console.log("Deployer:", deployer);
        
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy the vault
        AaveAutopilot vault = new AaveAutopilot(
            IERC20(USDC), // USDC token
            "Aave Autopilot USDC", // Vault name
            "apUSDC", // Vault symbol
            IPool(AAVE_POOL), // Aave Pool
            AAVE_DATA_PROVIDER, // Aave Data Provider
            A_USDC, // aUSDC token
            ETH_USD_PRICE_FEED, // ETH/USD price feed
            deployer // Owner
        );
        
        // Log deployment details
        console.log("\n=== Deployment Summary ===");
        console.log("Network: Sepolia");
        console.log("Deployer:", deployer);
        console.log("AaveAutopilot deployed to:", address(vault));
        
        // Verify critical configurations
        console.log("\n=== Configuration ===");
        console.log("USDC Token:", USDC);
        console.log("Aave Pool:", AAVE_POOL);
        console.log("Aave Data Provider:", AAVE_DATA_PROVIDER);
        console.log("aUSDC Token:", A_USDC);
        console.log("ETH/USD Price Feed:", ETH_USD_PRICE_FEED);
        console.log("Chainlink Keeper Registry:", KEEPER_REGISTRY);
        console.log("LINK Token:", LINK_TOKEN);
        
        emit ContractDeployed(address(vault), "AaveAutopilot");
        
        // Stop broadcasting
        vm.stopBroadcast();
        
        console.log("\nDeployment completed successfully!");
        
        // Prepare verification command
        console.log("\nTo verify on Etherscan, run:");
        console.log(string(abi.encodePacked(
            "forge verify-contract ",
            "--chain-id 11155111 \
            --constructor-args $(cast abi-encode "constructor(address,string,string,address,address,address,address,address)" \
            "0x", toChecksumAddress(USDC), " \
            \"Aave Autopilot USDC\" \
            \"apUSDC\" \
            \"0x", toChecksumAddress(AAVE_POOL), "\" \
            \"0x", toChecksumAddress(AAVE_DATA_PROVIDER), "\" \
            \"0x", toChecksumAddress(A_USDC), "\" \
            \"0x", toChecksumAddress(ETH_USD_PRICE_FEED), "\" \
            \"0x", toChecksumAddress(deployer), "\") \
            --compiler-version v0.8.20+commit.a1b79de6 \
            --optimizer-runs 200 \
            --watch \
            ", address(vault), " \
            src/AaveAutopilot.sol:AaveAutopilot \
            --etherscan-api-key $ETHERSCAN_API_KEY"
        )));
    }
    
    // Helper function to convert address to checksum format
    function toChecksumAddress(address account) internal pure returns (string memory) {
        bytes20 addr = bytes20(account);
        bytes memory alphabet = "0123456789abcdef";
        
        bytes memory str = new bytes(42);
        str[0] = '0';
        str[1] = 'x';
        
        for (uint i = 0; i < 20; i++) {
            str[2 + i * 2] = alphabet[uint8(addr[i] >> 4)];
            str[3 + i * 2] = alphabet[uint8(addr[i] & 0x0f)];
        }
        
        return string(str);
    }
}

// Helper contract to generate constructor arguments for verification
contract AaveAutopilotConstructorArgs {
    function getConstructorArgs() public pure returns (
        address asset,
        string memory name,
        string memory symbol,
        address aavePool,
        address aaveDataProvider,
        address aToken,
        address ethUsdPriceFeed,
        address owner
    ) {
        asset = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238; // USDC
        name = "Aave Autopilot USDC";
        symbol = "apUSDC";
        aavePool = 0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951;
        aaveDataProvider = 0x3e9708D80F7b3e431180130bF478987472f950aF;
        aToken = 0x16dA4541aD1807f4443d92D26044C1147406EB80;
        ethUsdPriceFeed = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
        owner = msg.sender; // This will be replaced with actual deployer
    }
}
