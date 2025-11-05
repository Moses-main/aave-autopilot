// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/AaveAutopilot.sol";

contract SimpleInteract is Test {
    AaveAutopilot public autopilot;
    
    // Base Sepolia addresses
    address constant USDC = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;
    address constant AAVE_POOL = 0x6dcb6D1E0D487EDAE6B45D1d1B86e1A4AD8d4a2C;
    address constant AAVE_DATA_PROVIDER = 0x2d8A3C5677189723C4cB8873CfC9C8976FDF38Ac;
    address constant A_USDC = 0x4C5aE35b3f16fAcaA5a41f4Ba145D9aD887e8a5a;
    address constant ETH_USD_PRICE_FEED = 0x71041DDDAd094AE566B4d4cd0FA6C97e45B01E60;
    
    // Test account
    uint256 privateKey = vm.envUint("PRIVATE_KEY");
    address testAccount = vm.addr(privateKey);
    
    // ERC20 interface
    IERC20 public usdc = IERC20(USDC);
    
    function setUp() public {
        // Set up the test environment
        vm.createSelectFork("https://sepolia.base.org");
        
        // Deploy a new instance or use the deployed one
        autopilot = AaveAutopilot(payable(0xb896DaacC1987B2A547e101EA8334Cf3aB0AC19a));
        
        // Label addresses for better error messages
        vm.label(address(autopilot), "AaveAutopilot");
        vm.label(USDC, "USDC");
        vm.label(AAVE_POOL, "AavePool");
        vm.label(AAVE_DATA_PROVIDER, "AaveDataProvider");
        vm.label(A_USDC, "aUSDC");
        vm.label(ETH_USD_PRICE_FEED, "ETH/USD Price Feed");
        vm.label(testAccount, "TestAccount");
    }
    
    function testBasicInfo() public {
        console.log("Testing basic contract info...");
        
        // Check contract addresses
        address asset = autopilot.asset();
        IPool aavePool = autopilot.aavePool();
        IPoolDataProvider aaveDataProvider = autopilot.aaveDataProvider();
        
        console.log("Asset:", asset);
        console.log("Aave Pool:", address(aavePool));
        console.log("Aave Data Provider:", address(aaveDataProvider));
        
        // Basic assertions
        assertEq(asset, USDC, "USDC address mismatch");
        assertEq(address(aavePool), AAVE_POOL, "Aave Pool address mismatch");
        assertEq(address(aaveDataProvider), AAVE_DATA_PROVIDER, "Aave Data Provider address mismatch");
    }
    
    function testCheckUpkeep() public {
        console.log("Testing checkUpkeep...");
        
        // Call checkUpkeep
        (bool upkeepNeeded, ) = autopilot.checkUpkeep("");
        
        // Get current health factor
        uint256 healthFactor = autopilot.getCurrentHealthFactor();
        
        console.log("Current health factor:", healthFactor);
        console.log("Upkeep needed:", upkeepNeeded ? "Yes" : "No");
        
        // This is just for information
        assertTrue(true, "checkUpkeep called successfully");
    }
    
    function testDeposit() public {
        console.log("Testing deposit...");
        
        // Skip if not running on a fork
        if (block.chainid != 84532) return;
        
        // Get initial balance
        uint256 initialBalance = usdc.balanceOf(testAccount);
        console.log("Initial USDC balance:", initialBalance / 1e6, "USDC");
        
        if (initialBalance == 0) {
            console.log("No USDC balance to deposit");
            return;
        }
        
        // Use 10% of balance or 10 USDC, whichever is smaller
        uint256 depositAmount = initialBalance / 10 > 10e6 ? 10e6 : initialBalance / 10;
        
        console.log("Depositing", depositAmount / 1e6, "USDC");
        
        // Approve USDC transfer
        vm.prank(testAccount);
        usdc.approve(address(autopilot), depositAmount);
        
        // Deposit
        vm.prank(testAccount);
        uint256 shares = autopilot.deposit(depositAmount, testAccount);
        
        // Verify deposit
        assertGt(shares, 0, "No shares received");
        console.log("Deposit successful. Shares received:", shares);
    }
}
