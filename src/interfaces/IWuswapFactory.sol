// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @notice Surface the pair reads for fee config and that periphery uses to resolve pairs.
interface IWuswapFactory {
    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);
    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint256 index) external view returns (address pair);
    function allPairsLength() external view returns (uint256);
    function createPair(address tokenA, address tokenB) external returns (address pair);
}
