// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {WuswapPair} from "src/WuswapPair.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {FactoryStub} from "test/mocks/FactoryStub.sol";

contract PairBurnTest is Test {
    FactoryStub internal factory;
    WuswapPair internal pair;
    MockERC20 internal token0;
    MockERC20 internal token1;

    address internal alice = makeAddr("alice");

    function setUp() public {
        MockERC20 tokenA = new MockERC20("Token A", "TKA", 18);
        MockERC20 tokenB = new MockERC20("Token B", "TKB", 18);
        (token0, token1) = address(tokenA) < address(tokenB) ? (tokenA, tokenB) : (tokenB, tokenA);
        factory = new FactoryStub();
        pair = factory.createPair(address(token0), address(token1));
    }

    function _mintTo(address to, uint256 a0, uint256 a1) internal returns (uint256 liquidity) {
        token0.mint(address(pair), a0);
        token1.mint(address(pair), a1);
        liquidity = pair.mint(to);
    }

    /// Burning the full LP position returns the pro-rata floor of each reserve; the
    /// MINIMUM_LIQUIDITY shares stay locked, so the pool is never fully drained.
    function test_Burn_Proportional() public {
        uint256 liquidity = _mintTo(alice, 1e18, 4e18); // 2e18 - 1000, reserves (1e18, 4e18), supply 2e18

        vm.prank(alice);
        assertTrue(pair.transfer(address(pair), liquidity));
        vm.prank(alice);
        (uint256 amount0, uint256 amount1) = pair.burn(alice);

        // floor(liquidity * balance / supply) with liquidity = 2e18-1000, supply = 2e18
        assertEq(amount0, 1e18 - 500); // (2e18-1000) * 1e18 / 2e18
        assertEq(amount1, 4e18 - 2000); // (2e18-1000) * 4e18 / 2e18
        assertEq(token0.balanceOf(alice), amount0);
        assertEq(token1.balanceOf(alice), amount1);

        // pool keeps the dust backing the 1000 locked shares
        assertEq(pair.totalSupply(), 1000);
        (uint112 r0, uint112 r1,) = pair.getReserves();
        assertEq(r0, 500);
        assertEq(r1, 2000);
        assertEq(token0.balanceOf(address(pair)), 500);
        assertEq(token1.balanceOf(address(pair)), 2000);
    }

    function test_RevertWhen_BurnZeroAmounts() public {
        _mintTo(alice, 1e18, 4e18);
        // no LP transferred into the pair → nothing to burn
        vm.expectRevert(WuswapPair.InsufficientLiquidityBurned.selector);
        pair.burn(alice);
    }

    /// Withdrawal floors against the pool: the redeemed amounts never exceed the exact
    /// pro-rata share, reserves stay solvent, and balances equal reserves afterwards.
    function testFuzz_BurnRoundsDown(uint112 a0, uint112 a1) public {
        a0 = uint112(bound(a0, 1e6, 1e30));
        a1 = uint112(bound(a1, 1e6, 1e30));
        uint256 liquidity = _mintTo(alice, a0, a1);

        uint256 supply = pair.totalSupply();
        uint256 balance0 = token0.balanceOf(address(pair));
        uint256 balance1 = token1.balanceOf(address(pair));

        vm.prank(alice);
        assertTrue(pair.transfer(address(pair), liquidity));
        vm.prank(alice);
        (uint256 amount0, uint256 amount1) = pair.burn(alice);

        // exact floor division — rounding favors the pool
        assertEq(amount0, liquidity * balance0 / supply);
        assertEq(amount1, liquidity * balance1 / supply);
        assertLe(amount0 * supply, liquidity * balance0);
        assertLe(amount1 * supply, liquidity * balance1);

        // solvency: reserves track real balances, pool retains the locked-share backing
        (uint112 r0, uint112 r1,) = pair.getReserves();
        assertEq(uint256(r0), token0.balanceOf(address(pair)));
        assertEq(uint256(r1), token1.balanceOf(address(pair)));
        assertEq(uint256(r0), balance0 - amount0);
        assertEq(uint256(r1), balance1 - amount1);
    }
}
