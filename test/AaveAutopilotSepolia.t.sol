// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/AaveAutopilot.sol";

contract AaveAutopilotSepoliaTest is Test {
    // Sepolia addresses
    address constant USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238; // Sepolia USDC
    address constant AAVE_POOL = 0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951; // Sepolia Aave Pool
    address constant AAVE_DATA_PROVIDER = 0x3e9708D80F7b3e431180130bF478987472f950aF; // Sepolia Aave Data Provider
    address constant A_USDC = 0x16dA4541aD1807f4443d92D26044C1147406EB80; // Sepolia aUSDC
    address constant ETH_USD_PRICE_FEED = 0x694AA1769357215DE4FAC081bf1f309aDC325306; // Sepolia ETH/USD Price Feed
    address constant LINK_TOKEN = 0x779877A7B0D9E8603169DdbD7836e478b4624789; // Sepolia LINK
    
    // Test accounts
    address deployer = makeAddr("deployer");
    address user1 = makeAddr("user1");
    address keeper = makeAddr("keeper");
    
    // Contract instances
    AaveAutopilot public autopilot;
    
    // Fork setup
    uint256 sepoliaFork;
    string SEPOLIA_RPC_URL = vm.envString("SEPOLIA_RPC_URL");
    
    function setUp() public {
        // Create a fork of Sepolia
        sepoliaFork = vm.createFork(SEPOLIA_RPC_URL);
        vm.selectFork(sepoliaFork);
        
        // Deploy the contract
        vm.startPrank(deployer);
        autopilot = new AaveAutopilot(
            IERC20(USDC),
            "Aave Autopilot USDC",
            "apUSDC",
            IPool(AAVE_POOL),
            AAVE_DATA_PROVIDER,
            A_USDC,
            ETH_USD_PRICE_FEED,
            deployer
        );
        
        // Grant KEEPER_ROLE to the keeper
        autopilot.grantRole(autopilot.KEEPER_ROLE(), keeper);
        vm.stopPrank();
        
        // Fund test accounts with ETH
        vm.deal(user1, 10 ether);
        vm.deal(keeper, 10 ether);
    }
    
    function testDeployment() public {
        assertEq(autopilot.name(), "Aave Autopilot USDC");
        assertEq(autopilot.symbol(), "apUSDC");
        assertEq(autopilot.owner(), deployer);
    }
    
    function testDepositAndWithdraw() public {
        // Impersonate a user with USDC
        address usdcWhale = 0x6E5B0aDDb50a5a4d2C4e3A8D0a1C1C5e4F5E6D7C; // Example whale address
        vm.startPrank(usdcWhale);
        
        // Approve autopilot to spend USDC
        IERC20(USDC).approve(address(autopilot), 1000e6);
        
        // Deposit USDC
        autopilot.deposit(1000e6, user1);
        
        // Check balances
        assertEq(IERC20(USDC).balanceOf(address(autopilot)), 0); // Should be 0 as it's deposited to Aave
        assertEq(autopilot.balanceOf(user1), 1000e6);
        
        // Withdraw
        vm.startPrank(user1);
        autopilot.withdraw(500e6, user1, user1);
        
        // Check balances after withdrawal
        assertEq(autopilot.balanceOf(user1), 500e6);
        assertGt(IERC20(USDC).balanceOf(user1), 0);
        
        vm.stopPrank();
    }
    
    function testKeeperFunctions() public {
        // Impersonate keeper
        vm.startPrank(keeper);
        
        // Test checkUpkeep with no positions (should not need upkeep)
        (bool upkeepNeeded, ) = autopilot.checkUpkeep("");
        assertFalse(upkeepNeeded, "No upkeep should be needed initially");
        
        // Test performUpkeep with no work to do
        vm.expectRevert("No work to do");
        autopilot.performUpkeep("");
        
        vm.stopPrank();
    }
    
    function testHealthFactorCalculation() public view {
        // Test health factor calculation
        uint256 healthFactor = autopilot.getHealthFactor(user1);
        assertGt(healthFactor, 0, "Health factor should be greater than 0");
    }
}
