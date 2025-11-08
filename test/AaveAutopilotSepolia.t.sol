// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Tests for AaveAutopilot on Sepolia
// To run: forge test --match-path test/AaveAutopilotSepolia.t.sol -vvv

import "forge-std/Test.sol";
import "../src/AaveAutopilot.sol";

// Wrapper contract to expose internal functions for testing
contract AaveAutopilotWrapper is AaveAutopilot {
    constructor(
        IERC20 _asset,
        string memory _name,
        string memory _symbol,
        address _aavePool,
        address _aaveDataProvider,
        address _aToken,
        address _ethUsdPriceFeed,
        address _linkToken,
        address _owner
    ) AaveAutopilot(
        _asset,
        _name,
        _symbol,
        _aavePool,
        _aaveDataProvider,
        _aToken,
        _ethUsdPriceFeed,
        _linkToken,
        _owner
    ) {}
    
    // Wrapper to expose _getHealthFactorView for testing
    function getHealthFactorView(address user) external view returns (uint256) {
        return _getHealthFactorView(user);
    }
}

contract AaveAutopilotSepoliaTest is Test {
    // Sepolia testnet addresses with correct checksums
    address constant USDC = 0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8;  // USDC (6 decimals)
    address constant AAVE_POOL = 0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951;  // Aave Pool
    address constant AAVE_DATA_PROVIDER = 0x9B2F5546aaE6fC2eE3BeAD55c59Eb7eD8648Afe1;  // Aave Data Provider
    address constant A_USDC = 0x16DA4541AD1807f4443d92d26044c1147406eB10;  // aUSDC (6 decimals)
    address constant ETH_USD_PRICE_FEED = 0x694AA1769357215DE4FAC081bf1f309aDC325306;  // ETH/USD Price Feed
    address constant LINK_TOKEN = 0x779877A7B0D9E8603169DdbD7836e478b4624789;  // LINK Token
    address constant KEEPER_REGISTRY = 0xE16Df59B887e3Caa439E0b29B42bA2e7976FD8b2;  // Keeper Registry 2.1
    
    // Test parameters
    uint256 constant DEPOSIT_AMOUNT = 1000 * 10**6; // 1000 USDC (6 decimals)
    uint256 constant WITHDRAW_AMOUNT = 500 * 10**6;  // 500 USDC (6 decimals)
    
    // Test accounts
    address constant USER = address(0x1234);
    address constant OWNER = address(0x5678);
    
    // Contract instances
    AaveAutopilotWrapper public vault;
    IERC20 public usdc;
    
    function setUp() public {
        // Deploy the vault
        usdc = IERC20(USDC);
        
        vault = new AaveAutopilotWrapper(
            IERC20(USDC),
            "Aave Autopilot Vault",
            "aapUSDC",
            AAVE_POOL,
            AAVE_DATA_PROVIDER,
            A_USDC,
            ETH_USD_PRICE_FEED,
            LINK_TOKEN,
            OWNER
        );
        
        // Transfer USDC to test user
        deal(USDC, USER, DEPOSIT_AMOUNT * 2);
    }
    
    function testDeposit() public {
        // Impersonate user
        vm.startPrank(USER);
        
        // Approve vault to spend USDC
        usdc.approve(address(vault), DEPOSIT_AMOUNT);
        
        // Deposit USDC
        uint256 shares = vault.deposit(DEPOSIT_AMOUNT, USER);
        
        // Verify deposit
        assertGt(shares, 0, "Shares should be greater than 0");
        assertEq(vault.balanceOf(USER), shares, "User should have correct share balance");
        
        vm.stopPrank();
    }
    
    function testWithdraw() public {
        // First deposit
        testDeposit();
        
        // Impersonate user
        vm.startPrank(USER);
        
        // Withdraw USDC
        uint256 assets = vault.redeem(WITHDRAW_AMOUNT, USER, USER);
        
        // Verify withdrawal
        assertGt(assets, 0, "Assets should be greater than 0");
        assertEq(usdc.balanceOf(USER), DEPOSIT_AMOUNT - WITHDRAW_AMOUNT, "User should have correct USDC balance");
        
        vm.stopPrank();
    }
    
    function testHealthFactor() public {
        // First deposit
        testDeposit();
        
        // Get health factor
        uint256 healthFactor = vault.getHealthFactorView(USER);
        
        // Verify health factor is greater than 1e18 (1.0 in Aave's format)
        assertGt(healthFactor, 1e18, "Health factor should be greater than 1.0");
    }
}
