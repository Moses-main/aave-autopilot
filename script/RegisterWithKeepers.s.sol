// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IKeeperRegistry} from "../src/interfaces/IKeeperRegistry.sol";

/**
 * @title RegisterWithKeepers
 * @notice Script to register AaveAutopilot with Chainlink Keepers
 * @dev Make sure the contract is funded with LINK before running this script
 */
contract RegisterWithKeepers is Script {
    // Contract addresses
    address constant VAULT_ADDRESS = 0xc9497Ec40951FbB98C02c666b7F9Fa143678E2Be;
    address constant KEEPER_REGISTRY = 0x7b3EC232b08BD7b4b3305BE0C044D907B2DF960B; // Legacy Keeper Registry
    address constant LINK_TOKEN = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
    
    // Keeper registration parameters
    string constant NAME = "AaveAutopilot Keeper";
    bytes4 constant REGISTER_SELECTOR = 0x4cf7e8b5; // register() selector
    uint32 constant GAS_LIMIT = 1000000; // Increased gas limit
    uint96 constant AMOUNT = 5e18; // 5 LINK - increased amount for registration
    
    function run() external {
        // Get deployer private key from env
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        if (deployerPrivateKey == 0) {
            revert("PRIVATE_KEY environment variable not set");
        }
        
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);
        
        // Get deployer address
        address deployer = vm.addr(vm.envUint("PRIVATE_KEY"));
        
        // Register with Chainlink Keepers
        IKeeperRegistry registry = IKeeperRegistry(KEEPER_REGISTRY);
        
        // Encode the checkUpkeep function call
        bytes memory checkData = abi.encodeWithSignature("checkUpkeep(bytes)", "");
        
        // Approve LINK transfer from the contract to Keeper Registry
        // Using the standard ERC20 approve function
        (bool success, ) = LINK_TOKEN.call(
            abi.encodeWithSignature(
                "approve(address,uint256)",
                KEEPER_REGISTRY,
                AMOUNT
            )
        );
        require(success, "Failed to approve LINK transfer");
        
        // Register the upkeep using the contract's LINK balance
        (uint256 upkeepId, uint256 balance) = registry.registerAndPredictID(
            NAME,
            "", // encryptedEmail - not used
            VAULT_ADDRESS, // upkeepContract - our vault
            GAS_LIMIT,
            deployer, // adminAddress - set to deployer's address
            checkData,
            LINK_TOKEN,
            AMOUNT,
            0, // source - 0 for UI registration
            deployer // sender - must be the same as adminAddress for new registrations
        );
        
        console.log("\n=== Keeper Registration Successful ===");
        console.log("Upkeep ID:", upkeepId);
        console.log("Initial Balance:", balance / 1e18, "LINK");
        console.log("Gas Limit:", GAS_LIMIT);
        
        vm.stopBroadcast();
    }
}
