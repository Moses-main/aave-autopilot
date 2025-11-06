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
    // Sepolia testnet addresses - AaveAutopilot contract address
    address constant VAULT_ADDRESS = 0xA076ecA49434a4475a9FF716c2E9f20ccc453c20; // Deployed AaveAutopilot address
    address constant LINK_TOKEN = 0x779877A7B0D9E8603169DdbD7836e478b4624789; // Sepolia LINK Token
    
    // LINK whale address on Sepolia (you may need to fund this address first)
    // Replace with your own funded address or get LINK from the faucet: https://faucets.chain.link/sepolia
    address constant LINK_WHALE = 0x94d182c5AF3F2Bb8eB1C409dc000cA8dc393925A; // Corrected checksum
    
    // Amount of LINK to transfer (18 decimals)
    uint256 constant LINK_AMOUNT = 10 * 10**18; // 10 LINK
    
    function run() external {
        // Get deployer private key from env
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        if (deployerPrivateKey == 0) {
            revert("PRIVATE_KEY environment variable not set");
        }
        
        // Get the deployer address from the private key
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deployer:", deployer);
        console.log("LINK_WHALE:", LINK_WHALE);
        console.log("VAULT_ADDRESS:", VAULT_ADDRESS);
        
        // Start broadcasting transactions from the deployer
        vm.startBroadcast(deployerPrivateKey);
        
        // Get LINK token instance
        IERC20 link = IERC20(LINK_TOKEN);
        
        // Check deployer's LINK balance
        uint256 deployerLinkBalance = link.balanceOf(deployer);
        console.log("Deployer LINK Balance:", deployerLinkBalance / 1e18, "LINK");
        
        if (deployerLinkBalance < LINK_AMOUNT) {
            revert("Insufficient LINK balance. Please fund the deployer address with at least 10 LINK.");
        }
        
        // Get current vault LINK balance
        uint256 vaultBalanceBefore = link.balanceOf(VAULT_ADDRESS);
        console.log("Vault LINK Balance Before:", vaultBalanceBefore / 1e18, "LINK");
        
        // Transfer LINK from deployer to vault
        bool success = link.transfer(VAULT_ADDRESS, LINK_AMOUNT);
        
        if (!success) {
            revert("Failed to transfer LINK tokens. Check if the deployer has approved this contract to spend LINK.");
        }
        
        // Verify the transfer
        uint256 vaultBalanceAfter = link.balanceOf(VAULT_ADDRESS);
        uint256 actualTransferred = vaultBalanceAfter - vaultBalanceBefore;
        
        console.log("\n=== LINK Funding Successful ===");
        console.log("From:", deployer);
        console.log("To (Vault):", VAULT_ADDRESS);
        console.log("LINK Amount Sent:", actualTransferred / 1e18, "LINK");
        console.log("Vault LINK Balance After:", vaultBalanceAfter / 1e18, "LINK");
        
        vm.stopBroadcast();
    }
}
