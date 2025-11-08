// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.21;

// // Fork testing for Mainnet
// // To run: forge test --match-path test/AaveAutopilotMainnetFork.t.sol -vvv --fork-url $MAINNET_RPC_URL

// import "forge-std/Test.sol";
// import "../src/AaveAutopilot.sol";

// // Mock ERC20 contract for testing
// contract MockERC20 {
//     string public name;
//     string public symbol;
//     uint8 public decimals;
    
//     mapping(address => uint256) public balanceOf;
//     mapping(address => mapping(address => uint256)) public allowance;
    
//     event Transfer(address indexed from, address indexed to, uint256 value);
//     event Approval(address indexed owner, address indexed spender, uint256 value);
    
//     constructor(string memory _name, string memory _symbol, uint8 _decimals) {
//         name = _name;
//         symbol = _symbol;
//         decimals = _decimals;
//     }
    
//     function mint(address to, uint256 amount) external {
//         balanceOf[to] += amount;
//         emit Transfer(address(0), to, amount);
//     }
    
//     function transfer(address to, uint256 amount) external returns (bool) {
//         require(balanceOf[msg.sender] >= amount, "Insufficient balance");
//         balanceOf[msg.sender] -= amount;
//         balanceOf[to] += amount;
//         emit Transfer(msg.sender, to, amount);
//         return true;
//     }
    
//     function approve(address spender, uint256 amount) external returns (bool) {
//         allowance[msg.sender][spender] = amount;
//         emit Approval(msg.sender, spender, amount);
//         return true;
//     }
    
//     function transferFrom(address from, address to, uint256 amount) external returns (bool) {
//         require(balanceOf[from] >= amount, "Insufficient balance");
//         require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        
//         balanceOf[from] -= amount;
//         balanceOf[to] += amount;
//         allowance[from][msg.sender] -= amount;
        
//         emit Transfer(from, to, amount);
//         return true;
//     }
// }

// // Mock Aave Pool contract for testing
// contract MockAavePool {
//     mapping(address => uint256) public supplyBalances;
    
//     function supply(address asset, uint256 amount, address onBehalfOf, uint16) external {
//         IERC20(asset).transferFrom(msg.sender, address(this), amount);
//         supplyBalances[onBehalfOf] += amount;
//     }
    
//     function withdraw(address asset, uint256 amount, address to) external returns (uint256) {
//         require(supplyBalances[msg.sender] >= amount, "Insufficient balance");
//         supplyBalances[msg.sender] -= amount;
//         IERC20(asset).transfer(to, amount);
//         return amount;
//     }
    
//     function getUserAccountData(address user) external pure returns (
//         uint256 totalCollateralBase,
//         uint256 totalDebtBase,
//         uint256 availableBorrowsBase,
//         uint256 currentLiquidationThreshold,
//         uint256 ltv,
//         uint256 healthFactor
//     ) {
//         // Return mock values for testing
//         return (1000e8, 500e8, 500e8, 8000, 7500, 2e18);
//     }
// }

// // Mock Price Feed contract for testing
// contract MockPriceFeed {
//     function latestAnswer() external pure returns (int256) {
//         return 2000e8; // $2000 per ETH
//     }
// }

// // Mock Keeper Registry contract for testing
// contract MockKeeperRegistry {
//     event KeeperRegistered(
//         string name,
//         bytes encryptedEmail,
//         address indexed upkeepContract,
//         uint32 gasLimit,
//         address adminAddress,
//         bytes checkData,
//         uint96 amount,
//         uint8 source,
//         address sender
//     );
    
//     function register(
//         string memory name,
//         bytes calldata encryptedEmail,
//         address upkeepContract,
//         uint32 gasLimit,
//         address adminAddress,
//         bytes calldata checkData,
//         uint96 amount,
//         uint8 source,
//         address sender
//     ) external {
//         emit KeeperRegistered(
//             name,
//             encryptedEmail,
//             upkeepContract,
//             gasLimit,
//             adminAddress,
//             checkData,
//             amount,
//             source,
//             sender
//         );
//     }
// }

// // Wrapper contract to expose internal functions for testing
// contract AaveAutopilotWrapper is AaveAutopilot {
//     constructor(
//         IERC20 _asset,
//         string memory _name,
//         string memory _symbol,
//         address _aavePool,
//         address _aaveDataProvider,
//         address _aToken,
//         address _ethUsdPriceFeed,
//         address _linkToken,
//         address _owner
//     ) AaveAutopilot(
//         _asset,
//         _name,
//         _symbol,
//         _aavePool,
//         _aaveDataProvider,
//         _aToken,
//         _ethUsdPriceFeed,
//         _linkToken,
//         _owner
//     ) {}
    
//     // Wrapper to expose _getHealthFactorView for testing
//     function getHealthFactorView(address user) external view returns (uint256) {
//         return _getHealthFactorView(user);
//     }
// }

// contract AaveAutopilotMainnetForkTest is Test {
//     // Test contract instances
//     AaveAutopilot public autopilot;
    
//     // Mainnet addresses - using test addresses that we'll mock
//     address public USDC;
//     address public AAVE_POOL;
//     address public AAVE_DATA_PROVIDER;
//     address public A_USDC;
//     address public ETH_USD_PRICE_FEED;
//     address public LINK_TOKEN;
//     address public KEEPER_REGISTRY;
    
//     // Test accounts
//     address public constant USER = address(0x1234);
//     address public constant OWNER = address(0x5678);
    
//     // Set up the test environment
//     function setUp() public {
//         // Create test contract addresses
//         USDC = address(new MockERC20("USD Coin", "USDC", 6));
//         AAVE_POOL = address(new MockAavePool());
//         AAVE_DATA_PROVIDER = address(0x123);  // Not used in tests yet
//         A_USDC = address(new MockERC20("Aave USDC", "aUSDC", 6));
//         ETH_USD_PRICE_FEED = address(new MockPriceFeed());
//         LINK_TOKEN = address(new MockERC20("Chainlink", "LINK", 18));
//         KEEPER_REGISTRY = address(new MockKeeperRegistry());
        
//         // Label the addresses for better test output
//         vm.label(USDC, "USDC");
//         vm.label(AAVE_POOL, "AAVE_POOL");
//         vm.label(AAVE_DATA_PROVIDER, "AAVE_DATA_PROVIDER");
//         vm.label(A_USDC, "A_USDC");
//         vm.label(ETH_USD_PRICE_FEED, "ETH_USD_PRICE_FEED");
//         vm.label(LINK_TOKEN, "LINK_TOKEN");
//         vm.label(KEEPER_REGISTRY, "KEEPER_REGISTRY");
        
//         // Deploy the AaveAutopilot contract
//         autopilot = new AaveAutopilot(
//             IERC20(USDC),
//             "Aave Autopilot",
//             "aAuto",
//             AAVE_POOL,
//             AAVE_DATA_PROVIDER,
//             A_USDC,
//             ETH_USD_PRICE_FEED,
//             LINK_TOKEN,
//             OWNER
//         );
        
//         // Set up initial balances for testing
//         MockERC20(USDC).mint(USER, 10000 * 10**6);  // 10,000 USDC
//         MockERC20(LINK_TOKEN).mint(USER, 100 * 10**18);  // 100 LINK
        
//         // Deploy the AaveAutopilotWrapper contract
//         vault = new AaveAutopilotWrapper(
//             IERC20(USDC),
//             "Aave Autopilot Vault",
//             "aAutoVault",
//             AAVE_POOL,
//             AAVE_DATA_PROVIDER,
//             A_USDC,
//             ETH_USD_PRICE_FEED,
//             LINK_TOKEN,
//             OWNER
//         );
        
//         // Approve the vault to spend user's USDC
//         MockERC20(USDC).approve(address(vault), type(uint256).max);
//     }
    
//     // Test parameters
//     uint256 constant DEPOSIT_AMOUNT = 1000 * 10**6; // 1000 USDC (6 decimals)
//     uint256 constant WITHDRAW_AMOUNT = 500 * 10**6;  // 500 USDC (6 decimals)
    
//     // Test functions
//     function testDeposit() public {
//         // Impersonate the user
//         vm.startPrank(USER);
        
//         // Approve the vault to spend user's USDC
//         MockERC20(USDC).approve(address(vault), DEPOSIT_AMOUNT);
        
//         // Deposit USDC into the vault
//         vault.deposit(DEPOSIT_AMOUNT, USER);
        
//         // Check that the user received the correct amount of shares
//         uint256 shares = vault.balanceOf(USER);
//         assertGt(shares, 0, "User should receive shares");
        
//         // Check that the vault has the correct USDC balance
//         uint256 vaultBalance = IERC20(USDC).balanceOf(address(vault));
//         assertEq(vaultBalance, DEPOSIT_AMOUNT, "Vault should have the deposited amount");
        
//         vm.stopPrank();
//     }
    
//     function testWithdraw() public {
//         // First, deposit some USDC
//         testDeposit();
        
//         // Get the initial share balance
//         uint256 initialShares = vault.balanceOf(USER);
        
//         // Impersonate the user
//         vm.startPrank(USER);
        
//         // Withdraw some USDC
//         vault.withdraw(WITHDRAW_AMOUNT, USER, USER);
        
//         // Check that the user's share balance decreased
//         uint256 newShares = vault.balanceOf(USER);
//         assertLt(newShares, initialShares, "User's shares should decrease after withdrawal");
        
//         // Check that the user received the USDC
//         uint256 userBalance = IERC20(USDC).balanceOf(USER);
//         assertGt(userBalance, 0, "User should receive USDC after withdrawal");
        
//         vm.stopPrank();
//     }
//         // Transfer USDC to test user
//         deal(USDC, USER, DEPOSIT_AMOUNT * 2);
//     }
    
//     function testDepositOnMainnetFork() public {
//         // Impersonate user
//         vm.startPrank(USER);
        
//         // Approve vault to spend USDC
//         usdc.approve(address(vault), DEPOSIT_AMOUNT);
        
//         // Deposit USDC
//         uint256 shares = vault.deposit(DEPOSIT_AMOUNT, USER);
        
//         // Verify deposit
//         assertGt(shares, 0, "Shares should be greater than 0");
//         assertEq(vault.balanceOf(USER), shares, "User should have correct share balance");
        
//         vm.stopPrank();
//     }
    
//     function testWithdrawOnMainnetFork() public {
//         // First deposit
//         testDepositOnMainnetFork();
        
//         // Impersonate user
//         vm.startPrank(USER);
        
//         // Withdraw USDC
//         uint256 assets = vault.redeem(WITHDRAW_AMOUNT, USER, USER);
        
//         // Verify withdrawal
//         assertGt(assets, 0, "Assets should be greater than 0");
//         assertEq(usdc.balanceOf(USER), DEPOSIT_AMOUNT - WITHDRAW_AMOUNT, "User should have correct USDC balance");
        
//         vm.stopPrank();
//     }
// }
