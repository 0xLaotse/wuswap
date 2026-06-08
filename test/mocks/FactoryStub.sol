// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {WuswapPair} from "src/WuswapPair.sol";

/// @notice Minimal stand-in for the real factory (lands in a later PR) so pairs can be
///         deployed in tests today. Supplies the feeTo() the pair reads in _mintFee;
///         defaults to address(0), i.e. protocol fee off. setFeeTo flips the fee path on.
contract FactoryStub {
    address public feeTo;

    function setFeeTo(address newFeeTo) external {
        feeTo = newFeeTo;
    }

    function createPair(address token0, address token1) external returns (WuswapPair pair) {
        pair = new WuswapPair(token0, token1);
    }
}
