// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title FundWithLink
 * @notice Script to fund the AaveAutopilot contract with LINK tokens for Chainlink Keepers
 * @dev Make sure to set the PRIVATE_KEY environment variable before running
 */
contract FundWithLink is Script {
    // Contract addresses
    address constant VAULT_ADDRESS = 0xaFf8c2337df3A7ce17525E6aa1BABCbb926F1421;
    address constant LINK_TOKEN = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
    
    // LINK whale address with lots of tokens (on mainnet)
    address constant LINK_WHALE = 0x3f5CE5FBFe3E9aF3971dD833D26bA9b5C936f0bE;
    
    // Amount of LINK to transfer (18 decimals)
    uint256 constant LINK_AMOUNT = 10 * 10**18; // 10 LINK
    
    function run() external {
        // Get deployer private key from env
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        if (deployerPrivateKey == 0) {
            revert("PRIVATE_KEY environment variable not set");
        }
        
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);
        
        // Impersonate the LINK whale
        vm.startPrank(LINK_WHALE);
        
        // Transfer LINK to the vault
        IERC20 link = IERC20(LINK_TOKEN);
        bool success = link.transfer(VAULT_ADDRESS, LINK_AMOUNT);
        
        if (!success) {
            revert("Failed to transfer LINK tokens");
        }
        
        // Stop impersonation
        vm.stopPrank();
        
        // Verify the transfer
        uint256 vaultLinkBalance = link.balanceOf(VAULT_ADDRESS);
        
        console.log("\n=== LINK Funding Successful ===");
        console.log("Vault Address:", VAULT_ADDRESS);
        console.log("LINK Amount Sent:", LINK_AMOUNT / 1e18, "LINK");
        console.log("Vault LINK Balance:", vaultLinkBalance / 1e18, "LINK");
        
        vm.stopBroadcast();
    }
}
