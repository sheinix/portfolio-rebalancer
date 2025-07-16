// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Minimal Uniswap V4 pool factory interface
interface IUniswapV4PoolFactory {
    function getPool(address tokenA, address tokenB) external view returns (address);
}

/// @notice Minimal Uniswap V4 pool interface
interface IUniswapV4Pool {
    function liquidity() external view returns (uint128);
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);
} 