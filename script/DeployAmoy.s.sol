// File: script/DeployAmoy.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import "../src/AaveAutopilot.sol";
import "../src/interfaces/IAave.sol";

contract DeployAmoy is Script {
    // Polygon Amoy addresses
    string constant WMATIC_STR = "0x9c3C9283D3e44854697Cd22D3FAA240Cfb032889"; // WMATIC on Amoy
    string constant AAVE_POOL_STR = "0x6C9fB0D5bD9429eb9Cd96B85B81d872281771AB6"; // Aave V3 Pool
    string constant AAVE_DATA_PROVIDER_STR = "0x2d8A3C5677189723C4cB8873CfC9C8976FDF38Af"; // Aave Data Provider
    string constant A_WMATIC_STR = "0x1E4b7B4B2E4aB5eB8e0aF89840ac02c2458dEbd"; // aWMATIC Token
    string constant MATIC_USD_PRICE_FEED_STR = "0xd0D5e3DB44DE05E9F294BB0a3bEEaF030DE24Ada"; // Chainlink MATIC/USD
    string constant KEEPER_REGISTRY_STR = "0xE16Df59B887e3Caa439E0b29B42bA2e7976FD8b2"; // Chainlink Keeper Registry
    string constant LINK_TOKEN_STR = "0x326C977E6efc84E512bB9C30f76E30c160eD06FB"; // LINK Token on Amoy
    
    // Address variables
    address WMATIC;
    address AAVE_POOL;
    address AAVE_DATA_PROVIDER;
    address A_WMATIC;
    address MATIC_USD_PRICE_FEED;
    address KEEPER_REGISTRY;
    address LINK_TOKEN;
    
    event ContractDeployed(address indexed contractAddress, string contractName);
    event ConfigurationSet(address indexed contractAddress, string config, address value);
    
    function run() external {
        // Parse all addresses from strings
        WMATIC = vm.parseAddress(WMATIC_STR);
        AAVE_POOL = vm.parseAddress(AAVE_POOL_STR);
        AAVE_DATA_PROVIDER = vm.parseAddress(AAVE_DATA_PROVIDER_STR);
        A_WMATIC = vm.parseAddress(A_WMATIC_STR);
        MATIC_USD_PRICE_FEED = vm.parseAddress(MATIC_USD_PRICE_FEED_STR);
        KEEPER_REGISTRY = vm.parseAddress(KEEPER_REGISTRY_STR);
        LINK_TOKEN = vm.parseAddress(LINK_TOKEN_STR);
        
        // Get deployer private key from env
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        if (deployerPrivateKey == 0) {
            revert("PRIVATE_KEY environment variable not set");
        }
        
        address deployer = vm.addr(deployerPrivateKey);
        console.log("Starting deployment of AaveAutopilot to Polygon Amoy...");
        console.log("Deployer:", deployer);
        
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy AaveAutopilot
        console.log("Deploying AaveAutopilot...");
        AaveAutopilot vault = new AaveAutopilot(
            IERC20Metadata(WMATIC),  // _asset (WMATIC)
            "Wrapped Matic Vault",   // _name
            "WMATIC-VAULT",          // _symbol
            AAVE_POOL,               // _aavePool
            AAVE_DATA_PROVIDER,      // _aaveDataProvider
            A_WMATIC,                // _aToken
            MATIC_USD_PRICE_FEED,    // _priceFeed
            LINK_TOKEN               // _linkToken
        );
        
        // Transfer ownership to the deployer
        vault.transferOwnership(deployer);
        
        // Log deployment details
        console.log("\n=== Deployment Summary ===");
        console.log("Network: Polygon Amoy (Testnet)");
        console.log("Deployer:", deployer);
        console.log("AaveAutopilot deployed to:", address(vault));
        
        console.log("\n=== Configuration ===");
        console.log("WMATIC Token:", WMATIC);
        console.log("AAVE Pool:", AAVE_POOL);
        console.log("AAVE Data Provider:", AAVE_DATA_PROVIDER);
        console.log("aWMATIC Token:", A_WMATIC);
        console.log("MATIC/USD Price Feed:", MATIC_USD_PRICE_FEED);
        console.log("Chainlink Keeper Registry:", KEEPER_REGISTRY);
        console.log("LINK Token:", LINK_TOKEN);
        
        emit ContractDeployed(address(vault), "AaveAutopilot");
        
        // Stop broadcasting
        vm.stopBroadcast();
        
        console.log("\nDeployment completed successfully!");
        
        // Prepare verification command
        console.log("\nTo verify on Polygonscan, run the following command:");
        console.log("\nFirst, save the constructor arguments to a file:");
        console.log("echo '");
        console.log('{"_asset":"', WMATIC, '",');
        console.log('"_name":"Wrapped Matic Vault",');
        console.log('"_symbol":"WMATIC-VAULT",');
        console.log('"_aavePool":"', AAVE_POOL, '",');
        console.log('"_aaveDataProvider":"', AAVE_DATA_PROVIDER, '",');
        console.log('"_aToken":"', A_WMATIC, '",');
        console.log('"_ethUsdPriceFeed":"', MATIC_USD_PRICE_FEED, '",');
        console.log('"_linkToken":"', LINK_TOKEN, '"}');
        console.log("' > constructor-args.json");
        
        console.log("\nThen run the verification command:");
        console.log("forge verify-contract --chain-id 80002 \\");
        console.log("  --constructor-args $(cat constructor-args.json) \\");
        console.log("  --compiler-version v0.8.19 \\");
        console.log("  --watch \\");
        console.log("  ", address(vault), " src/AaveAutopilot.sol:AaveAutopilot \\");
        console.log("  $POLYGONSCAN_API_KEY");
    }
}

// Helper contract to generate constructor arguments for verification
contract AaveAutopilotConstructorArgs {
    function getConstructorArgs() public pure returns (
        address _asset,
        string memory _name,
        string memory _symbol,
        address _aavePool,
        address _aaveDataProvider,
        address _aToken,
        address _ethUsdPriceFeed,
        address _linkToken
    ) {
        return (
            0x9c3C9283D3e44854697Cd22D3FAA240Cfb032889, // WMATIC
            "Wrapped Matic Vault",
            "WMATIC-VAULT",
            0x6C9fB0D5bD9429eb9Cd96B85B81d872281771AB6, // AAVE_POOL
            0x2d8A3C5677189723C4cB8873CfC9C8976FDF38Af, // AAVE_DATA_PROVIDER
            0x1E4b7B4B2E4aB5eB8e0aF89840ac02c2458dEbd, // aWMATIC
            0xd0D5e3DB44DE05E9F294BB0a3bEEaF030DE24Ada, // MATIC/USD Price Feed
            0x326C977E6efc84E512bB9C30f76E30c160eD06FB  // LINK Token
        );
    }
}