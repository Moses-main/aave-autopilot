// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import "../src/AaveAutopilot.sol";
import "../src/interfaces/IAave.sol";

/**
 * @title AaveAutopilot Sepolia Deploy Script
 * @notice Script to deploy AaveAutopilot contract to Ethereum Sepolia
 * @dev Make sure to set the PRIVATE_KEY environment variable before running
 */
contract DeploySepolia is Script {
    // Sepolia addresses (as strings to avoid checksum issues)
    string constant USDC_STR = "0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8"; // Sepolia USDC
    string constant AAVE_POOL_STR = "0x6Ae43d3271fF6888e7Fc43Fd7321a503fF738951"; // Aave V3 Pool
    string constant AAVE_DATA_PROVIDER_STR = "0x9B2F5546AaE6fC2eE3BEaD55c59eB7eD8648aFe1"; // Aave Data Provider
    string constant A_USDC_STR = "0x16dA4541aD1807f4443d92D26044C1147406EB10"; // aUSDC Token
    string constant ETH_USD_PRICE_FEED_STR = "0x694AA1769357215DE4FAC081bf1f309aDC325306"; // Chainlink ETH/USD
    string constant KEEPER_REGISTRY_STR = "0xE16Df59B887e3Caa439E0b29B42bA2e7976FD8b2"; // Chainlink Keeper Registry 2.1
    string constant LINK_TOKEN_STR = "0x779877A7B0D9E8603169DdbD7836e478b4624789"; // LINK Token on Sepolia
    
    // Address variables
    address USDC;
    address AAVE_POOL;
    address AAVE_DATA_PROVIDER;
    address A_USDC;
    address ETH_USD_PRICE_FEED;
    address KEEPER_REGISTRY;
    address LINK_TOKEN;
    
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
        KEEPER_REGISTRY = vm.parseAddress(KEEPER_REGISTRY_STR);
        LINK_TOKEN = vm.parseAddress(LINK_TOKEN_STR);
        
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
        
        // Deploy AaveAutopilot
        AaveAutopilot vault = new AaveAutopilot(
            IERC20(USDC),
            "Aave Autopilot USDC",
            "apUSDC",
            AAVE_POOL, // Aave Pool address
            AAVE_DATA_PROVIDER, // Aave Data Provider
            A_USDC, // aUSDC Token
            ETH_USD_PRICE_FEED, // ETH/USD Price Feed
            LINK_TOKEN, // LINK Token for Chainlink Keepers
            deployer // Use the deployer address as the owner
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
        console.log("\nTo verify on Etherscan, run the following command:");
        console.log("\nFirst, save the constructor arguments to a file:");
        console.log("```bash");
        console.log(string(abi.encodePacked(
            "echo '{\"method\":\"constructor\",\"params\":[\"",
            toChecksumAddress(USDC), 
            "\",\"Aave Autopilot USDC\",\"apUSDC\",\"",
            toChecksumAddress(AAVE_POOL),
            "\",\"",
            toChecksumAddress(AAVE_DATA_PROVIDER),
            "\",\"",
            toChecksumAddress(A_USDC),
            "\",\"",
            toChecksumAddress(ETH_USD_PRICE_FEED),
            "\",\"",
            toChecksumAddress(msg.sender),
            "\"]}' > constructor-args.json"
        )));
        
        console.log("\nThen verify the contract:");
        console.log("```bash");
        console.log(string(abi.encodePacked(
            "forge verify-contract ",
            "--chain-id 11155111 ",
            "--constructor-args $(cat constructor-args.json) ",
            "--compiler-version v0.8.20+commit.a1b79de6 ",
            "--optimizer-runs 200 ",
            "--watch ",
            address(vault), " ",
            "src/AaveAutopilot.sol:AaveAutopilot ",
            "--etherscan-api-key $ETHERSCAN_API_KEY"
        )));
        console.log("```");
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
    function getConstructorArgs(address _owner) public pure returns (
        address asset,
        string memory name,
        string memory symbol,
        address aavePool,
        address aaveDataProvider,
        address aToken,
        address ethUsdPriceFeed,
        address owner
    ) {
        // These values should match the deployment script
        asset = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238; // USDC
        name = "Aave Autopilot USDC";
        symbol = "apUSDC";
        aavePool = 0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951;
        aaveDataProvider = 0x3e9708D80F7b3e431180130bF478987472f950aF;
        aToken = 0x16dA4541aD1807f4443d92D26044C1147406EB80;
        ethUsdPriceFeed = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
        owner = _owner; // Use the provided owner address
    }
}
