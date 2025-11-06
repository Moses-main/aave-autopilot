// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// KeeperRegistry 2.1 interface
interface IKeeperRegistry {
    function registerUpkeep(
        string memory name,
        uint32 executeGas,
        address upkeepContract,
        uint32 checkDataOffset,
        uint32 checkDataLength,
        bytes calldata triggerConfig,
        bytes calldata offchainConfig,
        address adminAddress,
        bytes calldata checkData
    ) external returns (uint256 id);
    
    function addFunds(uint256 id, uint96 amount) external;
    
    function getUpkeep(uint256 id) 
        external 
        view 
        returns (
            address target,
            uint32 executeGas,
            bytes memory checkData,
            uint96 balance,
            address lastKeeper,
            address admin,
            uint64 maxValidBlocknumber,
            uint96 amountSpent,
            bool paused
        );
}

/**
 * @title RegisterKeeperV2
 * @notice Script to register AaveAutopilot with Chainlink Automation 2.1
 * @dev Make sure to set the PRIVATE_KEY environment variable before running
 */
contract RegisterKeeperV2 is Script {
    // Contract addresses
    address constant VAULT_ADDRESS = 0xaFf8c2337df3A7ce17525E6aa1BABCbb926F1421;
    address constant KEEPER_REGISTRY = 0xE16Df59B403e9B01F5f28a3b09a4e71c9F3509dF; // KeeperRegistry 2.1
    address constant LINK_TOKEN = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
    
    // Keeper registration parameters
    string constant UPKEEP_NAME = "AaveAutopilot Keeper";
    uint32 constant GAS_LIMIT = 1_000_000; // Adjust based on your contract's needs
    uint96 constant FUND_AMOUNT = 5 * 10**18; // 5 LINK
    
    function run() external {
        // Get deployer private key from env
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deployer:", deployer);
        console.log("Vault Address:", VAULT_ADDRESS);
        console.log("Keeper Registry:", KEEPER_REGISTRY);
        
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);
        
        // Approve Keeper Registry to spend LINK
        console.log("Approving LINK transfer...");
        IERC20 link = IERC20(LINK_TOKEN);
        link.approve(KEEPER_REGISTRY, FUND_AMOUNT);
        
        // Register the upkeep
        console.log("Registering upkeep...");
        IKeeperRegistry registry = IKeeperRegistry(KEEPER_REGISTRY);
        
        // For conditional upkeeps, triggerConfig is empty
        bytes memory triggerConfig = "";
        
        // Offchain config can be empty for basic setups
        bytes memory offchainConfig = "";
        
        // Check data - empty for conditional upkeeps
        bytes memory checkData = "";
        
        // Register the upkeep
        uint256 upkeepId = registry.registerUpkeep(
            UPKEEP_NAME,           // Name of the upkeep
            GAS_LIMIT,             // Gas limit for performUpkeep
            VAULT_ADDRESS,         // Contract to monitor
            0,                     // checkData offset (0 for no checkData)
            0,                     // checkData length (0 for no checkData)
            triggerConfig,         // Empty for conditional upkeeps
            offchainConfig,        // Empty for basic setup
            deployer,              // Admin address (can cancel/update the upkeep)
            checkData              // Empty for conditional upkeeps
        );
        
        console.log("Upkeep registered with ID:", upkeepId);
        
        // Add funds to the upkeep
        console.log("Adding funds to the upkeep...");
        registry.addFunds(upkeepId, FUND_AMOUNT);
        
        // Get the upkeep info to verify
        (
            address target,
            uint32 executeGas,
            , // checkData
            uint96 balance,
            , // lastKeeper
            address admin,
            , // maxValidBlocknumber
            , // amountSpent
            bool paused
        ) = registry.getUpkeep(upkeepId);
        
        console.log("\nUpkeep Details:");
        console.log("Target:", target);
        console.log("Execute Gas:", executeGas);
        console.log("Balance (LINK):", balance / 1e18, "LINK");
        console.log("Admin:", admin);
        console.log("Paused:", paused);
        
        vm.stopBroadcast();
    }
}
