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
    address constant VAULT_ADDRESS = 0x129918F79fB60dc1AC3f07316f0683f9Fa356178;
    address constant KEEPER_REGISTRY = 0xE16Df59B403e9B01F5f28a3b09a4e71c9F3509dF;
    address constant LINK_TOKEN = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
    
    // Keeper registration parameters
    string constant NAME = "AaveAutopilot Keeper";
    bytes4 constant REGISTER_SELECTOR = 0x4cf7e8b5; // register() selector
    uint32 constant GAS_LIMIT = 500000;
    uint96 constant AMOUNT = 1e18; // 1 LINK
    
    function run() external {
        // Get deployer private key from env
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        if (deployerPrivateKey == 0) {
            revert("PRIVATE_KEY environment variable not set");
        }
        
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);
        
        // Approve LINK transfer to Keeper Registry
        IERC20 link = IERC20(LINK_TOKEN);
        link.approve(KEEPER_REGISTRY, AMOUNT);
        
        // Register with Chainlink Keepers
        IKeeperRegistry registry = IKeeperRegistry(KEEPER_REGISTRY);
        
        // Encode the checkUpkeep function call
        bytes memory checkData = abi.encodeWithSignature("checkUpkeep(bytes)", "");
        
        // Register the upkeep
        (uint256 upkeepId, uint256 balance) = registry.registerAndPredictID(
            NAME,
            "", // encryptedEmail - not used
            VAULT_ADDRESS, // upkeepContract - our vault
            GAS_LIMIT,
            address(this), // adminAddress - can be changed to a multisig later
            checkData,
            LINK_TOKEN,
            AMOUNT,
            0, // source - 0 for UI registration
            address(this) // sender - must be the same as adminAddress for new registrations
        );
        
        console.log("\n=== Keeper Registration Successful ===");
        console.log("Upkeep ID:", upkeepId);
        console.log("Initial Balance:", balance / 1e18, "LINK");
        console.log("Gas Limit:", GAS_LIMIT);
        
        vm.stopBroadcast();
    }
}
