// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {WuswapPair} from "src/WuswapPair.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {FactoryStub} from "test/mocks/FactoryStub.sol";
import {RefMath} from "test/utils/RefMath.sol";

contract PairSwapTest is Test {
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
        _seedLiquidity(5e18, 10e18);
    }

    /// Deposit-then-call: tokens are transferred into the pair, then mint credits them.
    function _seedLiquidity(uint256 amount0, uint256 amount1) internal {
        token0.mint(address(pair), amount0);
        token1.mint(address(pair), amount1);
        pair.mint(alice);
    }

    /// Pay the canonical input for an exact output: the output lands, reserves move by
    /// exactly (+in, -out), and the fee-adjusted K check passes on the +1-wei rounding.
    function test_Swap_ExactOutput() public {
        (uint112 r0, uint112 r1,) = pair.getReserves();
        uint256 amount1Out = 1e18;
        uint256 amount0In = RefMath.getAmountIn(amount1Out, r0, r1);

        token0.mint(address(pair), amount0In);
        pair.swap(0, amount1Out, bob, "");

        assertEq(token1.balanceOf(bob), amount1Out);
        (uint112 nr0, uint112 nr1,) = pair.getReserves();
        assertEq(nr0, uint256(r0) + amount0In);
        assertEq(nr1, uint256(r1) - amount1Out);
    }

    function test_RevertWhen_NoOutput() public {
        vm.expectRevert(WuswapPair.InsufficientOutputAmount.selector);
        pair.swap(0, 0, bob, "");
    }

    /// Output must be strictly below the reserve — draining a side is rejected before any transfer.
    function test_RevertWhen_OutputExceedsReserves() public {
        (, uint112 r1,) = pair.getReserves();
        vm.expectRevert(WuswapPair.InsufficientLiquidity.selector);
        pair.swap(0, r1, bob, "");
    }

    /// The output recipient can never be one of the pool tokens — would corrupt balance accounting.
    function test_RevertWhen_ToIsToken() public {
        vm.expectRevert(WuswapPair.InvalidTo.selector);
        pair.swap(0, 1e18, address(token0), "");
    }

    /// Requesting output without paying anything in: balance delta is zero on both sides.
    function test_RevertWhen_NoInput() public {
        vm.expectRevert(WuswapPair.InsufficientInputAmount.selector);
        pair.swap(0, 1e18, bob, "");
    }

    /// One wei short of the canonical input breaks x*y >= k — the fee-adjusted check catches it.
    function test_RevertWhen_UnderpaidInput() public {
        (uint112 r0, uint112 r1,) = pair.getReserves();
        uint256 amount1Out = 1e18;
        uint256 amount0In = RefMath.getAmountIn(amount1Out, r0, r1);

        token0.mint(address(pair), amount0In - 1);
        vm.expectRevert(WuswapPair.KInvariantViolated.selector);
        pair.swap(0, amount1Out, bob, "");
    }
}
