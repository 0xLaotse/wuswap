// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @notice Flash-swap callback invoked on the recipient when `swap` is called with data.
interface IWuswapCallee {
    function wuswapCall(address sender, uint256 amount0Out, uint256 amount1Out, bytes calldata data) external;
}
