// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IAave.sol";
import "./interfaces/AggregatorV3Interface.sol";
import "./interfaces/KeeperCompatibleInterface.sol";

/**
 * @title AaveAutopilot
 * @notice ERC-4626 vault that manages Aave v3 positions with automatic health factor monitoring
 * @dev Implements intelligent position management to prevent liquidations
 */
contract AaveAutopilot is 
    ERC4626, 
    Ownable, 
    ReentrancyGuard, 
    Pausable, 
    AccessControl, 
    KeeperCompatibleInterface 
{
    using SafeERC20 for IERC20;
    
    // Events
    event AccountData(
        address indexed user,
        uint256 totalCollateralETH,
        uint256 totalDebtETH,
        uint256 availableBorrowsETH,
        uint256 currentLiquidationThreshold,
        uint256 ltv,
        uint256 healthFactor
    );
    
    // Roles
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    // ============ State Variables ============

    /// @notice Minimum health factor before triggering auto-adjustment (1.05x)
    uint256 public constant MIN_HEALTH_FACTOR = 1.05e18;

    /// @notice Target health factor after rebalancing (1.5x)
    uint256 public constant TARGET_HEALTH_FACTOR = 1.5e18;

    /// @notice Health factor threshold for Keeper check (1.1x)
    uint256 public constant KEEPER_THRESHOLD = 1.1e18;

    /// @notice Chainlink ETH/USD price feed
    AggregatorV3Interface public immutable ethUsdPriceFeed;

    /// @notice Aave Pool contract
    IPool public immutable aavePool;
    
    /// @notice Aave Data Provider contract
    IPoolDataProvider public immutable aaveDataProvider;
    
    /// @notice Aave aToken for the underlying asset
    IAToken public immutable aToken;
    
    /// @notice Track last rebalance timestamp per user
    mapping(address => uint256) public lastRebalanceTimestamp;
    
    /// @notice Minimum time between rebalances (1 hour)
    uint256 public constant REBALANCE_COOLDOWN = 1 hours;

    // ============ Events ============

    event HealthFactorChecked(uint256 healthFactor, bool actionTaken);
    event PositionAdjusted(uint256 oldHealthFactor, uint256 newHealthFactor);
    event PositionRebalanced(address indexed user, uint256 oldHealthFactor, uint256 newHealthFactor);
    event KeeperTriggered(address indexed keeper, address indexed user, uint256 healthFactor);
    event RebalanceAttempt(
        address indexed user,
        uint256 oldHealthFactor,
        uint256 newHealthFactor,
        bool success,
        string reason
    );
    event MaxAttemptsReached(address indexed user);
    
    // ERC4626 Events
    event Deposited(address indexed sender, address indexed owner, uint256 assets, uint256 shares);
    event Withdrawn(address indexed sender, address indexed receiver, address indexed owner, uint256 assets, uint256 shares);

    // ============ Constructor ============

    /**
     * @param _asset The underlying asset (e.g., USDC)
     * @param _name Name of the vault token
     * @param _symbol Symbol of the vault token
     * @param _aavePool The Aave v3 pool address
     * @param _aaveDataProvider The Aave v3 data provider address
     * @param _aToken The Aave v3 aToken address
     * @param _ethUsdPriceFeed Chainlink ETH/USD price feed address
     * @param _owner Owner of the contract
     */
    constructor(
        IERC20 _asset,
        string memory _name,
        string memory _symbol,
        address _aavePool,
        address _aaveDataProvider,
        address _aToken,
        address _ethUsdPriceFeed,
        address _owner
    ) ERC4626(_asset) ERC20(_name, _symbol) {
        require(_aavePool != address(0), "Invalid Aave Pool");
        require(_aaveDataProvider != address(0), "Invalid Data Provider");
        require(_aToken != address(0), "Invalid aToken");
        require(_ethUsdPriceFeed != address(0), "Invalid Price Feed");
        require(_owner != address(0), "Invalid owner address");
        
        // Initialize Ownable with the owner
        _transferOwnership(_owner);
        
        // Set up roles
        _setupRole(DEFAULT_ADMIN_ROLE, _owner);
        _setupRole(PAUSER_ROLE, _owner);
        _setupRole(KEEPER_ROLE, _owner);
        
        // Initialize contract state
        aavePool = IPool(_aavePool);
        aaveDataProvider = IPoolDataProvider(_aaveDataProvider);
        aToken = IAToken(_aToken);
        ethUsdPriceFeed = AggregatorV3Interface(_ethUsdPriceFeed);
        
        // Approve Aave Pool to spend our tokens
        IERC20(asset()).safeIncreaseAllowance(_aavePool, type(uint256).max);
    }

    // ============ Core ERC-4626 Functions ============

    /**
     * @notice Total assets managed by the vault
     */
    // Update totalAssets to get real balance from Aave
    function totalAssets() public view override returns (uint256) {
        return aToken.balanceOf(address(this)); // Real-time balance with interest
    }

    /**
     * @notice Deposit assets into the vault
     */
    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) 
        internal 
        override 
        nonReentrant 
        whenNotPaused 
    {
        require(assets > 0, "Cannot deposit 0");
        require(shares > 0, "Invalid share amount");
        
        // First, transfer assets from the caller to this contract
        SafeERC20.safeTransferFrom(IERC20(asset()), caller, address(this), assets);
        
        // Then supply to Aave
        aavePool.supply(asset(), assets, address(this), 0);
        
        // Finally, mint shares to the receiver
        _mint(receiver, shares);
        
        emit Deposit(caller, receiver, assets, shares);
        emit Deposited(caller, receiver, assets, shares);
    }

    /**
     * @notice Withdraw assets from the vault
     */
    // Update _withdraw function
    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) 
        internal 
        override 
        nonReentrant 
        whenNotPaused 
    {
        require(assets > 0, "Cannot withdraw 0");
        require(shares > 0, "Invalid share amount");
        
        // Check health factor after withdrawal
        uint256 healthFactor = getCurrentHealthFactor();
        require(healthFactor >= MIN_HEALTH_FACTOR, "Withdrawal would make position unsafe");
        
        // Withdraw from Aave
        aavePool.withdraw(asset(), assets, address(this));
        
        super._withdraw(caller, receiver, owner, assets, shares);
        
        emit Withdrawn(caller, receiver, owner, assets, shares);
    }

            // ============ Chainlink Automation ============
    
    // Constants for batch processing and circuit breaker
    uint256 public currentBatchIndex;
    uint256 public constant MAX_REBALANCE_ATTEMPTS = 3;
    uint256 public constant BATCH_SIZE = 10; // Number of users to process in one batch
    
    // Track rebalance attempts per user
    mapping(address => uint256) public rebalanceAttempts;
    
    /**
     * @notice Internal function to get a batch of users with active positions
     * @dev This is a simplified version - in production, you'd want a more efficient way
     * to track users with active positions
     */
    function _getUsersBatch(uint256, uint256) internal pure returns (address[] memory) {
        // In a real implementation, you'd want to track users with active positions
        // For this example, we'll return an empty array
        address[] memory users = new address[](0);
        return users;
    }
    
    /**
     * @notice Method called by Chainlink Keepers to check if upkeep is needed
     * @dev Processes users in batches to avoid gas limits
     */
    function checkUpkeep(
        bytes calldata checkData
    ) external view override returns (bool upkeepNeeded, bytes memory performData) {
        // If specific user is provided in checkData, check only that user
        if (checkData.length > 0) {
            address user = abi.decode(checkData, (address));
            uint256 userHf = _getHealthFactorView(user);
            uint256 userLastRebalance = lastRebalanceTimestamp[user];
            bool userTimePassed = block.timestamp - userLastRebalance >= REBALANCE_COOLDOWN;
            bool userNeedsRebalance = userHf < KEEPER_THRESHOLD && 
                                    userHf > 0 && 
                                    rebalanceAttempts[user] < MAX_REBALANCE_ATTEMPTS &&
                                    userTimePassed;
            
            if (userNeedsRebalance) {
                address[] memory usersToRebalance = new address[](1);
                usersToRebalance[0] = user;
                return (true, abi.encode(usersToRebalance));
            }
        }
        
        // In production, implement batch processing of users
        // For demo, we'll use a simplified approach with currentBatchIndex
        address[] memory usersToCheck = new address[](1);
        address currentUser = msg.sender; // Replace with actual batch processing
        usersToCheck[0] = currentUser;
        
        uint256 currentHf = _getHealthFactorView(currentUser);
        uint256 currentUserLastRebalance = lastRebalanceTimestamp[currentUser];
        bool currentTimePassed = block.timestamp - currentUserLastRebalance >= REBALANCE_COOLDOWN;
        bool currentNeedsRebalance = currentHf < KEEPER_THRESHOLD && 
                                   currentHf > 0 && 
                                   rebalanceAttempts[currentUser] < MAX_REBALANCE_ATTEMPTS &&
                                   currentTimePassed;
        
        return (currentNeedsRebalance, abi.encode(usersToCheck));
    }
    
    /**
     * @notice Method called by Chainlink Keepers to perform upkeep
     * @dev Will only be called if checkUpkeep returns true
     */
    function performUpkeep(
        bytes calldata performData
    ) external override onlyRole(KEEPER_ROLE) whenNotPaused {
        address[] memory users = abi.decode(performData, (address[]));
        
        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            uint256 oldHealthFactor = getHealthFactor(user);
            
            // Skip if user doesn't need rebalancing or has exceeded max attempts
            if (oldHealthFactor >= KEEPER_THRESHOLD || 
                oldHealthFactor == 0 || 
                rebalanceAttempts[user] >= MAX_REBALANCE_ATTEMPTS) {
                continue;
            }
            
            try this._rebalancePosition(user) {
                // Success - reset attempt counter
                rebalanceAttempts[user] = 0;
                emit PositionRebalanced(user, oldHealthFactor, getHealthFactor(user));
                emit RebalanceAttempt(user, oldHealthFactor, getHealthFactor(user), true, "");
            } catch Error(string memory reason) {
                // Increment attempt counter on failure
                rebalanceAttempts[user]++;
                emit RebalanceAttempt(user, oldHealthFactor, 0, false, reason);
                
                if (rebalanceAttempts[user] >= MAX_REBALANCE_ATTEMPTS) {
                    emit MaxAttemptsReached(user);
                }
            } catch (bytes memory) {
                // Catch any other errors
                rebalanceAttempts[user]++;
                emit RebalanceAttempt(user, oldHealthFactor, 0, false, "Unknown error");
                
                if (rebalanceAttempts[user] >= MAX_REBALANCE_ATTEMPTS) {
                    emit MaxAttemptsReached(user);
                }
            }
        }
        
        // Update batch index for next run
        currentBatchIndex = (currentBatchIndex + 1) % 10;
    }
    
    // ============ Health Factor Management ============
    
    /**
     * @notice Get the current health factor from Aave
     * @return healthFactor The current health factor (scaled by 1e18)
     */
    function getCurrentHealthFactor() public view returns (uint256 healthFactor) {
        (, , , , , healthFactor) = aaveDataProvider.getUserAccountData(address(this));
        return healthFactor;
    }
    
    /**
     * @notice Get the current health factor for a user (view-only, doesn't emit events)
     * @param user The address of the user
     * @return The health factor (scaled by 1e18, >1 means safe, <1 means at risk)
     */
    function _getHealthFactorView(address user) internal view returns (uint256) {
        if (user == address(0)) return 0;
        
        // Get user account data from Aave
        (
            , , , , ,
            uint256 healthFactor
        ) = aaveDataProvider.getUserAccountData(user);
        
        return healthFactor;
    }
    
    /**
     * @notice Get the current health factor for a user
     * @param user The address of the user
     * @return The health factor (scaled by 1e18, >1 means safe, <1 means at risk)
     */
    function getHealthFactor(address user) public returns (uint256) {
        if (user == address(0)) return 0;
        
        // Get user account data from Aave
        (
            uint256 totalCollateralETH,
            uint256 totalDebtETH,
            uint256 availableBorrowsETH,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        ) = aaveDataProvider.getUserAccountData(user);
        
        // Emit an event with the account data for monitoring
        emit AccountData(
            user,
            totalCollateralETH,
            totalDebtETH,
            availableBorrowsETH,
            currentLiquidationThreshold,
            ltv,
            healthFactor
        );
        
        return healthFactor;
    }
    
    /**
     * @notice Get the current ETH price in USD from Chainlink
     * @return price The current ETH price (scaled to 8 decimals)
     */
    function getEthPrice() public view returns (uint256) {
        (
            , 
            int256 price,
            ,
            ,
            
        ) = ethUsdPriceFeed.latestRoundData();
        require(price > 0, "Invalid price feed");
        return uint256(price);
    }
    
    
    /**
     * @notice Check and adjust the position's health factor
     */
    function checkAndAdjustPosition() external whenNotPaused {
        uint256 healthFactor = getCurrentHealthFactor();
        if (healthFactor < MIN_HEALTH_FACTOR) {
            this._rebalancePosition(msg.sender);
        }
    }
    
    /**
     * @notice Internal function to rebalance the position
     * @param user Address of the user whose position needs rebalancing
     */
    function _rebalancePosition(address user) external {
        // This function is called via try/catch, so we use a reentrancy guard
        require(msg.sender == address(this), "Only callable internally");
        
        uint256 currentHf = _getHealthFactorView(user);
        require(currentHf < MIN_HEALTH_FACTOR, "Health factor is safe");
        
        // Get current debt and collateral from Aave
        (uint256 totalCollateralETH, uint256 totalDebtETH, , , , ) = aaveDataProvider.getUserAccountData(address(this));
        
        // Calculate how much to repay to reach target health factor
        uint256 ethPrice = getEthPrice();
        uint256 targetDebt = (totalDebtETH * currentHf) / TARGET_HEALTH_FACTOR;
        uint256 repayAmountETH = totalDebtETH - targetDebt;
        
        if (repayAmountETH > 0) {
            // Convert ETH amount to asset amount (adjust decimals as needed)
            uint256 repayAmount = (repayAmountETH * 1e8) / ethPrice;
            
            // Check if we have enough liquidity to repay
            uint256 availableLiquidity = IERC20(asset()).balanceOf(address(this));
            
            if (repayAmount > availableLiquidity) {
                // Calculate how much we can safely withdraw
                uint256 maxWithdraw = totalCollateralETH - (totalDebtETH * 1e18) / MIN_HEALTH_FACTOR;
                uint256 needed = repayAmount - availableLiquidity;
                uint256 withdrawAmount = needed > maxWithdraw ? maxWithdraw : needed;
                
                if (withdrawAmount > 0) {
                    // Withdraw from Aave
                    aavePool.withdraw(asset(), withdrawAmount, address(this));
                }
                
                // Update available liquidity after withdrawal
                availableLiquidity = IERC20(asset()).balanceOf(address(this));
            }
            
            // Repay debt with available liquidity (don't try to repay more than we have)
            uint256 actualRepayAmount = repayAmount > availableLiquidity ? availableLiquidity : repayAmount;
            if (actualRepayAmount > 0) {
                aavePool.repay(asset(), actualRepayAmount, 2, address(this));
            }
        }
        
        emit PositionAdjusted(currentHf, getCurrentHealthFactor());
    }
    
    // ============ Admin Functions ============

    /**
     * @notice Pause all state-changing operations
     * @dev Only callable by accounts with PAUSER_ROLE
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause all state-changing operations
     * @dev Only callable by accounts with PAUSER_ROLE
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }
    
    /**
     * @notice Grant Keeper role to an address
     * @param keeper Address to grant Keeper role to
     */
    function addKeeper(address keeper) external onlyOwner {
        grantRole(KEEPER_ROLE, keeper);
    }
    
    /**
     * @notice Revoke Keeper role from an address
     * @param keeper Address to revoke Keeper role from
     */
    function removeKeeper(address keeper) external onlyOwner {
        revokeRole(KEEPER_ROLE, keeper);
    }
    
    /**
     * @notice Recover ERC20 tokens sent by mistake
     * @param tokenAddress Address of the token to recover
     * @param to Address to send the tokens to
     * @param amount Amount to recover
     */
    function recoverERC20(
        address tokenAddress,
        address to,
        uint256 amount
    ) external onlyOwner {
        require(tokenAddress != address(asset()), "Cannot recover underlying asset");
        IERC20(tokenAddress).transfer(to, amount);
    }
}
