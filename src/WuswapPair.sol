// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {WuswapERC20} from "./WuswapERC20.sol";
import {ReentrancyGuardTransient} from "@openzeppelin-contracts/utils/ReentrancyGuardTransient.sol";

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

    function getReserves() public view returns (uint112 r0, uint112 r1, uint32 ts) {
        (r0, r1, ts) = (reserve0, reserve1, blockTimestampLast);
    }
}
