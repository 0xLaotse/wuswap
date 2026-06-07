// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {Math} from "src/libraries/Math.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

contract SqrtFuzzTest is Test {
    /// Differential check: our babylonian sqrt must match solady's, full uint256 range.
    function testFuzz_SqrtMatchesSolady(uint256 x) public pure {
        assertEq(Math.sqrt(x), FixedPointMathLib.sqrt(x));
    }

    /// floor property: z^2 <= x < (z+1)^2
    function testFuzz_SqrtIsFloor(uint256 x) public pure {
        uint256 z = Math.sqrt(x);
        assertLe(z * z, x);
        if (z < type(uint128).max) assertGt((z + 1) * (z + 1), x);
    }
}
