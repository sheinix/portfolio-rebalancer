// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "solmate/utils/FixedPointMathLib.sol";
import "@chainlink/shared/interfaces/AggregatorV3Interface.sol";
import "./PortfolioStructs.sol";

/**
 * @title PortfolioLogicLibrary
 * @notice Library containing computational logic for portfolio management
 * @dev Pure/view functions that don't modify storage, optimized for gas efficiency and testability
 */
library PortfolioLogicLibrary {
    using FixedPointMathLib for uint256;

    // Constants
    uint256 public constant ALLOCATION_SCALE = 1_000_000; // 100% = 1,000,000

    // Custom errors
    error PriceFeedError();

    /**
     * @dev Checks if user's portfolio deviates from target allocations beyond threshold
     * @param basket Array of token information
     * @param userBalances Array of user balances for each token (extracted from mapping)
     * @param rebalanceThreshold Deviation threshold to trigger rebalance
     * @return needsRebalancing Whether portfolio needs rebalancing
     * @return snapshot Portfolio data snapshot for reuse
     */
    function needsRebalance(
        TokenInfo[] memory basket,
        uint256[] memory userBalances,
        uint256 rebalanceThreshold
    ) internal view returns (bool needsRebalancing, PortfolioSnapshot memory snapshot) {
        uint256 len = basket.length;
        uint256[] memory balances = new uint256[](len);
        uint256[] memory prices = new uint256[](len);
        uint256 totalUSD = 0;
        bool needs = false;

        // Get prices and use provided balances
        for (uint256 i = 0; i < len; i++) {
            balances[i] = userBalances[i];
            prices[i] = getLatestPrice(basket[i].priceFeed);
            totalUSD += balances[i].mulWadDown(prices[i]);
        }

        // Check for deviations
        for (uint256 i = 0; i < len; i++) {
            uint256 value = balances[i].mulWadDown(prices[i]);
            uint256 pct = value == 0 ? 0 : value.divWadDown(totalUSD);
            uint256 target = basket[i].targetAllocation;
            if (exceedsDeviation(pct, target, rebalanceThreshold)) {
                needs = true;
                break;
            }
        }

        return (needs, PortfolioSnapshot(balances, prices, totalUSD));
    }

    /**
     * @dev Computes the USD delta for each token: currentUsd - targetUsd
     * @param basket Array of token information
     * @param balances Token balances array
     * @param prices Token prices array  
     * @param totalUSD Total portfolio value in USD
     * @return deltas Array of USD deltas for each token
     */
    function computeDeltaUsd(
        TokenInfo[] memory basket,
        uint256[] memory balances,
        uint256[] memory prices,
        uint256 totalUSD
    ) internal pure returns (int256[] memory deltas) {
        uint256 len = basket.length;
        deltas = new int256[](len);
        
        for (uint256 i = 0; i < len; i++) {
            uint256 currentUsd = balances[i].mulWadDown(prices[i]);
            uint256 targetUsd = (totalUSD * basket[i].targetAllocation) / ALLOCATION_SCALE;
            deltas[i] = int256(currentUsd) - int256(targetUsd);
        }
    }

    /**
     * @dev Sorts TokenDelta array in-place by usd descending, up to count elements
     * @param arr Array of TokenDelta structs to sort
     * @param count Number of elements to sort
     */
    function sortDescending(TokenDelta[] memory arr, uint256 count) internal pure {
        for (uint256 i = 0; i < count; i++) {
            uint256 maxIdx = i;
            for (uint256 j = i + 1; j < count; j++) {
                if (arr[j].usd > arr[maxIdx].usd) {
                    maxIdx = j;
                }
            }
            if (maxIdx != i) {
                TokenDelta memory tmp = arr[i];
                arr[i] = arr[maxIdx];
                arr[maxIdx] = tmp;
            }
        }
    }

    /**
     * @dev Calculates the total USD value of a user's portfolio
     * @param basket Array of token information
     * @param userBalances Array of user balances for each token (extracted from mapping)
     * @return total Total portfolio value in USD
     */
    function portfolioValueUSD(
        TokenInfo[] memory basket,
        uint256[] memory userBalances
    ) internal view returns (uint256 total) {
        for (uint256 i = 0; i < basket.length; i++) {
            TokenInfo memory info = basket[i];
            uint256 bal = userBalances[i];
            if (bal == 0) continue;
            uint256 price = getLatestPrice(info.priceFeed);
            total += bal.mulWadDown(price);
        }
    }

    /**
     * @dev Fetches latest price from Chainlink price feed (returns 1e18 USD per token)
     * @param priceFeed Address of the Chainlink price feed
     * @return price Price normalized to 18 decimals
     */
    function getLatestPrice(address priceFeed) internal view returns (uint256 price) {
        (, int256 answer,,,) = AggregatorV3Interface(priceFeed).latestRoundData();
        if (answer <= 0) revert PriceFeedError();
        
        // Normalize to 1e18
        uint8 decimals = AggregatorV3Interface(priceFeed).decimals();
        price = uint256(answer) * (10 ** (18 - decimals));
    }

    /**
     * @dev Returns true if the deviation between actual and target allocation exceeds the threshold
     * @param pct Current allocation percentage
     * @param target Target allocation percentage  
     * @param threshold Deviation threshold
     * @return exceeds Whether deviation exceeds threshold
     */
    function exceedsDeviation(uint256 pct, uint256 target, uint256 threshold) 
        internal 
        pure 
        returns (bool exceeds) 
    {
        uint256 deviation = pct > target ? pct - target : target - pct;
        exceeds = deviation > threshold;
    }
}