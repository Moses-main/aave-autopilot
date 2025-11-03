// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IPool {
    /**
     * @notice Supply assets to Aave
     * @param asset The address of the underlying asset
     * @param amount The amount to supply
     * @param onBehalfOf Address that will receive the aTokens
     * @param referralCode Referral code (use 0)
     */
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;

    /**
     * @notice Withdraw assets from Aave
     * @param asset The address of the underlying asset
     * @param amount The amount to withdraw (use type(uint256).max for all)
     * @param to Address that will receive the assets
     */
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
}

interface IPoolDataProvider {
    /**
     * @notice Get user's account data
     * @return totalCollateralBase Total collateral in base currency
     * @return totalDebtBase Total debt in base currency
     * @return availableBorrowsBase Available to borrow in base currency
     * @return currentLiquidationThreshold Liquidation threshold
     * @return ltv Loan to value
     * @return healthFactor Current health factor
     */
    function getUserAccountData(address user)
        external
        view
        returns (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        );
}

interface IAToken {
    /**
     * @notice Get balance of aTokens (includes accrued interest)
     */
    function balanceOf(address user) external view returns (uint256);
}
