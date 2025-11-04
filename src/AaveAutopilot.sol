// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IAave.sol";
import "./interfaces/AggregatorV3Interface.sol";
import "./interfaces/KeeperCompatibleInterface.sol";

/**
 * @title AaveAutopilot
 * @notice ERC-4626 vault that manages Aave v3 positions with automatic health factor monitoring
 * @dev Implements intelligent position management to prevent liquidations
 */
contract AaveAutopilot is ERC4626, Ownable, ReentrancyGuard, Pausable, KeeperCompatibleInterface {
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
    
    /// @notice Last time the position was rebalanced
    uint256 public lastRebalanceTimestamp;
    
    /// @notice Minimum time between rebalances (1 hour)
    uint256 public constant REBALANCE_COOLDOWN = 1 hours;

    // ============ Events ============

    event HealthFactorChecked(uint256 healthFactor, bool actionTaken);
    event PositionAdjusted(uint256 oldHealthFactor, uint256 newHealthFactor);
    
    // ERC4626 Events
    event Deposited(address indexed sender, address indexed owner, uint256 assets, uint256 shares);
    event Withdrawn(address indexed sender, address indexed receiver, address indexed owner, uint256 assets, uint256 shares);

    // ============ Constructor ============

    /**
     * @param asset The underlying asset (e.g., USDC)
     * @param vaultName Name of the vault token
     * @param vaultSymbol Symbol of the vault token
     * @param _aavePool The Aave v3 pool address
     * @param _aaveDataProvider The Aave v3 data provider address
     * @param _aToken The Aave v3 aToken address
     * @param _ethUsdPriceFeed Chainlink ETH/USD price feed address
     */
    constructor(
        IERC20 asset,
        string memory vaultName,
        string memory vaultSymbol,
        address _aavePool,
        address _aaveDataProvider,
        address _aToken,
        address _ethUsdPriceFeed
    ) ERC4626(asset) ERC20(vaultName, vaultSymbol) Ownable(msg.sender) {
        require(_aavePool != address(0), "Invalid Aave Pool");
        require(_aaveDataProvider != address(0), "Invalid Data Provider");
        require(_aToken != address(0), "Invalid aToken");
        require(_ethUsdPriceFeed != address(0), "Invalid Price Feed");
        
        aavePool = IPool(_aavePool);
        aaveDataProvider = IPoolDataProvider(_aaveDataProvider);
        aToken = IAToken(_aToken);
        ethUsdPriceFeed = AggregatorV3Interface(_ethUsdPriceFeed);
        
        // Approve Aave Pool to spend our tokens
        IERC20(asset).approve(_aavePool, type(uint256).max);
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
     * @notice Check if the position needs rebalancing
     * @return upkeepNeeded Whether upkeep is needed
     * @return performData Encoded data for the performUpkeep call
     */
    /**
     * @notice Check if the position needs rebalancing
     * @return upkeepNeeded Whether upkeep is needed
     * @return performData Encoded data for the performUpkeep call
     */
    function checkUpkeep(
        bytes calldata /* checkData */
    ) 
        external 
        view 
        override 
        returns (bool upkeepNeeded, bytes memory performData) 
    {
        uint256 healthFactor = getCurrentHealthFactor();
        bool timePassed = block.timestamp - lastRebalanceTimestamp >= REBALANCE_COOLDOWN;
        
        upkeepNeeded = (healthFactor < KEEPER_THRESHOLD) && timePassed;
        performData = abi.encode(healthFactor);
        
        return (upkeepNeeded, performData);
    }
    
    /**
     * @notice Perform the rebalancing if needed
     * @param performData Encoded data from checkUpkeep
     */
    /**
     * @notice Perform the rebalancing if needed
     * @param performData Encoded data from checkUpkeep
     */
    function performUpkeep(
        bytes calldata performData
    ) 
        external 
        override 
        whenNotPaused
    {
        (uint256 healthFactor) = abi.decode(performData, (uint256));
        require(healthFactor < KEEPER_THRESHOLD, "Health factor above threshold");
        require(
            block.timestamp - lastRebalanceTimestamp >= REBALANCE_COOLDOWN, 
            "Cooldown not met"
        );
        
        lastRebalanceTimestamp = block.timestamp;
        _rebalancePosition(healthFactor);
        
        emit PositionAdjusted(healthFactor, getCurrentHealthFactor());
    }
    
    /**
     * @notice Check and adjust the position's health factor
     */
    function checkAndAdjustPosition() external whenNotPaused {
        uint256 healthFactor = getCurrentHealthFactor();
        if (healthFactor < MIN_HEALTH_FACTOR) {
            _rebalancePosition(healthFactor);
        }
    }
    
    /**
     * @notice Internal function to rebalance the position
     * @param currentHf Current health factor
     */
    function _rebalancePosition(uint256 currentHf) internal {
        require(currentHf < MIN_HEALTH_FACTOR, "Health factor is safe");
        
        // Get current debt and collateral from Aave
        (uint256 totalCollateralETH, uint256 totalDebtETH, uint256 availableBorrowsETH, , , ) = aaveDataProvider.getUserAccountData(address(this));
        
        // Calculate how much to repay to reach target health factor
        uint256 ethPrice = getEthPrice();
        uint256 targetDebt = (totalDebtETH * currentHf) / TARGET_HEALTH_FACTOR;
        uint256 repayAmountETH = totalDebtETH - targetDebt;
        
        if (repayAmountETH > 0) {
            // Convert ETH amount to asset amount
            uint256 repayAmount = (repayAmountETH * 1e8) / ethPrice; // Convert to asset decimals
            
            // Check if we have enough liquidity to repay
            uint256 availableLiquidity = IERC20(asset()).balanceOf(address(this));
            if (repayAmount > availableLiquidity) {
                // Withdraw some from Aave if needed
                uint256 needed = repayAmount - availableLiquidity;
                aavePool.withdraw(asset(), needed, address(this));
            }
            
            // Repay debt
            aavePool.repay(asset(), repayAmount, 2, address(this));
        }
        
        emit PositionAdjusted(currentHf, getCurrentHealthFactor());
    }
    
    // ============ Admin Functions ============
    
    /**
     * @notice Pause the contract in case of emergency
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @notice Unpause the contract
     */
    function unpause() external onlyOwner {
        _unpause();
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
