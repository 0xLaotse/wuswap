// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @notice Canonical Uniswap-V2 swap quoting — the independent reference the pair's
///         on-chain K check is differentially tested against. Lives in test/ only:
///         the pair never trusts a pricing formula, it verifies x*y >= k on balances.
library RefMath {
    /// @dev Output for an exact input after the 0.3% fee. amountIn*997 is the fee-adjusted
    ///      input; the classic closed form keeps every intermediate in integer space.
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) internal pure returns (uint256) {
        uint256 amountInWithFee = amountIn * 997;
        return amountInWithFee * reserveOut / (reserveIn * 1000 + amountInWithFee);
    }

    /// @dev Minimum input to receive an exact output, fee included. The trailing +1 rounds
    ///      up so the pool is never shortchanged — the caller always overpays by <1 wei.
    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut) internal pure returns (uint256) {
        return reserveIn * amountOut * 1000 / ((reserveOut - amountOut) * 997) + 1;
    }
}
