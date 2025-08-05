// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title PortfolioStructs
 * @notice Shared data structures for portfolio management
 * @dev Contains common structs used across portfolio contracts and libraries
 */
struct TokenInfo {
    address token;
    address priceFeed; // Chainlink AggregatorV3Interface
    uint256 targetAllocation; // scaled by ALLOCATION_SCALE
}

struct PortfolioSnapshot {
    uint256[] balances;
    uint256[] prices;
    uint256 totalUSD;
}

struct TokenDelta {
    uint256 index;
    int256 usd;
}
