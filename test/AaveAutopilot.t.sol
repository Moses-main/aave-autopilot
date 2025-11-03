// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/AaveAutopilot.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock USDC", "mUSDC") {
        _mint(msg.sender, 1_000_000 * 10**6); // 1M USDC
    }
    
    function decimals() public pure override returns (uint8) {
        return 6; // USDC has 6 decimals
    }
}

contract AaveAutopilotTest is Test {
    AaveAutopilot public vault;
    MockERC20 public usdc;
    
    address public alice = address(0x1);
    address public bob = address(0x2);
    
    function setUp() public {
        // Deploy mock USDC
        usdc = new MockERC20();
        
        // Deploy vault
        vault = new AaveAutopilot(
            IERC20(address(usdc)),
            "Aave Autopilot USDC",
            "apUSDC"
        );
        
        // Give Alice and Bob some USDC
        usdc.transfer(alice, 10_000 * 10**6); // 10k USDC
        usdc.transfer(bob, 10_000 * 10**6);
    }
    
    function testDeposit() public {
        uint256 depositAmount = 1000 * 10**6; // 1000 USDC
        
        vm.startPrank(alice);
        usdc.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, alice);
        vm.stopPrank();
        
        assertEq(vault.totalAssets(), depositAmount);
        assertEq(vault.balanceOf(alice), depositAmount); // 1:1 initially
    }
    
    function testWithdraw() public {
        // First deposit
        uint256 depositAmount = 1000 * 10**6;
        
        vm.startPrank(alice);
        usdc.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, alice);
        
        // Then withdraw
        vault.withdraw(depositAmount, alice, alice);
        vm.stopPrank();
        
        assertEq(vault.totalAssets(), 0);
        assertEq(usdc.balanceOf(alice), 10_000 * 10**6); // Got everything back
    }
}
