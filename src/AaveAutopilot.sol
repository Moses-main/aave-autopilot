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
import "./libraries/AaveLib.sol";

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
    
    using AaveLib for IPoolDataProvider;

    /// @notice Gas buffer for keeper operations (100k gas)
    uint256 public constant GAS_BUFFER = 100_000;
    
    /// @notice Safety margin for health factor (1.02 = 2%)
    uint256 public safetyMargin = 1.02e18;

    /// @notice Chainlink ETH/USD price feed
    AggregatorV3Interface public immutable ethUsdPriceFeed;

    /// @notice Aave Pool contract
    IPool public immutable aavePool;
    
    /// @notice Aave Data Provider contract
    IPoolDataProvider public immutable aaveDataProvider;
    
    /// @notice Aave aToken for the underlying asset
    IAToken public immutable aToken;
    
    /// @notice Chainlink token address
    address public immutable LINK_TOKEN;
    
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
    event GasLimitReached(address indexed lastProcessedUser, uint256 processedCount);
    event SafetyMarginUpdated(uint256 oldMargin, uint256 newMargin);
    
    // ERC4626 Events
    event Deposited(address indexed sender, address indexed owner, uint256 assets, uint256 shares);
    event Withdrawn(address indexed sender, address indexed receiver, address indexed owner, uint256 assets, uint256 shares);
    
    /**
     * @notice Set the safety margin for health factor checks
     * @param _safetyMargin New safety margin (1e18 = 100%, 1.02e18 = 102%, etc.)
     */
    function setSafetyMargin(uint256 _safetyMargin) external onlyOwner {
        require(_safetyMargin >= 1e18, "Margin too low");
        require(_safetyMargin <= 1.1e18, "Margin too high");
        emit SafetyMarginUpdated(safetyMargin, _safetyMargin);
        safetyMargin = _safetyMargin;
    }
    
    /**
     * @notice Withdraw any LINK tokens from the contract
     * @param to Address to send the LINK tokens to
     */
    function withdrawLink(address to) external onlyOwner {
        require(to != address(0), "Invalid address");
        IERC20 link = IERC20(LINK_TOKEN);
        uint256 balance = link.balanceOf(address(this));
        require(balance > 0, "No LINK to withdraw");
        link.safeTransfer(to, balance);
    }

    // ============ Constructor ============

    /**
     * @param _asset The underlying asset (e.g., USDC)
     * @param _name Name of the vault token
     * @param _symbol Symbol of the vault token
     * @param _aavePool The Aave v3 pool address
     * @param _aaveDataProvider The Aave v3 data provider address
     * @param _aToken The Aave v3 aToken address
     * @param _ethUsdPriceFeed Chainlink ETH/USD price feed address
     * @param _linkToken Chainlink token address
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
        address _linkToken,
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
        LINK_TOKEN = _linkToken;
        
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
        require(healthFactor >= AaveLib.MIN_HEALTH_FACTOR, "Withdrawal would make position unsafe");
        
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
            bool userNeedsRebalance = userHf < AaveLib.KEEPER_THRESHOLD && 
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
        bool currentNeedsRebalance = currentHf < AaveLib.KEEPER_THRESHOLD && 
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
            if (oldHealthFactor >= AaveLib.KEEPER_THRESHOLD || 
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
        ( , , , , , healthFactor) = aaveDataProvider.getUserAccountData(address(this));
        return healthFactor;
    }
    
    /**
     * @notice Get the current health factor for a user (view-only, doesn't emit events)
     * @param user The address of the user
     * @return The health factor (scaled by 1e18, >1 means safe, <1 means at risk)
     */
    function _getHealthFactorView(address user) internal view returns (uint256) {
        ( , , , , , uint256 healthFactor) = aaveDataProvider.getUserAccountData(user);
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
     * @notice Check and adjust the position's health factor
     */
    function checkAndAdjustPosition() external whenNotPaused {
        uint256 healthFactor = getCurrentHealthFactor();
        if (healthFactor < AaveLib.MIN_HEALTH_FACTOR) {
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
        require(currentHf < AaveLib.MIN_HEALTH_FACTOR, "Health factor is safe");
        
        // Call the library function to handle the rebalancing
        uint256 newHealthFactor = AaveLib.rebalancePosition(
            aavePool,
            aaveDataProvider,
            asset(),
            ethUsdPriceFeed,
            address(this)
        );
        
        emit PositionAdjusted(currentHf, newHealthFactor);
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
