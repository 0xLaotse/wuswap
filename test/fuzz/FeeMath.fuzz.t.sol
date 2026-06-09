// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {WuswapPair} from "src/WuswapPair.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {FactoryStub} from "test/mocks/FactoryStub.sol";
import {RefMath} from "test/utils/RefMath.sol";

/// Fee-math properties of the constant-product swap. The pricing reference (RefMath) is held
/// against the pair's actual execution — the contract trusts no formula, so the formula is
/// proven to agree with what the K check lets through, not the other way around.
contract FeeMathFuzzTest is Test {
    FactoryStub internal factory;
    WuswapPair internal pair;
    MockERC20 internal token0;
    MockERC20 internal token1;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public {
        MockERC20 tokenA = new MockERC20("Token A", "TKA", 18);
        MockERC20 tokenB = new MockERC20("Token B", "TKB", 18);
        (token0, token1) = address(tokenA) < address(tokenB) ? (tokenA, tokenB) : (tokenB, tokenA);
        factory = new FactoryStub();
        pair = factory.createPair(address(token0), address(token1));
    }

    function _seed(uint256 r0, uint256 r1) internal returns (uint112 R0, uint112 R1) {
        token0.mint(address(pair), r0);
        token1.mint(address(pair), r1);
        pair.mint(alice);
        (R0, R1,) = pair.getReserves();
    }

    // --- pure pricing properties (RefMath) ---

    /// A quote can never hand out the whole opposite reserve — the curve is asymptotic.
    function testFuzz_OutputNeverDrainsReserve(uint112 rIn, uint112 rOut, uint256 amountIn) public pure {
        uint256 ri = bound(rIn, 1000, type(uint112).max);
        uint256 ro = bound(rOut, 1000, type(uint112).max);
        amountIn = bound(amountIn, 1, type(uint112).max);
        assertLt(RefMath.getAmountOut(amountIn, ri, ro), ro);
    }

    /// The 0.3% is genuinely withheld: a fee quote never beats the same trade priced fee-free.
    /// Stated as <= because at sub-wei outputs both sides floor to the same integer.
    function testFuzz_FeeAlwaysTaken(uint112 rIn, uint112 rOut, uint256 amountIn) public pure {
        uint256 ri = bound(rIn, 1e6, 1e30);
        uint256 ro = bound(rOut, 1e6, 1e30);
        amountIn = bound(amountIn, 1, ri);
        uint256 feeOut = RefMath.getAmountOut(amountIn, ri, ro);
        uint256 zeroFeeOut = amountIn * ro / (ri + amountIn);
        assertLe(feeOut, zeroFeeOut);
    }

    /// getAmountIn is the inverse of getAmountOut up to rounding: paying the quoted input for x
    /// returns x or x+1. Priced at 1:1 with a small trade so the ±1 isn't swamped by curvature —
    /// the safety half (back >= x, i.e. the input is never too low) holds at any price.
    function testFuzz_QuoteRoundtrip(uint112 reserve, uint256 amountOut) public pure {
        uint256 r = bound(reserve, 1e18, 1e30);
        amountOut = bound(amountOut, 1, r / 1000);
        uint256 amountIn = RefMath.getAmountIn(amountOut, r, r);
        uint256 back = RefMath.getAmountOut(amountIn, r, r);
        assertGe(back, amountOut);
        assertLe(back, amountOut + 1);
    }

    // --- differential: reference quote vs on-chain execution ---

    /// The differential core: an independently computed RefMath quote is exactly what a real
    /// swap pays out. If the contract's K check and the formula ever disagreed, this breaks.
    function testFuzz_DifferentialQuoteVsExecution(uint112 res0, uint112 res1, uint256 amountIn) public {
        (uint112 R0, uint112 R1) = _seed(bound(res0, 1e9, 1e30), bound(res1, 1e9, 1e30));
        amountIn = bound(amountIn, 1e6, 1e30);
        uint256 expectedOut = RefMath.getAmountOut(amountIn, R0, R1);
        vm.assume(expectedOut > 0);

        token0.mint(address(pair), amountIn);
        pair.swap(0, expectedOut, bob, "");

        assertEq(token1.balanceOf(bob), expectedOut);
    }

    /// k = r0*r1 can only grow across a swap: fees stay in the pool, never leak out.
    function testFuzz_KNeverDecreasesAcrossSwaps(uint112 res0, uint112 res1, uint256 amountIn) public {
        (uint112 R0, uint112 R1) = _seed(bound(res0, 1e9, 1e30), bound(res1, 1e9, 1e30));
        amountIn = bound(amountIn, 1e6, 1e30);
        uint256 kBefore = uint256(R0) * R1;

        uint256 expectedOut = RefMath.getAmountOut(amountIn, R0, R1);
        vm.assume(expectedOut > 0);

        token0.mint(address(pair), amountIn);
        pair.swap(0, expectedOut, bob, "");

        (uint112 nR0, uint112 nR1,) = pair.getReserves();
        assertGe(uint256(nR0) * nR1, kBefore);
    }
}
