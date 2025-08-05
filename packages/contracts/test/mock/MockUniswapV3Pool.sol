// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract MockUniswapV3Pool {
    function liquidity() external pure returns (uint128) {
        return 1e18; // Mock liquidity > 0
    }
}