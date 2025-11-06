// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// KeeperRegistry legacy interface
interface IKeeperRegistry {
    function register(
        string memory name,
        bytes calldata encryptedEmail,
        address upkeepContract,
        uint32 gasLimit,
        address adminAddress,
        bytes calldata checkData,
        uint96 amount,
        uint8 source,
        address sender
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
            uint96 amountSpent
        );
}

/**
 * @title RegisterKeeper
 * @notice Script to register AaveAutopilot with Chainlink Keepers 2.1
 * @dev Make sure to set the PRIVATE_KEY environment variable before running
 */
contract RegisterKeeper is Script {
    // Contract addresses
    address constant VAULT_ADDRESS = 0xaFf8c2337df3A7ce17525E6aa1BABCbb926F1421;
    address constant KEEPER_REGISTRY = 0x7b3EC232b08BD7b4b3305BE0C044D907B2DF960B; // Legacy Keeper Registry
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
        
        // Encode the checkUpkeep function call
        bytes memory checkData = abi.encodeWithSignature("checkUpkeep(bytes)", "");
        
        // Register the upkeep with the legacy registry
        uint256 upkeepId = registry.register(
            UPKEEP_NAME,            // Name of the upkeep
            "",                     // Encrypted email (empty for now)
            VAULT_ADDRESS,          // Target contract
            GAS_LIMIT,              // Gas limit
            deployer,               // Admin address (can cancel the upkeep)
            checkData,              // Encoded function to check
            FUND_AMOUNT,            // Initial funding amount
            0,                      // Source (0 for UI, 1 for API, etc.)
            deployer                // Sender
        );
        
        console.log("Upkeep registered with ID:", upkeepId);
        
        // Get the upkeep info to verify
        (
            address target,
            uint32 executeGas,
            , // checkData
            uint96 balance,
            , // lastKeeper
            address admin,
            , // maxValidBlocknumber
            uint96 amountSpent
        ) = registry.getUpkeep(upkeepId);
        
        console.log("\nUpkeep Details:");
        console.log("Target:", target);
        console.log("Execute Gas:", executeGas);
        console.log("Balance (LINK):", balance / 1e18, "LINK");
        console.log("Admin:", admin);
        console.log("Amount Spent (LINK):", amountSpent / 1e18, "LINK");
        
        vm.stopBroadcast();
    }
}
