// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IPortfolioRebalancer {
    function initialize(
        address[] calldata tokens,
        address[] calldata priceFeeds,
        uint256[] calldata allocations,
        uint256 rebalanceThreshold,
        address uniswapV3Factory,
        address uniswapV3SwapRouter,
        address weth,
        uint256 feeBps,
        address treasury,
        address owner
    ) external;
}
