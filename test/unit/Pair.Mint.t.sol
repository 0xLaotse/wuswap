// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {WuswapPair} from "src/WuswapPair.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {FactoryStub} from "test/mocks/FactoryStub.sol";

contract PairMintTest is Test {
    FactoryStub internal factory;
    WuswapPair internal pair;
    MockERC20 internal token0;
    MockERC20 internal token1;

    address internal alice = makeAddr("alice");

    function setUp() public {
        MockERC20 tokenA = new MockERC20("Token A", "TKA", 18);
        MockERC20 tokenB = new MockERC20("Token B", "TKB", 18);
        // mirror the factory's token0 < token1 ordering
        (token0, token1) = address(tokenA) < address(tokenB) ? (tokenA, tokenB) : (tokenB, tokenA);
        // deploy via a stub: mint() reads factory.feeTo(), so the pair needs a real factory
        factory = new FactoryStub();
        pair = factory.createPair(address(token0), address(token1));
    }

    function test_LpMetadata() public view {
        assertEq(pair.name(), "Wuswap LP Token");
        assertEq(pair.symbol(), "WLP");
    }

    function test_ReservesStartEmpty() public view {
        (uint112 r0, uint112 r1, uint32 ts) = pair.getReserves();
        assertEq(r0, 0);
        assertEq(r1, 0);
        assertEq(ts, 0);
    }

    function test_MinimumLiquidityConstant() public view {
        assertEq(pair.MINIMUM_LIQUIDITY(), 1000);
    }

    function test_TokensWired() public view {
        assertEq(pair.token0(), address(token0));
        assertEq(pair.token1(), address(token1));
    }

    function test_FactoryIsDeployer() public view {
        assertEq(pair.factory(), address(factory));
    }
}
