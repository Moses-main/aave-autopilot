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
        address _owner
    ) AaveAutopilot(
        _asset,
        _name,
        _symbol,
        _aavePool,
        _aaveDataProvider,
        _aToken,
        _ethUsdPriceFeed,
        _owner
    ) {}
    
    // Wrapper to expose _getHealthFactorView for testing
    function getHealthFactorView(address user) external view returns (uint256) {
        return _getHealthFactorView(user);
    }
}

contract AaveAutopilotSepoliaTest is Test {
    // Sepolia addresses (as strings to avoid checksum issues)
    string constant USDC_STR = "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238"; // Sepolia USDC
    string constant AAVE_POOL_STR = "0x6Ae43d3271fF6888e7Fc43Fd7321a503fF738951"; // Aave V3 Pool
    string constant AAVE_DATA_PROVIDER_STR = "0x7B4EB56E7CD4b454BA8fF71E4518426369a138a3"; // Aave Data Provider
    string constant A_USDC_STR = "0x16dA4541aD1807f4443d92D26044C1147406EB80"; // aUSDC Token
    string constant ETH_USD_PRICE_FEED_STR = "0x694AA1769357215DE4FAC081bf1f309aDC325306"; // Chainlink ETH/USD
    string constant KEEPER_REGISTRY_STR = "0xE16Df59B403e9B01F5f28a3b09a4e71c9F3509dF"; // Chainlink Keeper Registry
    string constant LINK_TOKEN_STR = "0x779877A7B0D9E8603169DdbD7836e478b4624789"; // LINK Token on Sepolia
    
    // Address variables
    address USDC;
    address AAVE_POOL;
    address AAVE_DATA_PROVIDER;
    address A_USDC;
    address ETH_USD_PRICE_FEED;
    address KEEPER_REGISTRY;
    address LINK_TOKEN;
    
    // Test accounts
    address deployer = makeAddr("deployer");
    address user1 = makeAddr("user1");
    address keeper = makeAddr("keeper");
    
    // Contract instances
    AaveAutopilotWrapper public autopilot;
    
    // Fork setup
    uint256 sepoliaFork;
    string SEPOLIA_RPC_URL = vm.envString("SEPOLIA_RPC_URL");
    
    function setUp() public {
        // Parse all addresses from strings
        USDC = vm.parseAddress(USDC_STR);
        AAVE_POOL = vm.parseAddress(AAVE_POOL_STR);
        AAVE_DATA_PROVIDER = vm.parseAddress(AAVE_DATA_PROVIDER_STR);
        A_USDC = vm.parseAddress(A_USDC_STR);
        ETH_USD_PRICE_FEED = vm.parseAddress(ETH_USD_PRICE_FEED_STR);
        KEEPER_REGISTRY = vm.parseAddress(KEEPER_REGISTRY_STR);
        LINK_TOKEN = vm.parseAddress(LINK_TOKEN_STR);
        
        // Fork Sepolia at a specific block
        uint256 forkBlock = 5_000_000; // Adjust to a recent block number
        string memory rpcUrl = vm.envString("SEPOLIA_RPC_URL");
        uint256 forkId = vm.createFork(rpcUrl, forkBlock);
        vm.selectFork(forkId);
        
        // Deploy the contract
        vm.startPrank(deployer);
        // Deploy AaveAutopilotWrapper
        autopilot = new AaveAutopilotWrapper(
            IERC20(USDC),
            "Aave Autopilot USDC",
            "apUSDC",
            AAVE_POOL, // Pass address directly, not IPool
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
    
    function testDeployment() public view {
        assertEq(autopilot.name(), "Aave Autopilot USDC");
        assertEq(autopilot.symbol(), "apUSDC");
        assertEq(autopilot.owner(), deployer);
    }
    
    function testDepositAndWithdraw() public {
        // Use the test contract itself as the USDC holder for testing
        address usdcWhale = address(this);
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
    
    function testHealthFactorCalculation() public {
        // Test health factor calculation
        uint256 healthFactor = autopilot.getHealthFactorView(user1);
        assertGt(healthFactor, 0, "Health factor should be greater than 0");
    }
}
