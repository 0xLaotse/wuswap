// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

library Math {
    function min(uint256 x, uint256 y) internal pure returns (uint256) {
        return x < y ? x : y;
    }

    /// @dev Babylonian method, rounds down. Proven floor(sqrt(x)) by differential fuzz vs solady.
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}
