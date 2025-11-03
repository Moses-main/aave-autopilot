// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title AaveAutopilot
 * @notice ERC-4626 vault that manages Aave v3 positions with automatic health factor monitoring
 * @dev Implements intelligent position management to prevent liquidations
 */
contract AaveAutopilot is ERC4626, Ownable {
    
    // ============ State Variables ============
    
    /// @notice Minimum health factor before triggering auto-adjustment
    uint256 public constant MIN_HEALTH_FACTOR = 1.5e18; // 1.5 in 18 decimals
    
    /// @notice Target health factor after rebalancing
    uint256 public constant TARGET_HEALTH_FACTOR = 2e18; // 2.0 in 18 decimals
    
    /// @notice Total assets deposited by all users
    uint256 private _totalAssets;
    
    // ============ Events ============
    
    event HealthFactorChecked(uint256 healthFactor, bool actionTaken);
    event PositionAdjusted(uint256 oldHealthFactor, uint256 newHealthFactor);
    
    // ============ Constructor ============
    
    /**
     * @param asset The underlying asset (e.g., USDC)
     * @param vaultName Name of the vault token
     * @param vaultSymbol Symbol of the vault token
     */
    constructor(
        IERC20 asset,
        string memory vaultName,
        string memory vaultSymbol
    ) ERC4626(asset) ERC20(vaultName, vaultSymbol) Ownable(msg.sender) {}
    
    // ============ Core ERC-4626 Functions ============
    
    /**
     * @notice Total assets managed by the vault
     */
    function totalAssets() public view override returns (uint256) {
        return _totalAssets;
    }
    
    /**
     * @notice Deposit assets into the vault
     */
    function _deposit(
        address caller,
        address receiver,
        uint256 assets,
        uint256 shares
    ) internal override {
        super._deposit(caller, receiver, assets, shares);
        _totalAssets += assets;
        
        // TODO: Supply to Aave (Day 2)
    }
    
    /**
     * @notice Withdraw assets from the vault
     */
    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal override {
        // TODO: Withdraw from Aave (Day 2)
        
        super._withdraw(caller, receiver, owner, assets, shares);
        _totalAssets -= assets;
    }
    
    // ============ Health Factor Management (Day 3) ============
    
    /**
     * @notice Check health factor and adjust if needed
     */
    function checkAndAdjustPosition() external {
        // TODO: Implement on Day 3
    }
}
