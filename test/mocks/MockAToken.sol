// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockAToken is ERC20 {
    IERC20 public immutable UNDERLYING_ASSET_ADDRESS;
    
    constructor(
        IERC20 underlyingAsset,
        string memory name,
        string memory symbol
    ) ERC20(name, symbol) {
        UNDERLYING_ASSET_ADDRESS = underlyingAsset;
    }
    
    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }
    
    function burn(address account, uint256 amount) external {
        _burn(account, amount);
    }
    
    function balanceOf(address account) public view override returns (uint256) {
        return super.balanceOf(account);
    }
    
    function transfer(address to, uint256 amount) public override returns (bool) {
        return super.transfer(to, amount);
    }
    
    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        return super.transferFrom(from, to, amount);
    }
}
