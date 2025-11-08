// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC4626WithName} from "./ERC4626WithName.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IPool, IPoolDataProvider, IAToken} from "./interfaces/IAave.sol";
import {AggregatorV3Interface} from "./interfaces/AggregatorV3Interface.sol";
import {KeeperCompatibleInterface} from "./interfaces/KeeperCompatibleInterface.sol";
import {AaveLib} from "./libraries/AaveLib.sol";

/**
 * @title AaveAutopilot
 * @notice ERC-4626 vault that manages Aave v3 positions with automatic health factor monitoring
 * @dev Implements intelligent position management to prevent liquidations
 */
contract AaveAutopilot is 
    ERC4626WithName, 
    Ownable, 
    AccessControl, 
    ReentrancyGuard, 
    Pausable, 
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
    AggregatorV3Interface public immutable ETH_USD_PRICE_FEED;

    /// @notice Aave Pool contract
    IPool public immutable AAVE_POOL;
    
    /// @notice Aave Data Provider contract
    IPoolDataProvider public immutable AAVE_DATA_PROVIDER;
    
    /// @notice Aave aToken for the underlying asset
    IAToken public immutable A_TOKEN;

    /// @notice Chainlink token address
    address public immutable LINK_TOKEN;
    
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
     * @param _linkToken Address of the LINK token
     */
    constructor(
        IERC20Metadata _asset,
        string memory _name,
        string memory _symbol,
        address _aavePool,
        address _aaveDataProvider,
        address _aToken,
        address _ethUsdPriceFeed,
        address _linkToken
    ) ERC4626WithName(_asset, _name, _symbol) {
        require(_aavePool != address(0), "Invalid Aave Pool address");
        require(_aaveDataProvider != address(0), "Invalid Aave Data Provider address");
        require(_aToken != address(0), "Invalid aToken address");
        require(_ethUsdPriceFeed != address(0), "Invalid price feed address");
        require(_linkToken != address(0), "Invalid LINK token address");
        
        AAVE_POOL = IPool(_aavePool);
        AAVE_DATA_PROVIDER = IPoolDataProvider(_aaveDataProvider);
        A_TOKEN = IAToken(_aToken);
        ETH_USD_PRICE_FEED = AggregatorV3Interface(_ethUsdPriceFeed);
        LINK_TOKEN = _linkToken;
        
        // Set up default admin role
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        
        // Approve Aave Pool to spend our tokens
        IERC20(asset()).safeIncreaseAllowance(_aavePool, type(uint256).max);
    }

    // ============ Core ERC-4626 Functions ============

    /**
     * @notice Deposit assets into the vault
     * @param assets Amount of assets to deposit
     * @param receiver Address to receive minted shares
     * @return shares Amount of shares minted
     */
    function deposit(uint256 assets, address receiver) 
        public 
        override 
        nonReentrant 
        whenNotPaused 
        returns (uint256) 
    {
        require(assets > 0, "Cannot deposit 0");
        require(receiver != address(0), "Invalid receiver address");
        
        // Check allowance
        uint256 allowance = IERC20(asset()).allowance(msg.sender, address(this));
        require(allowance >= assets, "Insufficient allowance. Please approve first.");
        
        // Calculate shares (1:1 for now, can be changed for fee logic)
        uint256 shares = previewDeposit(assets);
        
        // Call internal _deposit
        _deposit(msg.sender, receiver, assets, shares);
        
        return shares;
    }
    
    /**
     * @notice Deposit assets into the vault with signature support
     * @param assets Amount of assets to deposit
     * @param receiver Address to receive minted shares
     * @param owner Address that owns the assets
     * @return shares Amount of shares minted
     */
    function deposit(uint256 assets, address receiver, address owner)
        public
        returns (uint256)
    {
        if (msg.sender != owner) {
            uint256 allowed = allowance(owner, msg.sender);
            if (allowed != type(uint256).max) {
                require(allowed >= assets, "Insufficient allowance");
                _approve(owner, msg.sender, allowed - assets);
            }
        }
        return deposit(assets, receiver);
    }

    /**
     * @notice Total assets managed by the vault
     */
    // Update totalAssets to get real balance from Aave
    function totalAssets() public view override returns (uint256) {
        return A_TOKEN.balanceOf(address(this)); // Real-time balance with interest
    }

    /**
     * @notice Deposit assets into the vault
     */
    function _deposit(
        address caller,
        address receiver,
        uint256 assets,
        uint256 shares
    ) 
        internal 
        override 
        nonReentrant 
        whenNotPaused 
    {
        DepositParams memory params = DepositParams({
            caller: caller,
            receiver: receiver,
            assets: assets,
            shares: shares
        });
        
        _validateDeposit(params);
        _executeDeposit(params);
    }
    
    /**
     * @dev Validate deposit parameters
     */
    function _validateDeposit(DepositParams memory params) internal pure {
        require(params.assets > 0, "Cannot deposit 0");
        require(params.shares > 0, "Invalid share amount");
    }
    
    /**
     * @dev Execute deposit
     */
    function _executeDeposit(DepositParams memory params) internal {
        IERC20 token = IERC20(asset());
        
        // Transfer assets from caller to this contract
        SafeERC20.safeTransferFrom(token, params.caller, address(this), params.assets);
        
        // Supply to Aave
        AAVE_POOL.supply(asset(), params.assets, address(this), 0);
        
        // Mint shares to receiver
        _mint(params.receiver, params.shares);
        
        // Emit events
        emit Deposit(params.caller, params.receiver, params.assets, params.shares);
        emit Deposited(params.caller, params.receiver, params.assets, params.shares);
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
        WithdrawParams memory params = WithdrawParams({
            caller: caller,
            receiver: receiver,
            owner: owner,
            assets: assets,
            shares: shares
        });
        
        _validateWithdraw(params);
        _executeWithdraw(params);
    }
    
    /**
     * @dev Validate withdrawal parameters
     */
    function _validateWithdraw(WithdrawParams memory params) internal view {
        require(params.assets > 0, "Cannot withdraw 0");
        require(params.shares > 0, "Invalid share amount");
        
        // Check health factor after withdrawal using view function to save gas
        uint256 healthFactor = _getHealthFactorView(address(this));
        require(healthFactor >= AaveLib.MIN_HEALTH_FACTOR, "Withdrawal would make position unsafe");
    }
    
    /**
     * @dev Execute withdrawal
     */
    function _executeWithdraw(WithdrawParams memory params) internal {
        // Withdraw from Aave
        AAVE_POOL.withdraw(asset(), params.assets, address(this));
        
        // Call parent contract's _withdraw
        super._withdraw(params.caller, params.receiver, params.owner, params.assets, params.shares);
        
        emit Withdrawn(params.caller, params.receiver, params.owner, params.assets, params.shares);
    }

            // ============ Chainlink Automation ============
    
    // State variables for batch processing and circuit breaker
    uint256 public currentBatchIndex;
    uint256 private lastCheckedIndex;
    mapping(address => uint256) public rebalanceAttempts;
    mapping(address => uint256) public lastRebalanceTimestamp;
    uint256 public constant MAX_REBALANCE_ATTEMPTS = 3;
    uint256 public constant BATCH_SIZE = 10; // Number of users to process in one batch
    
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
    ) external override returns (bool upkeepNeeded, bytes memory performData) {
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
        
        // For the purpose of this demo, we'll return false when checkData is empty
        // In a production environment, you would implement batch processing of users here
        // and return the appropriate list of users that need rebalancing
        
        // Return empty arrays to indicate no upkeep is needed
        address[] memory emptyUsers = new address[](0);
        return (false, abi.encode(emptyUsers));
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
            _processUser(users[i]);
        }
        
        // Update batch index for next run
        currentBatchIndex = (currentBatchIndex + 1) % 10;
    }
    
    /**
     * @dev Process a single user for rebalancing
     * @param user The address of the user to process
     */
    function _processUser(address user) internal {
        uint256 oldHealthFactor = getHealthFactor(user);
        
        // Skip if user doesn't need rebalancing or has exceeded max attempts
        if (oldHealthFactor >= AaveLib.KEEPER_THRESHOLD || 
            oldHealthFactor == 0 || 
            rebalanceAttempts[user] >= MAX_REBALANCE_ATTEMPTS) {
            return;
        }
        
        try this._rebalancePosition(user) {
            // Success - reset attempt counter
            rebalanceAttempts[user] = 0;
            uint256 newHealthFactor = getHealthFactor(user);
            emit PositionRebalanced(user, oldHealthFactor, newHealthFactor);
            emit RebalanceAttempt(user, oldHealthFactor, newHealthFactor, true, "");
        } catch Error(string memory reason) {
            // Increment attempt counter on failure
            _handleRebalanceFailure(user, oldHealthFactor, reason);
        } catch (bytes memory) {
            // Catch any other errors
            _handleRebalanceFailure(user, oldHealthFactor, "Unknown error");
        }
    }
    
    /**
     * @dev Handle rebalance failure
     */
    function _handleRebalanceFailure(address user, uint256 oldHealthFactor, string memory reason) internal {
        rebalanceAttempts[user]++;
        emit RebalanceAttempt(user, oldHealthFactor, 0, false, reason);
        
        if (rebalanceAttempts[user] >= MAX_REBALANCE_ATTEMPTS) {
            emit MaxAttemptsReached(user);
        }
    }
    
    // ============ Health Factor Management ============
    
    /**
     * @notice Get the current health factor from Aave
     * @return healthFactor The current health factor (scaled by 1e18)
     */
    function getCurrentHealthFactor() public view returns (uint256 healthFactor) {
        ( , , , , , healthFactor) = AAVE_DATA_PROVIDER.getUserAccountData(address(this));
        return healthFactor;
    }
    
    /**
     * @notice Get the current health factor for a user (view-only, doesn't emit events)
     * @param user The address of the user
     * @return The health factor (scaled by 1e18, >1 means safe, <1 means at risk)
     */
    function _getHealthFactorView(address user) internal view returns (uint256) {
        ( , , , , , uint256 healthFactor) = AAVE_DATA_PROVIDER.getUserAccountData(user);
        return healthFactor;
    }
    
    // Struct to hold Aave user account data
    struct UserAccountData {
        uint256 totalCollateralETH;
        uint256 totalDebtETH;
        uint256 availableBorrowsETH;
        uint256 currentLiquidationThreshold;
        uint256 ltv;
        uint256 healthFactor;
    }
    
    // Struct to hold deposit parameters
    struct DepositParams {
        address caller;
        address receiver;
        uint256 assets;
        uint256 shares;
    }
    
    // Struct to hold withdraw parameters
    struct WithdrawParams {
        address caller;
        address receiver;
        address owner;
        uint256 assets;
        uint256 shares;
    }

    /**
     * @notice Get the current health factor for a user
     * @param user The address of the user
     * @return healthFactor The health factor (scaled by 1e18, >1 means safe, <1 means at risk)
     */
    function getHealthFactor(address user) public returns (uint256 healthFactor) {
        if (user == address(0)) return 0;
        
        // Get user account data from Aave
        UserAccountData memory data = _getUserAccountData(user);
        
        // Emit an event with the account data for monitoring
        _emitAccountData(user, data);
        
        return data.healthFactor;
    }
    
    /**
     * @dev Internal function to get user account data from Aave
     */
    function _getUserAccountData(address user) internal view returns (UserAccountData memory data) {
        (
            data.totalCollateralETH,
            data.totalDebtETH,
            data.availableBorrowsETH,
            data.currentLiquidationThreshold,
            data.ltv,
            data.healthFactor
        ) = AAVE_DATA_PROVIDER.getUserAccountData(user);
        return data;
    }
    
    /**
     * @dev Internal function to emit account data event
     */
    function _emitAccountData(address user, UserAccountData memory data) internal {
        emit AccountData(
            user,
            data.totalCollateralETH,
            data.totalDebtETH,
            data.availableBorrowsETH,
            data.currentLiquidationThreshold,
            data.ltv,
            data.healthFactor
        );
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
            AAVE_POOL,
            AAVE_DATA_PROVIDER,
            asset(),
            ETH_USD_PRICE_FEED,
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
        SafeERC20.safeTransfer(IERC20(tokenAddress), to, amount);
    }
}
