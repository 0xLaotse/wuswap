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
    address internal bob = makeAddr("bob");

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

    /// First liquidity provider receives sqrt(a0*a1) - MINIMUM_LIQUIDITY shares; the
    /// 1000 floor shares are minted to address(0) and locked forever.
    function test_FirstMint_LocksMinimumLiquidity() public {
        token0.mint(address(pair), 1e18);
        token1.mint(address(pair), 4e18);

        uint256 liquidity = pair.mint(alice);

        assertEq(liquidity, 2e18 - 1000); // sqrt(1e18 * 4e18) - 1000
        assertEq(pair.balanceOf(alice), 2e18 - 1000);
        assertEq(pair.balanceOf(address(0)), 1000); // permanently locked
        assertEq(pair.totalSupply(), 2e18);
        (uint112 r0, uint112 r1,) = pair.getReserves();
        assertEq(uint256(r0) * r1, 4e36);
    }

    /// Off-ratio deposits are credited by the scarcer side only (the min rule); the
    /// surplus of the richer side accrues to the pool, not to the depositor's shares.
    function test_SecondMint_ProportionalViaMin() public {
        token0.mint(address(pair), 1e18);
        token1.mint(address(pair), 4e18);
        pair.mint(alice); // supply 2e18, reserves (1e18, 4e18)

        // deposit token0 proportionally but oversupply token1 2x
        token0.mint(address(pair), 1e18);
        token1.mint(address(pair), 8e18);
        uint256 liquidity = pair.mint(bob);

        // min(1e18 * 2e18 / 1e18, 8e18 * 2e18 / 4e18) = min(2e18, 4e18) — token0 binds
        assertEq(liquidity, 2e18);
        assertEq(pair.balanceOf(bob), 2e18);
    }

    function test_RevertWhen_ZeroLiquidityMinted() public {
        token0.mint(address(pair), 1e18);
        token1.mint(address(pair), 4e18);
        pair.mint(alice);

        // a single wei on one side rounds to zero shares against the standing supply
        token0.mint(address(pair), 1);
        vm.expectRevert(WuswapPair.InsufficientLiquidityMinted.selector);
        pair.mint(bob);
    }

    /// Minted shares never exceed either single-sided proportional entitlement —
    /// the pool can only ever round a depositor down, never up.
    function testFuzz_MintNeverExceedsProportionalShare(uint112 a0, uint112 a1) public {
        a0 = uint112(bound(a0, 1001, 1e33));
        a1 = uint112(bound(a1, 1001, 1e33));
        token0.mint(address(pair), 1e18);
        token1.mint(address(pair), 4e18);
        pair.mint(alice);

        uint256 supply = pair.totalSupply();
        (uint112 r0, uint112 r1,) = pair.getReserves();

        token0.mint(address(pair), a0);
        token1.mint(address(pair), a1);
        uint256 liquidity = pair.mint(bob);

        assertLe(liquidity, uint256(a0) * supply / r0);
        assertLe(liquidity, uint256(a1) * supply / r1);
    }
}
