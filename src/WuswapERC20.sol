// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ERC20} from "solady/tokens/ERC20.sol";

/// @notice LP token base for wuswap pairs. solady ERC20 ships EIP-2612 permit.
abstract contract WuswapERC20 is ERC20 {
    function name() public pure override returns (string memory) {
        return "Wuswap LP Token";
    }

    function symbol() public pure override returns (string memory) {
        return "WLP";
    }
}
