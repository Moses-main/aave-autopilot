// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IAave.sol";
import "../interfaces/AggregatorV3Interface.sol";

library AaveLib {
    // Constants for health factors
    uint256 public constant MIN_HEALTH_FACTOR = 1.05e18;
    uint256 public constant TARGET_HEALTH_FACTOR = 1.5e18;
    uint256 public constant KEEPER_THRESHOLD = 1.1e18;
    
    /**
     * @notice Get the current health factor for a user
     * @param dataProvider The Aave data provider contract
     * @param user The address of the user
     * @return healthFactor The current health factor (scaled by 1e18)
     */
    function getHealthFactor(
        IPoolDataProvider dataProvider,
        address user
    ) 
        internal 
        view 
        returns (uint256) 
    {
        if (user == address(0)) return 0;
        
        // Get user account data from Aave
        ( , , , , , uint256 healthFactor) = dataProvider.getUserAccountData(user);
        return healthFactor;
    }
    
    /**
     * @notice Rebalance a user's position to maintain safe health factor
     * @param pool The Aave pool contract
     * @param dataProvider The Aave data provider contract
     * @param asset The underlying asset address
     * @param ethPriceFeed The Chainlink ETH/USD price feed
     * @param user The address of the user
     * @return newHealthFactor The new health factor after rebalancing
     */
    function rebalancePosition(
        IPool pool,
        IPoolDataProvider dataProvider,
        address asset,
        AggregatorV3Interface ethPriceFeed,
        address user
    ) 
        external 
        returns (uint256 newHealthFactor) 
    {
        // Get current health factor
        uint256 currentHf = getHealthFactor(dataProvider, user);
        require(currentHf < MIN_HEALTH_FACTOR, "Health factor is safe");
        
        // Get current debt and collateral from Aave
        (uint256 totalCollateralETH, uint256 totalDebtETH, , , , ) = 
            dataProvider.getUserAccountData(user);
        
        // Calculate how much to repay to reach target health factor
        uint256 ethPrice = getEthPrice(ethPriceFeed);
        uint256 targetDebt = (totalDebtETH * currentHf) / TARGET_HEALTH_FACTOR;
        uint256 repayAmountETH = totalDebtETH > targetDebt ? totalDebtETH - targetDebt : 0;
        
        if (repayAmountETH > 0) {
            // Convert ETH amount to asset amount (adjust decimals as needed)
            uint256 repayAmount = (repayAmountETH * 1e8) / ethPrice;
            
            // Check if we have enough liquidity to repay
            uint256 availableLiquidity = IERC20(asset).balanceOf(user);
            
            if (repayAmount > availableLiquidity) {
                // Calculate how much we can safely withdraw
                uint256 maxWithdraw = totalCollateralETH - (totalDebtETH * 1e18) / MIN_HEALTH_FACTOR;
                uint256 needed = repayAmount - availableLiquidity;
                uint256 withdrawAmount = needed > maxWithdraw ? maxWithdraw : needed;
                
                if (withdrawAmount > 0) {
                    // Withdraw from Aave
                    pool.withdraw(asset, withdrawAmount, user);
                }
                
                // Update available liquidity after withdrawal
                availableLiquidity = IERC20(asset).balanceOf(user);
            }
            
            // Repay debt with available liquidity (don't try to repay more than we have)
            uint256 actualRepayAmount = repayAmount > availableLiquidity ? availableLiquidity : repayAmount;
            if (actualRepayAmount > 0) {
                pool.repay(asset, actualRepayAmount, 2, user);
            }
        }
        
        // Return the new health factor
        ( , , , , , newHealthFactor) = dataProvider.getUserAccountData(user);
        return newHealthFactor;
    }
    
    /**
     * @notice Get the current ETH price in USD from Chainlink
     * @param priceFeed The Chainlink price feed contract
     * @return price The current ETH price (scaled to 8 decimals)
     */
    function getEthPrice(AggregatorV3Interface priceFeed) 
        internal 
        view 
        returns (uint256) 
    {
        (
            , 
            int256 price,
            ,
            ,
            
        ) = priceFeed.latestRoundData();
        require(price > 0, "Invalid price feed");
        return uint256(price);
    }
}
