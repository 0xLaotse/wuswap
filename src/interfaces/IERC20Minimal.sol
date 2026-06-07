// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @notice Minimal ERC20 surface the pair relies on to move tokens and read balances.
interface IERC20Minimal {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}
