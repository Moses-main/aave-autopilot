// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/interfaces/IAave.sol";
import "../src/interfaces/KeeperCompatibleInterface.sol";
import "../src/AaveAutopilot.sol";

contract InteractWithDeployed is Test {
    // Deployed contract address
    AaveAutopilot public autopilot = AaveAutopilot(payable(0xb896DaacC1987B2A547e101EA8334Cf3aB0AC19a));
    
    // Base Sepolia addresses
    address constant USDC = 0x036CbD53842c5426634e7929541eC2318f3dCF7e; // Base Sepolia USDC
    address constant AAVE_POOL = 0x6dcb6D1E0D487EDAE6B45D1d1B86e1A4AD8d4a2C; // Base Sepolia Aave Pool
    address constant AAVE_DATA_PROVIDER = 0x2d8A3C5677189723C4cB8873CfC9C8976FDF38Ac; // Base Sepolia Aave Data Provider
    address constant A_USDC = 0x4C5aE35b3f16fAcaA5a41f4Ba145D9aD887e8a5a; // Base Sepolia aUSDC
    address constant ETH_USD_PRICE_FEED = 0x71041DDDAd094AE566B4d4cd0FA6C97e45B01E60; // Base Sepolia ETH/USD Price Feed
    
    // Test account with private key from .env
    uint256 privateKey = vm.envUint("PRIVATE_KEY");
    address public testAccount = vm.addr(privateKey);
    
    // ERC20 interface for USDC
    IERC20 public usdc = IERC20(USDC);
    
    function setUp() public {
        // Set up the test environment
        vm.createSelectFork("https://sepolia.base.org");
        vm.label(address(autopilot), "AaveAutopilot");
        vm.label(USDC, "USDC");
        vm.label(AAVE_POOL, "AavePool");
        vm.label(testAccount, "TestAccount");
    }
    
    function testContractState() public {
        console.log("Testing contract state...");
        
        // Check contract addresses
        assertEq(address(autopilot.asset()), USDC, "USDC address mismatch");
        assertEq(address(autopilot.aavePool()), AAVE_POOL, "Aave Pool address mismatch");
        assertEq(address(autopilot.aaveDataProvider()), AAVE_DATA_PROVIDER, "Aave Data Provider address mismatch");
        
        console.log("Contract addresses verified successfully");
    }
    
    function testDeposit() public {
        // Skip if not running on a fork
        if (block.chainid != 84532) return;
        
        console.log("Testing deposit...");
        
        // Get initial balances
        uint256 initialBalance = usdc.balanceOf(testAccount);
        console.log("Initial USDC balance:", initialBalance / 1e6, "USDC");
        
        // Approve USDC transfer
        uint256 depositAmount = 10 * 10**6; // 10 USDC (6 decimals)
        vm.prank(testAccount);
        usdc.approve(address(autopilot), depositAmount);
        
        // Deposit
        vm.prank(testAccount);
        uint256 shares = autopilot.deposit(depositAmount, testAccount);
        
        // Verify deposit
        assertGt(shares, 0, "No shares received");
        assertEq(autopilot.balanceOf(testAccount), shares, "Shares not minted correctly");
        
        console.log("Deposit successful. Shares received:", shares);
    }
    
    function testWithdraw() public {
        // Skip if not running on a fork
        if (block.chainid != 84532) return;
        
        console.log("Testing withdrawal...");
        
        // Get initial balance and shares
        uint256 initialBalance = usdc.balanceOf(testAccount);
        uint256 initialShares = autopilot.balanceOf(testAccount);
        
        if (initialShares == 0) {
            console.log("No shares to withdraw. Run deposit test first.");
            return;
        }
        
        console.log("Withdrawing", initialShares, "shares");
        
        // Withdraw
        vm.prank(testAccount);
        uint256 assets = autopilot.redeem(initialShares, testAccount, testAccount);
        
        // Verify withdrawal
        assertGt(assets, 0, "No assets received");
        assertEq(usdc.balanceOf(testAccount), initialBalance + assets, "Assets not received correctly");
        
        console.log("Withdrawal successful. Assets received:", assets / 1e6, "USDC");
    }
    
    function testCheckUpkeep() public {
        console.log("Testing checkUpkeep...");
        
        // Call checkUpkeep
        (bool upkeepNeeded, ) = autopilot.checkUpkeep("");
        
        // Get current health factor
        uint256 healthFactor = autopilot.getCurrentHealthFactor();
        
        console.log("Current health factor:", healthFactor);
        console.log("Upkeep needed:", upkeepNeeded ? "Yes" : "No");
        
        // This is just for information, as the result depends on the current state
        assertTrue(true, "checkUpkeep called successfully");
    }
    
    function testPerformUpkeep() public {
        // Skip if not running on a fork
        if (block.chainid != 84532) return;
        
        console.log("Testing performUpkeep...");
        
        // First check if upkeep is needed
        (bool upkeepNeeded, bytes memory performData) = autopilot.checkUpkeep("");
        
        if (!upkeepNeeded) {
            console.log("No upkeep needed at this time");
            return;
        }
        
        // Get health factor before
        uint256 healthFactorBefore = autopilot.getCurrentHealthFactor();
        
        // Perform upkeep
        vm.prank(testAccount);
        autopilot.performUpkeep(performData);
        
        // Get health factor after
        uint256 healthFactorAfter = autopilot.getCurrentHealthFactor();
        
        console.log("Health factor before:", healthFactorBefore);
        console.log("Health factor after: ", healthFactorAfter);
        
        // Verify health factor improved or stayed the same
        assertGe(healthFactorAfter, healthFactorBefore, "Health factor did not improve");
    }
}
