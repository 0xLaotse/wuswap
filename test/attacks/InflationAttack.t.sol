// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {WuswapPair} from "src/WuswapPair.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {FactoryStub} from "test/mocks/FactoryStub.sol";

/// The first-depositor inflation attack mints a single all-powerful LP share and then
/// inflates its value so later deposits round to zero. wuswap burns MINIMUM_LIQUIDITY
/// (1000) shares to address(0) on the first mint, which floors the share supply and
/// makes that attack uneconomical. These tests pin the parts provable today; the full
/// reserve-inflation simulation needs sync() and lands with DonationAttack.t.sol.
contract InflationAttackTest is Test {
    FactoryStub internal factory;
    WuswapPair internal pair;
    MockERC20 internal token0;
    MockERC20 internal token1;

    address internal attacker = makeAddr("attacker");
    address internal alice = makeAddr("alice");

    function setUp() public {
        MockERC20 tokenA = new MockERC20("Token A", "TKA", 18);
        MockERC20 tokenB = new MockERC20("Token B", "TKB", 18);
        (token0, token1) = address(tokenA) < address(tokenB) ? (tokenA, tokenB) : (tokenB, tokenA);
        factory = new FactoryStub();
        pair = factory.createPair(address(token0), address(token1));
    }

    /// An attacker seeding the pool with the bare minimum walks away with at most a
    /// single share — the other 1000 are locked at address(0) forever. There is no
    /// "1 share owns the whole pool" position to inflate from.
    function test_FirstMint_LocksMinimumLiquidity_FloorsAttackerShare() public {
        token0.mint(address(pair), 1001);
        token1.mint(address(pair), 1001);

        vm.prank(attacker);
        uint256 attackerLp = pair.mint(attacker);

        assertEq(attackerLp, 1); // sqrt(1001*1001) - 1000
        assertEq(pair.balanceOf(address(0)), 1000); // locked, unrecoverable
        assertEq(pair.totalSupply(), 1001);
        assertLt(attackerLp, pair.MINIMUM_LIQUIDITY()); // attacker share dwarfed by the locked floor
    }

    /// Pre-sync, a raw token donation is not reflected in reserves — the next mint()
    /// reads it as the caller's own deposit and credits it to THEM. So an attacker
    /// cannot strand an honest depositor by donating before they mint; the donation is
    /// gifted to the victim instead. The reserve-inflation path requires sync(), which
    /// is exactly why the full simulation is deferred.
    // TODO(flash-pr): once sync() exists, fold the donation into reserves and assert the
    // MINIMUM_LIQUIDITY floor still leaves the victim with > 0 shares (DonationAttack.t.sol).
    function test_PreSyncDonation_CreditedToNextMinter_NotStranding() public {
        // attacker seeds minimally
        token0.mint(address(pair), 1001);
        token1.mint(address(pair), 1001);
        vm.prank(attacker);
        pair.mint(attacker);

        // attacker donates directly to the pair, hoping to inflate the share price
        token0.mint(address(pair), 500e18);
        token1.mint(address(pair), 500e18);

        // honest depositor adds real liquidity on top
        token0.mint(address(pair), 1000e18);
        token1.mint(address(pair), 1000e18);
        vm.prank(alice);
        uint256 aliceLp = pair.mint(alice);

        // alice is credited the donation (500e18) plus her own deposit (1000e18): the
        // attacker's "donation" lands in her pocket, not in a price she gets stranded by.
        assertEq(aliceLp, 1500e18);
        assertGt(aliceLp, 0);
    }
}
