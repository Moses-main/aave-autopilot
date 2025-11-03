// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/AaveAutopilot.sol";
import "../src/interfaces/IAave.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Mock Chainlink AggregatorV3
contract MockAggregatorV3 {
    int256 public price;
    uint8 public decimals = 8;
    
    constructor(int256 _initialPrice) {
        price = _initialPrice;
    }
    
    function setPrice(int256 _price) external {
        price = _price;
    }
    
    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) {
        return (0, price, block.timestamp, block.timestamp, 0);
    }
}

contract AaveAutopilotTest is Test {
    AaveAutopilot public vault;
    MockERC20 public usdc;
    MockAggregatorV3 public ethUsdPriceFeed;
    
    // Test addresses
    address public alice = address(0x1);
    address public bob = address(0x2);
    address public keeper = address(0x3);
    
    // Aave mock addresses
    address public constant AAVE_POOL = address(0x123);
    address public constant AAVE_DATA_PROVIDER = address(0x456);
    address public constant A_TOKEN = address(0x789);
    
    // Test constants
    uint256 public constant INITIAL_ETH_PRICE = 2000 * 1e8; // $2000/ETH
    uint256 public constant USDC_DECIMALS = 6;
    uint256 public constant INITIAL_BALANCE = 10_000 * 10 ** USDC_DECIMALS;
    
    function setUp() public {
        // Deploy mock USDC
        usdc = new MockERC20();
        
        // Deploy mock Chainlink price feed
        ethUsdPriceFeed = new MockAggregatorV3(int256(INITIAL_ETH_PRICE));
        
        // Deploy vault with mock dependencies
        vault = new AaveAutopilot(
            IERC20(address(usdc)),
            "Aave Autopilot USDC",
            "apUSDC",
            AAVE_POOL,
            AAVE_DATA_PROVIDER,
            A_TOKEN,
            address(ethUsdPriceFeed)
        );

        // Give test accounts some USDC
        usdc.transfer(alice, INITIAL_BALANCE);
        usdc.transfer(bob, INITIAL_BALANCE);
        
        // Label addresses for better test traces
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(keeper, "Keeper");
        vm.label(address(usdc), "USDC");
        vm.label(AAVE_POOL, "AavePool");
        vm.label(AAVE_DATA_PROVIDER, "AaveDataProvider");
        vm.label(A_TOKEN, "aUSDC");
        vm.label(address(ethUsdPriceFeed), "ETH/USD Price Feed");
    }
    
    // Helper function to mock Aave data provider responses
    function mockAaveData(uint256 healthFactor) internal {
        // Mock Aave data provider response
        vm.mockCall(
            AAVE_DATA_PROVIDER,
            abi.encodeWithSelector(
                IPoolDataProvider.getUserReserveData.selector,
                address(usdc),
                address(vault)
            ),
            abi.encode(0, 0, 0, 0, 0, healthFactor)
        );
    }
    
    // Test deposit functionality
    function testDeposit() public {
        uint256 depositAmount = 1000 * 10 ** USDC_DECIMALS;
        
        // Mock healthy position
        mockAaveData(2.5e18); // 2.5x health factor
        
        vm.startPrank(alice);
        usdc.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, alice);
        vm.stopPrank();

        assertEq(vault.totalAssets(), depositAmount, "Incorrect total assets");
        assertEq(vault.balanceOf(alice), depositAmount, "Incorrect share balance");
    }
    
    // Test withdrawal functionality
    function testWithdraw() public {
        uint256 depositAmount = 1000 * 10 ** USDC_DECIMALS;
        
        // Mock healthy position
        mockAaveData(2.5e18);
        
        // Deposit first
        vm.startPrank(alice);
        usdc.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, alice);
        
        // Then withdraw
        vault.withdraw(depositAmount / 2, alice, alice);
        
        assertEq(
            usdc.balanceOf(alice),
            INITIAL_BALANCE - depositAmount / 2,
            "Incorrect USDC balance after withdrawal"
        );
        
        assertEq(
            vault.balanceOf(alice),
            depositAmount / 2,
            "Incorrect share balance after withdrawal"
        );
        
        vm.stopPrank();
    }
    
    // Test health factor monitoring
    function testHealthFactorCheck() public {
        uint256 depositAmount = 1000 * 10 ** USDC_DECIMALS;
        
        // Mock healthy position
        mockAaveData(2.5e18);
        
        vm.startPrank(alice);
        usdc.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, alice);
        
        // Check health factor
        uint256 healthFactor = vault.getCurrentHealthFactor();
        assertEq(healthFactor, 2.5e18, "Incorrect health factor");
        
        // Mock ETH price drop (50% drop)
        ethUsdPriceFeed.setPrice(int256(INITIAL_ETH_PRICE / 2));
        
        // Mock updated health factor after price drop
        mockAaveData(1.1e18); // Below minimum threshold
        
        // Should trigger rebalance
        vault.checkAndAdjustPosition();
        
        // Verify rebalance occurred
        // (In a real test, we would verify the actual rebalance logic)
        
        vm.stopPrank();
    }
    
    // Test Keeper compatibility
    function testKeeperCheckUpkeep() public {
        // Mock unhealthy position
        mockAaveData(1.1e18); // Below KEEPER_THRESHOLD
        
        // Fast forward time to pass cooldown
        vm.warp(block.timestamp + 2 hours);
        
        // Check if upkeep is needed
        (bool upkeepNeeded, ) = vault.checkUpkeep("");
        assertTrue(upkeepNeeded, "Upkeep should be needed");
        
        // Perform upkeep
        vm.prank(keeper);
        (bool success, ) = address(vault).call(
            abi.encodeWithSelector(
                vault.performUpkeep.selector,
                abi.encode(1.1e18) // Current health factor
            )
        );
        
        assertTrue(success, "Perform upkeep failed");
    }
    
    // Test pausing functionality
    function testPause() public {
        // Only owner can pause
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        vault.pause();
        
        // Owner can pause
        vm.prank(address(this)); // Test contract is owner in setup
        vault.pause();
        
        // Operations should be paused
        vm.startPrank(alice);
        usdc.approve(address(vault), 1000 * 10 ** USDC_DECIMALS);
        
        vm.expectRevert("Pausable: paused");
        vault.deposit(1000 * 10 ** USDC_DECIMALS, alice);
        
        // Unpause
        vm.stopPrank();
        vault.unpause();
        
        // Should work again
        vm.startPrank(alice);
        mockAaveData(2.5e18);
        vault.deposit(1000 * 10 ** USDC_DECIMALS, alice);
        vm.stopPrank();
    }
    
    // Test reentrancy protection
    function testReentrancy() public {
        // Deploy malicious contract that tries to reenter
        MaliciousContract malicious = new MaliciousContract(address(vault), address(usdc));
        
        // Fund the malicious contract
        usdc.transfer(address(malicious), 1000 * 10 ** USDC_DECIMALS);
        
        // Try to exploit reentrancy
        vm.expectRevert("ReentrancyGuard: reentrant call");
        malicious.attack();
    }
}

// Malicious contract to test reentrancy
contract MaliciousContract {
    AaveAutopilot public vault;
    IERC20 public token;
    bool private attacking;
    
    constructor(address _vault, address _token) {
        vault = AaveAutopilot(_vault);
        token = IERC20(_token);
    }
    
    // This function will be called during the reentrancy
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external returns (bytes4) {
        if (!attacking) {
            attacking = true;
            // Try to reenter
            token.transfer(msg.sender, 100);
        }
        return this.onERC721Received.selector;
    }
    
    function attack() external {
        token.approve(address(vault), type(uint256).max);
        vault.deposit(100, address(this));
    }
}
}
