// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AaveAutopilot} from "../src/AaveAutopilot.sol";

/**
 * @title TestVault
 * @notice Script to test AaveAutopilot functionality on a forked mainnet
 */
contract TestVault is Script {
    // Contract addresses
    address constant VAULT_ADDRESS = 0xaFf8c2337df3A7ce17525E6aa1BABCbb926F1421;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant USDC_WHALE = 0x47ac0Fb4F2D84898e4D9E7b4DaB3C24507a6D503;
    
    // Test amounts
    uint256 constant DEPOSIT_AMOUNT = 1000 * 1e6; // 1000 USDC (6 decimals)
    uint256 constant WITHDRAW_AMOUNT = 500 * 1e6;  // 500 USDC (6 decimals)
    
    function run() external {
        // Get deployer private key from env
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        if (deployerPrivateKey == 0) {
            revert("PRIVATE_KEY environment variable not set");
        }
        
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);
        
        // Get contract instances
        AaveAutopilot vault = AaveAutopilot(payable(VAULT_ADDRESS));
        IERC20 usdc = IERC20(USDC);
        
        // Impersonate USDC whale
        vm.startPrank(USDC_WHALE);
        
        // Step 1: Approve vault to spend USDC
        usdc.approve(VAULT_ADDRESS, DEPOSIT_AMOUNT);
        
        // Step 2: Deposit USDC into vault
        console.log("\n=== Testing Deposit ===");
        uint256 sharesBefore = vault.balanceOf(USDC_WHALE);
        console.log("Shares before deposit:", sharesBefore);
        
        vault.deposit(DEPOSIT_AMOUNT, USDC_WHALE);
        
        uint256 sharesAfter = vault.balanceOf(USDC_WHALE);
        console.log("Shares after deposit:", sharesAfter);
        console.log("Shares minted:", sharesAfter - sharesBefore);
        
        // Step 3: Check vault state
        console.log("\n=== Vault State After Deposit ===");
        console.log("Total Assets:", vault.totalAssets() / 1e6, "USDC");
        console.log("Total Supply:", vault.totalSupply() / 1e6, "shares");
        console.log("USDC Balance in Vault:", usdc.balanceOf(VAULT_ADDRESS) / 1e6, "USDC");
        
        // Step 4: Test withdrawal
        console.log("\n=== Testing Withdrawal ===");
        uint256 assetsBefore = usdc.balanceOf(USDC_WHALE);
        console.log("USDC before withdrawal:", assetsBefore / 1e6, "USDC");
        
        vault.withdraw(WITHDRAW_AMOUNT, USDC_WHALE, USDC_WHALE);
        
        uint256 assetsAfter = usdc.balanceOf(USDC_WHALE);
        console.log("USDC after withdrawal:", assetsAfter / 1e6, "USDC");
        console.log("USDC withdrawn:", (assetsAfter - assetsBefore) / 1e6, "USDC");
        
        // Step 5: Final vault state
        console.log("\n=== Final Vault State ===");
        console.log("Total Assets:", vault.totalAssets() / 1e6, "USDC");
        console.log("Total Supply:", vault.totalSupply() / 1e6, "shares");
        console.log("USDC Balance in Vault:", usdc.balanceOf(VAULT_ADDRESS) / 1e6, "USDC");
        
        // Stop impersonation and broadcasting
        vm.stopPrank();
        vm.stopBroadcast();
    }
}
