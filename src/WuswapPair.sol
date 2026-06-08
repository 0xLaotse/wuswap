// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {WuswapERC20} from "./WuswapERC20.sol";
import {ReentrancyGuardTransient} from "@openzeppelin-contracts/utils/ReentrancyGuardTransient.sol";
import {IWuswapFactory} from "./interfaces/IWuswapFactory.sol";
import {IERC20Minimal} from "./interfaces/IERC20Minimal.sol";
import {Math} from "./libraries/Math.sol";

/// @title wuswap pair — constant-product market maker for a token pair
/// @notice Holds reserves of token0/token1, mints LP shares against deposits,
///         prices swaps along x*y >= k (fees accrete to k).
contract WuswapPair is WuswapERC20, ReentrancyGuardTransient {
    error InsufficientLiquidityMinted();
    error InsufficientLiquidityBurned();
    error InsufficientOutputAmount();
    error InsufficientInputAmount();
    error InsufficientLiquidity();
    error InvalidTo();
    error KInvariantViolated();
    error BalanceOverflow();

    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    uint256 public constant MINIMUM_LIQUIDITY = 1e3;

    address public immutable factory;
    address public immutable token0;
    address public immutable token1;

    // single-slot: 2x uint112 + uint32 = 256 bits — one SLOAD per swap
    uint112 private reserve0;
    uint112 private reserve1;
    uint32 private blockTimestampLast;

    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;
    uint256 public kLast;

    constructor(address _token0, address _token1) {
        factory = msg.sender;
        token0 = _token0;
        token1 = _token1;
    }

    /// @notice Mint LP shares for tokens already transferred into the pair.
    /// @dev Deposit-then-call: the credited amounts are the balance delta over stored
    ///      reserves, so a router (or the caller) must move the tokens in first. The first
    ///      mint locks MINIMUM_LIQUIDITY shares to address(0); later mints take the min of
    ///      both sides, so an off-ratio deposit is always rounded down, never up.
    /// @param to recipient of the freshly minted LP shares
    /// @return liquidity LP shares minted to `to`
    function mint(address to) external nonReentrant returns (uint256 liquidity) {
        (uint112 r0, uint112 r1,) = getReserves();
        uint256 balance0 = IERC20Minimal(token0).balanceOf(address(this));
        uint256 balance1 = IERC20Minimal(token1).balanceOf(address(this));
        uint256 amount0 = balance0 - r0;
        uint256 amount1 = balance1 - r1;

        bool feeOn = _mintFee(r0, r1);
        uint256 supply = totalSupply(); // read after _mintFee — it may have minted fee shares
        if (supply == 0) {
            liquidity = Math.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            // 1000 shares burned forever: floors the share price so the first LP cannot
            // inflate it via donation and round later depositors down to zero shares.
            _mint(address(0), MINIMUM_LIQUIDITY);
        } else {
            liquidity = Math.min(amount0 * supply / r0, amount1 * supply / r1);
        }
        if (liquidity == 0) revert InsufficientLiquidityMinted();
        _mint(to, liquidity);

        _update(balance0, balance1, r0, r1);
        if (feeOn) kLast = uint256(reserve0) * reserve1;
        emit Mint(msg.sender, amount0, amount1);
    }

    function getReserves() public view returns (uint112 r0, uint112 r1, uint32 ts) {
        (r0, r1, ts) = (reserve0, reserve1, blockTimestampLast);
    }

    function _update(uint256 balance0, uint256 balance1, uint112, uint112) private {
        if (balance0 > type(uint112).max || balance1 > type(uint112).max) revert BalanceOverflow();
        // TWAP price accumulators are wired into _update in a later PR — kept minimal here.
        // safe: the guard above bounds both balances to uint112.
        // forge-lint: disable-next-line(unsafe-typecast)
        reserve0 = uint112(balance0);
        // safe: same uint112 guard.
        // forge-lint: disable-next-line(unsafe-typecast)
        reserve1 = uint112(balance1);
        // wraps by design: uint32 timestamps are modular; consumers read deltas, not the
        // absolute value. The TWAP oracle PR makes the wrap explicit with an unchecked block.
        // forge-lint: disable-next-line(unsafe-typecast)
        blockTimestampLast = uint32(block.timestamp);
        emit Sync(reserve0, reserve1);
    }

    function _mintFee(uint112 r0, uint112 r1) private returns (bool feeOn) {
        address feeTo = IWuswapFactory(factory).feeTo();
        feeOn = feeTo != address(0);
        uint256 k = kLast;
        if (feeOn) {
            if (k != 0) {
                uint256 rootK = Math.sqrt(uint256(r0) * r1);
                uint256 rootKLast = Math.sqrt(k);
                if (rootK > rootKLast) {
                    // protocol takes 1/6 of k-growth since the last fee event, paid in LP shares
                    uint256 numerator = totalSupply() * (rootK - rootKLast);
                    uint256 denominator = 5 * rootK + rootKLast;
                    uint256 fee = numerator / denominator;
                    if (fee > 0) _mint(feeTo, fee);
                }
            }
        } else if (k != 0) {
            kLast = 0;
        }
    }
}
