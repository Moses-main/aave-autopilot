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
 * @notice Script to register the AaveAutopilot contract with Chainlink Automation 2.1 on Sepolia
 * @dev Make sure to set the PRIVATE_KEY and RPC_URL environment variables before running
 */
contract RegisterKeeperV2 is Script {
    // Chainlink Keeper Registry 2.1 (Sepolia Testnet)
    // https://docs.chain.link/chainlink-automation/supported-networks/
    address constant KEEPER_REGISTRY = 0xE16Df59B887e3Caa439E0b29B42bA2e7976FD8b2;
    
    // The AaveAutopilot contract address to register (update after deployment)
    address constant VAULT_ADDRESS = 0xaFf8c2337df3A7ce17525E6aa1BABCbb926F1421;
    
    // LINK token (Sepolia Testnet)
    address constant LINK_TOKEN = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
    
    // Keeper configuration
    string constant UPKEEP_NAME = "AaveAutopilot Keeper";
    uint32 constant GAS_LIMIT = 500000; // Adjust based on your needs
    uint96 constant FUND_AMOUNT = 5 * 10**18; // 5 LINK (18 decimals)   
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
