// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/AaveAutopilot.sol";
import "../src/interfaces/IAave.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Mock ERC20 token for testing
contract MockERC20 is IERC20 {
    string public name = "Mock USDC";
    string public symbol = "mUSDC";
    uint8 public decimals = 6;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        if (msg.sender != from) {
            require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
            allowance[from][msg.sender] -= amount;
        }
        
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        
        emit Transfer(from, to, amount);
        return true;
    }
}

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

// Mock ERC4626 contract for testing
contract MockERC4626 is ERC4626 {
    using SafeERC20 for IERC20;
    
    constructor(IERC20 asset) ERC4626(asset) ERC20("Mock ERC4626", "mERC4626") {}
    
    function totalAssets() public view override returns (uint256) {
        return IERC20(asset()).balanceOf(address(this));
    }
    
    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal override {
        // Skip the actual deposit logic since we're testing AaveAutopilot's implementation
        _mint(receiver, shares);
        emit Deposit(caller, receiver, assets, shares);
    }
    
    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal override {
        // Skip the actual withdraw logic since we're testing AaveAutopilot's implementation
        _burn(owner, shares);
        emit Withdraw(caller, receiver, owner, assets, shares);
    }
}

contract AaveAutopilotTest is Test {
    using stdStorage for StdStorage;

    AaveAutopilot public vault;
    MockERC20 public usdc;
    MockAggregatorV3 public ethUsdPriceFeed;
    
    // Test addresses
    address public alice = address(0x1);
    address public bob = address(0x2);
    address public keeper = address(0x3);
    address public owner = address(this); // Test contract is the owner
    
    // Aave mock addresses
    address public AAVE_POOL;
    address public AAVE_DATA_PROVIDER;
    address public A_TOKEN;
    
    // Test constants
    uint256 public constant INITIAL_ETH_PRICE = 2000 * 1e8; // $2000/ETH
    uint256 public constant USDC_DECIMALS = 6;
    uint256 public constant INITIAL_BALANCE = 10_000 * 10 ** USDC_DECIMALS;
    
    function setUp() public {
        // Deploy mock USDC
        usdc = new MockERC20();
        
        // Deploy mock Chainlink price feed
        ethUsdPriceFeed = new MockAggregatorV3(int256(INITIAL_ETH_PRICE));
        
        // Deploy mock Aave contracts
        AAVE_POOL = address(new MockAavePool());
        AAVE_DATA_PROVIDER = address(new MockAaveDataProvider());
        A_TOKEN = address(new MockAToken(address(usdc)));
        
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

        // Mint initial USDC to test accounts and vault
        usdc.mint(alice, INITIAL_BALANCE);
        usdc.mint(bob, INITIAL_BALANCE);
        usdc.mint(address(this), INITIAL_BALANCE * 10);
        
        // Approve vault to spend test contract's USDC
        usdc.approve(address(vault), type(uint256).max);
        
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
                IPoolDataProvider.getUserAccountData.selector,
                address(vault)
            ),
            abi.encode(0, 0, 0, 0, 0, healthFactor)
        );
    }
    
    // Test deposit functionality
    function testDeposit() public {
        uint256 amount = 1000 * 10 ** USDC_DECIMALS;
        
        // Mint USDC to Alice
        usdc.mint(alice, amount);
        
        // Approve AaveAutopilot to spend Alice's USDC
        vm.prank(alice);
        usdc.approve(address(vault), amount);
        
        // Mock the aToken balance after supply (1:1 for simplicity)
        uint256 aTokenAmount = amount;
        
        // Mock the Aave Pool supply call
        vm.mockCall(
            address(AAVE_POOL),
            abi.encodeWithSelector(IPool.supply.selector, address(usdc), amount, address(vault), uint16(0)),
            abi.encode()
        );
        
        // Mock the aToken transfer to simulate Aave minting aTokens
        vm.mockCall(
            address(A_TOKEN),
            abi.encodeWithSelector(IERC20.transfer.selector, alice, aTokenAmount),
            abi.encode(true)
        );
        
        // Mock the aToken balance of the vault
        vm.mockCall(
            address(A_TOKEN), 
            abi.encodeWithSelector(IERC20.balanceOf.selector, address(vault)),
            abi.encode(aTokenAmount)
        );
        
        // Mock the Aave Data Provider to return healthy position
        mockAaveData(2.5e18);
        
        // Mock the transferFrom call to return true when the vault transfers tokens from Alice
        vm.mockCall(
            address(usdc),
            abi.encodeWithSelector(IERC20.transferFrom.selector, alice, address(vault), amount),
            abi.encode(true)
        );
        
        // Mock the ERC4626 functions that will be called during deposit
        vm.mockCall(
            address(vault),
            abi.encodeWithSignature("totalAssets()"),
            abi.encode(0) // Initial total assets is 0
        );
        
        // Mock the previewDeposit call
        vm.mockCall(
            address(vault),
            abi.encodeWithSignature("previewDeposit(uint256)", amount),
            abi.encode(amount) // 1:1 shares for testing
        );
        
        // Mock the maxDeposit call
        vm.mockCall(
            address(vault),
            abi.encodeWithSignature("maxDeposit(address)", alice),
            abi.encode(type(uint256).max)
        );
        
        // Mock the convertToShares call
        vm.mockCall(
            address(vault),
            abi.encodeWithSignature("convertToShares(uint256,address)", amount, alice),
            abi.encode(amount) // 1:1 shares for testing
        );
        
        // Mock the totalSupply call
        vm.mockCall(
            address(vault),
            abi.encodeWithSignature("totalSupply()"),
            abi.encode(0) // Initial supply is 0
        );
        
        // Mock the _mint call
        vm.mockCall(
            address(vault),
            abi.encodeWithSignature("_mint(address,uint256)", alice, amount),
            abi.encode()
        );
        
        // Expect the Deposit event
        vm.expectEmit(true, true, true, true);
        emit IERC4626.Deposit(alice, alice, amount, amount);
        
        // Expect the custom Deposited event
        vm.expectEmit(true, true, true, true);
        emit AaveAutopilot.Deposited(alice, alice, amount, amount);
        
        // Perform the deposit
        vm.prank(alice);
        uint256 shares = vault.deposit(amount, alice);
        
        // Verify the deposit
        assertEq(shares, amount, "Shares should equal deposit amount");
    }
    
    // Test withdrawal functionality
    function testWithdraw() public {
        uint256 depositAmount = 1000e6; // 1000 USDC (6 decimals)
        uint256 withdrawAmount = 500e6;  // 500 USDC (half of deposit)
        
        // Mint USDC to Alice and approve vault
        usdc.mint(alice, depositAmount);
        vm.prank(alice);
        usdc.approve(address(vault), depositAmount);

        // Mock the aToken balance after supply (1:1 for simplicity)
        uint256 aTokenAmount = depositAmount;
        
        // Mock the Aave Pool supply call for deposit
        vm.mockCall(
            address(AAVE_POOL),
            abi.encodeWithSelector(IPool.supply.selector, address(usdc), depositAmount, address(vault), uint16(0)),
            abi.encode()
        );
        
        // Mock the aToken transfer to simulate Aave minting aTokens
        vm.mockCall(
            address(A_TOKEN),
            abi.encodeWithSelector(IERC20.transfer.selector, alice, aTokenAmount),
            abi.encode(true)
        );
        
        // Mock the aToken balance of the vault
        vm.mockCall(
            address(A_TOKEN), 
            abi.encodeWithSelector(IERC20.balanceOf.selector, address(vault)),
            abi.encode(aTokenAmount)
        );
        
        // Mock the totalAssets call to return the aToken balance
        vm.mockCall(
            address(vault),
            abi.encodeWithSignature("totalAssets()"),
            abi.encode(aTokenAmount)
        );
        
        // Mock the convertToShares call to return 1:1 for testing
        vm.mockCall(
            address(vault),
            abi.encodeWithSignature("convertToShares(uint256,address)", depositAmount, alice),
            abi.encode(depositAmount)
        );
        
        // Mock the previewDeposit call to return 1:1 for testing
        vm.mockCall(
            address(vault),
            abi.encodeWithSignature("previewDeposit(uint256)", depositAmount),
            abi.encode(depositAmount)
        );
        
        // Mock the maxDeposit call to return a high value for testing
        vm.mockCall(
            address(vault),
            abi.encodeWithSignature("maxDeposit(address)", alice),
            abi.encode(type(uint256).max)
        );
        
        // Mock the totalSupply call to return 0 for initial deposit
        vm.mockCall(
            address(vault),
            abi.encodeWithSignature("totalSupply()"),
            abi.encode(0)
        );
        
        // Mock the balanceOf call for the user
        vm.mockCall(
            address(vault),
            abi.encodeWithSignature("balanceOf(address)", alice),
            abi.encode(depositAmount)
        );

        // Mock the convertToAssets call for the share calculation
        vm.mockCall(
            address(vault),
            abi.encodeWithSignature("convertToAssets(uint256,address)", depositAmount, alice),
            abi.encode(depositAmount)
        );
        
        // Mock the previewWithdraw call
        vm.mockCall(
            address(vault),
            abi.encodeWithSignature("previewWithdraw(uint256,address)", withdrawAmount, alice),
            abi.encode(withdrawAmount)
        );
        
        // Mock the maxWithdraw call to return the full amount
        vm.mockCall(
            address(vault),
            abi.encodeWithSignature("maxWithdraw(address)", alice),
            abi.encode(depositAmount)
        );
        
        // Mock the Aave Pool withdraw call
        vm.mockCall(
            address(AAVE_POOL),
            abi.encodeWithSelector(IPool.withdraw.selector, address(usdc), withdrawAmount, alice),
            abi.encode(withdrawAmount)
        );
        
        // Mock the token transfer to the receiver
        vm.mockCall(
            address(usdc),
            abi.encodeWithSelector(IERC20.transfer.selector, alice, withdrawAmount),
            abi.encode(true)
        );
        
        // Mock the Aave Data Provider to return healthy position
        mockAaveData(2.5e18);
        
        // Record initial balance
        uint256 initialUsdcBalance = usdc.balanceOf(alice);
        
        // Expect the Withdraw event
        vm.expectEmit(true, true, true, true);
        emit IERC4626.Withdraw(alice, alice, alice, withdrawAmount, withdrawAmount);
        
        // Perform the withdrawal
        vm.prank(alice);
        uint256 withdrawn = vault.withdraw(withdrawAmount, alice, alice);
        
        // Verify the withdrawal
        assertEq(withdrawn, withdrawAmount, "Withdrawn amount should match requested amount");
        
        // Test withdrawal with insufficient balance
        vm.mockCall(
            address(vault),
            abi.encodeWithSignature("balanceOf(address)", alice),
            abi.encode(0)
        );
        
        vm.expectRevert("ERC20: burn amount exceeds balance");
        vm.prank(alice);
        vault.withdraw(1, alice, alice);
        
        // Test withdrawal with unhealthy position
        mockAaveData(1.04e18); // Below MIN_HEALTH_FACTOR
        
        vm.expectRevert("Withdrawal would make position unsafe");
        vm.prank(alice);
        vault.withdraw(1, alice, alice);
    }
    
    // Test health factor monitoring and rebalancing
    function testHealthFactorCheck() public {
        uint256 depositAmount = 1000 * 10 ** USDC_DECIMALS;
        
        // Mock healthy position
        mockAaveData(2.5e18);
        
        // Mock deposit setup
        vm.mockCall(
            address(usdc),
            abi.encodeWithSelector(IERC20.transferFrom.selector, alice, address(vault), depositAmount),
            abi.encode(true)
        );
        
        // Mock ERC4626 functions for deposit
        vm.mockCall(
            address(vault),
            abi.encodeWithSignature("totalAssets()"),
            abi.encode(0)
        );
        
        vm.mockCall(
            address(vault),
            abi.encodeWithSignature("previewDeposit(uint256)", depositAmount),
            abi.encode(depositAmount)
        );
        
        vm.mockCall(
            address(vault),
            abi.encodeWithSignature("maxDeposit(address)", alice),
            abi.encode(type(uint256).max)
        );
        
        vm.mockCall(
            address(vault),
            abi.encodeWithSignature("convertToShares(uint256,address)", depositAmount, alice),
            abi.encode(depositAmount)
        );
        
        vm.mockCall(
            address(vault),
            abi.encodeWithSignature("totalSupply()"),
            abi.encode(0)
        );
        
        vm.mockCall(
            address(vault),
            abi.encodeWithSignature("_mint(address,uint256)", alice, depositAmount),
            abi.encode()
        );
        
        vm.startPrank(alice);
        usdc.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, alice);
        
        // Check health factor
        uint256 healthFactor = vault.getCurrentHealthFactor();
        assertEq(healthFactor, 2.5e18, "Incorrect health factor");
        
        // Test checkAndAdjustPosition with healthy position (should do nothing)
        mockAaveData(2.5e18);
        vault.checkAndAdjustPosition();
        
        // Test with unhealthy position
        mockAaveData(1.04e18); // Below MIN_HEALTH_FACTOR
        
        // Mock the rebalance call
        vm.mockCall(
            address(AAVE_POOL),
            abi.encodeWithSelector(IPool.withdraw.selector, address(usdc), type(uint256).max, address(vault)),
            abi.encode(depositAmount)
        );
        
        // Expect the PositionAdjusted event
        vm.expectEmit(true, true, true, true);
        emit AaveAutopilot.PositionAdjusted(1.04e18, 2.5e18);
        
        // Should trigger rebalance
        vault.checkAndAdjustPosition();
        
        // Test cooldown
        mockAaveData(1.04e18);
        vault.checkAndAdjustPosition(); // Should not trigger another rebalance due to cooldown
        
        // Fast forward past cooldown
        vm.warp(block.timestamp + 2 hours);
        
        // Should trigger rebalance again after cooldown
        vm.expectEmit(true, true, true, true);
        emit AaveAutopilot.PositionAdjusted(1.04e18, 2.5e18);
        vault.checkAndAdjustPosition();
        
        vm.stopPrank();
    }
    
    // Test Keeper compatibility
    function testKeeperCheckUpkeep() public {
        // Mock unhealthy position
        mockAaveData(1.09e18); // Below KEEPER_THRESHOLD (1.1)
        
        // Fast forward time to pass cooldown
        vm.warp(block.timestamp + 2 hours);
        
        // Check if upkeep is needed
        (bool upkeepNeeded, ) = vault.checkUpkeep("");
        assertTrue(upkeepNeeded, "Upkeep should be needed when health factor is below threshold");
        
        // Mock the rebalance call
        vm.mockCall(
            address(AAVE_POOL),
            abi.encodeWithSelector(IPool.withdraw.selector, address(usdc), type(uint256).max, address(vault)),
            abi.encode(1000e6) // Mock withdraw amount
        );
        
        // Expect the PositionAdjusted event
        vm.expectEmit(true, true, true, true);
        emit AaveAutopilot.PositionAdjusted(1.09e18, 2.5e18);
        
        // Perform upkeep
        vm.prank(keeper);
        (bool success, ) = address(vault).call(
            abi.encodeWithSelector(
                vault.performUpkeep.selector,
                abi.encode(1.09e18) // Current health factor
            )
        );
        
        assertTrue(success, "Perform upkeep failed");
        
        // Test when cooldown hasn't passed
        mockAaveData(1.09e18);
        (upkeepNeeded, ) = vault.checkUpkeep("");
        assertFalse(upkeepNeeded, "Upkeep should not be needed during cooldown");
        
        // Test when health factor is above threshold
        mockAaveData(1.2e18); // Above KEEPER_THRESHOLD
        (upkeepNeeded, ) = vault.checkUpkeep("");
        assertFalse(upkeepNeeded, "Upkeep should not be needed when health factor is above threshold");
    }
    
    // Test pausing functionality
    function testPause() public {
        uint256 amount = 100e6; // 100 USDC

        // Mint USDC to Alice
        usdc.mint(alice, amount);
        
        // Approve AaveAutopilot to spend Alice's USDC
        vm.prank(alice);
        usdc.approve(address(vault), amount);

        // Pause as owner
        vm.prank(owner);
        vault.pause();

        // Try to deposit while paused (should fail)
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        vault.deposit(amount, alice);

        // Unpause
        vm.prank(owner);
        vault.unpause();

        // Mock the aToken balance after supply (1:1 for simplicity)
        uint256 aTokenAmount = amount;
        
        // Mock the Aave Pool supply call
        vm.mockCall(
            address(AAVE_POOL),
            abi.encodeWithSelector(IPool.supply.selector, address(usdc), amount, address(vault), uint16(0)),
            abi.encode()
        );
        
        // Mock the aToken transfer to simulate Aave minting aTokens
        vm.mockCall(
            address(A_TOKEN),
            abi.encodeWithSelector(IERC20.transfer.selector, alice, aTokenAmount),
            abi.encode(true)
        );
        
        // Mock the aToken balance of the vault
        vm.mockCall(
            address(A_TOKEN), 
            abi.encodeWithSelector(IERC20.balanceOf.selector, address(vault)),
            abi.encode(aTokenAmount)
        );
        
        // Mock the totalAssets call to return the aToken balance
        vm.mockCall(
            address(vault),
            abi.encodeWithSignature("totalAssets()"),
            abi.encode(aTokenAmount)
        );
        
        // Mock the convertToShares call to return 1:1 for testing
        vm.mockCall(
            address(vault),
            abi.encodeWithSignature("convertToShares(uint256,address)", amount, alice),
            abi.encode(amount)
        );
        
        // Mock the previewDeposit call to return 1:1 for testing
        vm.mockCall(
            address(vault),
            abi.encodeWithSignature("previewDeposit(uint256)", amount),
            abi.encode(amount)
        );
        
        // Mock the maxDeposit call to return a high value for testing
        vm.mockCall(
            address(vault),
            abi.encodeWithSignature("maxDeposit(address)", alice),
            abi.encode(type(uint256).max)
        );
        
        // Mock the totalSupply call to return 0 for initial deposit
        vm.mockCall(
            address(vault),
            abi.encodeWithSignature("totalSupply()"),
            abi.encode(0)
        );
        
        // Mock the balanceOf call for the user
        vm.mockCall(
            address(vault),
            abi.encodeWithSignature("balanceOf(address)", alice),
            abi.encode(0)
        );
        
        // Mock the convertToAssets call for the share calculation
        vm.mockCall(
            address(vault),
            abi.encodeWithSignature("convertToAssets(uint256,address)", amount, alice),
            abi.encode(amount)
        );
        
        // Mock the previewWithdraw call
        vm.mockCall(
            address(vault),
            abi.encodeWithSignature("previewWithdraw(uint256,address)", amount, alice),
            abi.encode(amount)
        );
        
        // Mock the maxWithdraw call
        vm.mockCall(
            address(vault),
            abi.encodeWithSignature("maxWithdraw(address)", alice),
            abi.encode(amount)
        );
        
        // Mock the Aave Data Provider to return healthy position
        mockAaveData(2.5e18);
        
        // Should work after unpausing
        vm.prank(alice);
        uint256 shares = vault.deposit(amount, alice);

        // Verify the deposit after unpausing
        assertEq(shares, amount, "Shares should equal deposit amount after unpausing");
    }
    
    // Test reentrancy
    function testReentrancy() public {
        uint256 amount = 1000 * 10 ** USDC_DECIMALS;
        
        // Deploy malicious contract that tries to reenter
        MaliciousContract malicious = new MaliciousContract(address(vault), address(usdc));

        // Fund the malicious contract
        usdc.mint(address(malicious), amount);

        // Mock the aToken balance for the vault
        vm.mockCall(
            address(A_TOKEN),
            abi.encodeWithSelector(IERC20.balanceOf.selector, address(vault)),
            abi.encode(amount)
        );

        // Mock the Aave Pool supply call for the initial deposit
        vm.mockCall(
            address(AAVE_POOL),
            abi.encodeWithSelector(IPool.supply.selector, address(usdc), 100, address(vault), uint16(0)),
            abi.encode()
        );

        // Mock the aToken transfer for the initial deposit
        vm.mockCall(
            address(A_TOKEN),
            abi.encodeWithSelector(IERC20.transfer.selector, address(malicious), 100),
            abi.encode(true)
        );

        // Mock the convertToShares call to return 1:1 for testing
        vm.mockCall(
            address(vault),
            abi.encodeWithSignature("convertToShares(uint256,address)", 100, address(malicious)),
            abi.encode(100)
        );
        
        // Mock the previewDeposit call to return 1:1 for testing
        vm.mockCall(
            address(vault),
            abi.encodeWithSignature("previewDeposit(uint256)", 100),
            abi.encode(100)
        );
        
        // Mock the maxDeposit call to return a high value for testing
        vm.mockCall(
            address(vault),
            abi.encodeWithSignature("maxDeposit(address)", address(malicious)),
            abi.encode(type(uint256).max)
        );
        
        // Mock the totalSupply call to return 0 for initial deposit
        vm.mockCall(
            address(vault),
            abi.encodeWithSignature("totalSupply()"),
            abi.encode(0)
        );

        // Mock the balanceOf call for the malicious contract
        vm.mockCall(
            address(vault),
            abi.encodeWithSignature("balanceOf(address)", address(malicious)),
            abi.encode(100)
        );

        // Mock the convertToAssets call for the share calculation
        vm.mockCall(
            address(vault),
            abi.encodeWithSignature("convertToAssets(uint256,address)", 100, address(malicious)),
            abi.encode(100)
        );
        
        // Mock the previewWithdraw call
        vm.mockCall(
            address(vault),
            abi.encodeWithSignature("previewWithdraw(uint256,address)", 100, address(malicious)),
            abi.encode(100)
        );
        
        // Mock the maxWithdraw call
        vm.mockCall(
            address(vault),
            abi.encodeWithSignature("maxWithdraw(address)", address(malicious)),
            abi.encode(100)
        );

        // Mock the transferFrom call to trigger the reentrancy
        // This will be called when the vault tries to transfer USDC from the malicious contract
        vm.mockCall(
            address(usdc),
            abi.encodeWithSelector(IERC20.transferFrom.selector, address(malicious), address(vault), 100),
            abi.encode(true)
        );

        // Mock the safeTransfer call that would be made during the reentrant call
        // This will trigger the onERC20Received callback in the malicious contract
        vm.mockCall(
            address(usdc),
            abi.encodeWithSelector(IERC20.transfer.selector, address(malicious), 100),
            abi.encode(true)
        );

        // Mock the Aave Pool supply call for the reentrant deposit
        // This will be called during the reentrant call
        vm.mockCall(
            address(AAVE_POOL),
            abi.encodeWithSelector(IPool.supply.selector, address(usdc), 50, address(vault), uint16(0)),
            abi.encode()
        );

        // Mock the aToken transfer for the reentrant deposit
        vm.mockCall(
            address(A_TOKEN),
            abi.encodeWithSelector(IERC20.transfer.selector, address(malicious), 50),
            abi.encode(true)
        );

        // Mock the _mint call for the reentrant deposit
        // This is where the reentrancy will be detected
        vm.mockCall(
            address(vault),
            abi.encodeWithSignature("_mint(address,uint256)", address(malicious), 50),
            abi.encode()
        );

        // Expect reentrancy protection to trigger
        // The reentrancy guard should prevent the second deposit from completing
        vm.expectRevert("ReentrancyGuard: reentrant call");
        
        // Execute the attack
        malicious.attack();

        // Verify the malicious contract's balance didn't change
        assertEq(usdc.balanceOf(address(malicious)), amount, "Malicious contract's balance should not change");
    }
}

// Mock Aave Pool
contract MockAavePool {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16) external {
        // In a real test, we would update the user's aToken balance here
        IERC20(asset).transferFrom(msg.sender, address(this), amount);
    }
    
    function withdraw(address asset, uint256 amount, address to) external returns (uint256) {
        // In a real test, we would check the user's aToken balance here
        IERC20(asset).transfer(to, amount);
        return amount;
    }
    
    function repay(address asset, uint256 amount, uint256, address) external returns (uint256) {
        IERC20(asset).transferFrom(msg.sender, address(this), amount);
        return amount;
    }
    
    function getUserAccountData(address) external pure returns (uint256, uint256, uint256, uint256, uint256, uint256) {
        // Return mock data
        return (1e18, 0.5e18, 1e18, 8000, 7500, 2e18);
    }
}

// Mock Aave Data Provider
contract MockAaveDataProvider {
    function getUserAccountData(address) external pure returns (uint256, uint256, uint256, uint256, uint256, uint256) {
        // Return mock data
        return (1e18, 0.5e18, 1e18, 8000, 7500, 2e18);
    }
}

// Mock Aave aToken
contract MockAToken is IERC20 {
    string public name = "Aave Interest Bearing USDC";
    string public symbol = "aUSDC";
    uint8 public decimals = 6;
    uint256 public totalSupply;
    address public immutable UNDERLYING_ASSET_ADDRESS;
    
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    constructor(address underlyingAsset) {
        UNDERLYING_ASSET_ADDRESS = underlyingAsset;
    }
    
    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }
    
    function burn(address from, uint256 amount) external {
        require(balanceOf[from] >= amount, "Insufficient balance");
        balanceOf[from] -= amount;
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }
    
    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }
    
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        if (msg.sender != from) {
            require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
            allowance[from][msg.sender] -= amount;
        }
        
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        
        emit Transfer(from, to, amount);
        return true;
    }
    
    function POOL() external view returns (address) {
        return msg.sender; // For testing
    }
    
    function getIncentivesController() external pure returns (address) {
        return address(0);
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
    
    // Fallback function to receive ETH
    receive() external payable {}
    
    // This function will be called during the reentrancy
    function onERC20Received(
        address,
        uint256,
        bytes calldata
    ) external returns (bytes4) {
        if (!attacking && msg.sender == address(vault)) {
            attacking = true;
            // Try to reenter by calling deposit again
            // This will trigger the reentrancy guard
            vault.deposit(50, address(this));
        }
        return this.onERC20Received.selector;
    }
    
    function attack() external {
        // Approve vault to spend tokens
        token.approve(address(vault), type(uint256).max);
        
        // Start the attack by making a deposit
        vault.deposit(100, address(this));
    }
    
    // Helper function to check if the contract has a balance of a token
    function hasBalance(address tokenAddress) external view returns (bool) {
        return IERC20(tokenAddress).balanceOf(address(this)) > 0;
    }
}
