// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title FundWithLink
 * @notice Script to fund the AaveAutopilot contract with LINK tokens on Sepolia
 * @dev Make sure to set the PRIVATE_KEY and RPC_URL environment variables before running
 */
contract FundWithLink is Script {
    // Sepolia testnet addresses
    address constant VAULT_ADDRESS = 0xaFf8c2337df3A7ce17525E6aa1BABCbb926F1421; // Update this after deployment
    address constant LINK_TOKEN = 0x779877A7B0D9E8603169DdbD7836e478b4624789; // Sepolia LINK Token
    
    // LINK whale address on Sepolia (you may need to fund this address first)
    // Replace with your own funded address or get LINK from the faucet: https://faucets.chain.link/sepolia
    address constant LINK_WHALE = 0x94d182C5aF3F2Bb8eB1C409Dc000cA8dC393925a; // Update this with your funded address
    
    // Amount of LINK to transfer (18 decimals)
    uint256 constant AMOUNT = 10 * 10**18; // 10 LINK
    
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
