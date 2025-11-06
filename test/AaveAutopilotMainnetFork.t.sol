// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

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

contract AaveAutopilotMainnetForkTest is Test {
    // Mainnet addresses with correct checksums
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant AAVE_POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address constant AAVE_DATA_PROVIDER = 0x7B4EB56E7CD4b454BA8ff71E4518426369a138a3;
    address constant A_USDC = 0x98C23E9d8f34FEfb1B7Bd6a91B7bB122f4E16f5c;
    address constant ETH_USD_PRICE_FEED = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address constant LINK_TOKEN = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
    
    // Test user who will deposit USDC (using a known USDC whale for testing)
    address constant USDC_WHALE = 0x47ac0Fb4F2D84898e4D9E7b4DaB3C24507a6D503;
    address testUser = address(0x123);
    
    // Test accounts
    address owner = address(0x1);
    address user1 = address(0x2);
    address keeper = address(0x3);
    
    // Contract instance
    AaveAutopilotWrapper public autopilot;
    
    // RPC URL for Tenderly fork (from environment variable)
    string RPC_URL;
    
    function setUp() public {
        // Get RPC URL from environment
        RPC_URL = vm.envString("RPC_URL");
        
        // Create and select a fork of Ethereum Mainnet
        uint256 forkId = vm.createFork(RPC_URL);
        vm.selectFork(forkId);
        
        // Make all necessary contracts persistent in the forked environment
        address[] memory contracts = new address[](7);
        contracts[0] = USDC;
        contracts[1] = AAVE_POOL;
        contracts[2] = AAVE_DATA_PROVIDER;
        contracts[3] = A_USDC;
        contracts[4] = ETH_USD_PRICE_FEED;
        contracts[5] = LINK_TOKEN;
        contracts[6] = USDC_WHALE;
        
        for (uint i = 0; i < contracts.length; i++) {
            vm.makePersistent(contracts[i]);
        }
        
        // Deploy the autopilot contract
        vm.startPrank(owner);
        
        autopilot = new AaveAutopilotWrapper(
            IERC20(USDC),
            "Aave Autopilot Vault",
            "aAuto-USDC",
            AAVE_POOL,
            AAVE_DATA_PROVIDER,
            A_USDC,
            ETH_USD_PRICE_FEED,
            LINK_TOKEN,
            owner
        );
        
        // Make the deployed contract persistent
        vm.makePersistent(address(autopilot));
        
        // Grant keeper role
        autopilot.grantRole(autopilot.KEEPER_ROLE(), keeper);
        
        // Get some USDC from the whale for testing
        uint256 amountToTransfer = 10000 * 10**6; // 10,000 USDC (6 decimals)
        
        // Impersonate the USDC whale and transfer to test user
        vm.startPrank(USDC_WHALE);
        IERC20(USDC).transfer(testUser, amountToTransfer);
        vm.stopPrank();
        
        // Start with the test user
        vm.startPrank(testUser);
        
        vm.stopPrank();
    }
    
    function testDeployment() public {
        assertEq(autopilot.owner(), owner, "Owner should be set correctly");
        assertTrue(autopilot.hasRole(autopilot.KEEPER_ROLE(), keeper), "Keeper role should be set");
        assertTrue(autopilot.hasRole(autopilot.PAUSER_ROLE(), owner), "Pauser role should be set");
    }
    
    function testDeposit() public {
        // Test user is already set up from setUp()
        
        // Approve the autopilot to spend USDC
        uint256 depositAmount = 1000 * 10**6; // 1,000 USDC
        IERC20(USDC).approve(address(autopilot), depositAmount);
        
        // Check initial balances
        uint256 initialBalance = IERC20(USDC).balanceOf(testUser);
        uint256 initialVaultBalance = autopilot.totalAssets();
        
        // Deposit USDC into the vault
        autopilot.deposit(depositAmount, testUser);
        
        // Check final balances
        uint256 finalBalance = IERC20(USDC).balanceOf(testUser);
        uint256 finalVaultBalance = autopilot.totalAssets();
        
        // Assert the deposit was successful
        assertEq(initialBalance - finalBalance, depositAmount, "USDC was not transferred from user");
        assertEq(finalVaultBalance - initialVaultBalance, depositAmount, "Vault did not receive the deposit");
        assertEq(autopilot.balanceOf(testUser), depositAmount, "User did not receive correct number of shares");
        
        // Test withdrawal
        uint256 shares = autopilot.balanceOf(testUser);
        autopilot.withdraw(depositAmount, testUser, testUser);
        
        // Check final balances after withdrawal
        uint256 finalWithdrawBalance = IERC20(USDC).balanceOf(testUser);
        assertApproxEqRel(
            finalWithdrawBalance,
            initialBalance,
            1e16, // 1% tolerance for any fees or rounding
            "User did not receive correct amount back after withdrawal"
        );
    }
}
