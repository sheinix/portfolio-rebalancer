// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@chainlink/shared/interfaces/AggregatorV3Interface.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

/**
 * @title ValidationLibrary
 * @notice Library containing common validation functions to reduce bytecode size across contracts
 * @dev Uses custom errors for gas efficiency
 */
library ValidationLibrary {
    // Custom errors
    error ZeroAddress();
    error ZeroTreasury();
    error ZeroFactory();
    error ArrayLengthMismatch();
    error InvalidPriceFeedCall(address feed);
    error InvalidPriceFeedAnswer(address feed);
    error InvalidPriceFeedUpdate(address feed);
    error NoPoolForToken();
    error NoLiquidityForToken();
    error TokenNotRoutableToWETH(address token);

    /**
     * @dev Validates that an address is not zero
     * @param addr Address to validate
     */
    function validateNonZeroAddress(address addr) internal pure {
        if (addr == address(0)) revert ZeroAddress();
    }

    /**
     * @dev Validates that multiple arrays have the same length
     * @param length1 Length of first array
     * @param length2 Length of second array
     */
    function validateArrayLengths(uint256 length1, uint256 length2) internal pure {
        if (length1 != length2) revert ArrayLengthMismatch();
    }

    /**
     * @dev Validates that three arrays have the same length
     * @param length1 Length of first array
     * @param length2 Length of second array
     * @param length3 Length of third array
     */
    function validateArrayLengths(uint256 length1, uint256 length2, uint256 length3) internal pure {
        if (length1 != length2 || length1 != length3) revert ArrayLengthMismatch();
    }

    /**
     * @dev Validates that a Chainlink price feed is working and returns valid data
     * @param priceFeed Address of the Chainlink price feed
     */
    function validatePriceFeed(address priceFeed) internal view {
        validateNonZeroAddress(priceFeed);

        try AggregatorV3Interface(priceFeed).latestRoundData() returns (
            uint80, /*roundId*/ int256 answer, uint256, /*startedAt*/ uint256 updatedAt, uint80 /*answeredInRound*/
        ) {
            if (answer <= 0) revert InvalidPriceFeedAnswer(priceFeed);
            if (updatedAt == 0) revert InvalidPriceFeedUpdate(priceFeed);
        } catch {
            revert InvalidPriceFeedCall(priceFeed);
        }
    }

    /**
     * @dev Validates multiple addresses are not zero
     * @param addresses Array of addresses to validate
     */
    function validateNonZeroAddresses(address[] calldata addresses) internal pure {
        uint256 length = addresses.length;
        for (uint256 i = 0; i < length; i++) {
            validateNonZeroAddress(addresses[i]);
        }
    }

    /**
     * @dev Validates multiple price feeds
     * @param priceFeeds Array of price feed addresses to validate
     */
    function validatePriceFeeds(address[] calldata priceFeeds) internal view {
        uint256 length = priceFeeds.length;
        for (uint256 i = 0; i < length; i++) {
            validatePriceFeed(priceFeeds[i]);
        }
    }

    /**
     * @dev Validates that tokens have minimal routing connectivity via WETH
     * @notice This can ensure at least tokens can hop to WETH and back to the token
     * @param tokens Array of token addresses to validate
     * @param uniswapV3Factory Uniswap V3 factory address
     * @param weth WETH token address for routing validation
     */
    function validateMinimalLiquidity(address[] calldata tokens, address uniswapV3Factory, address weth)
        internal
        view
    {
        validateNonZeroAddress(weth);
        IUniswapV3Factory factory = IUniswapV3Factory(uniswapV3Factory);

        // Common fee tiers in Uniswap V3 (0.05%, 0.3%, 1.0%)
        uint24[3] memory fees = [uint24(500), uint24(3_000), uint24(10_000)];

        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == weth) continue; // WETH doesn't need routing to itself

            bool hasWethPool = false;

            // Check all common fee tiers for WETH pair
            for (uint256 j = 0; j < fees.length; j++) {
                address pool = factory.getPool(tokens[i], weth, fees[j]);
                if (pool != address(0) && IUniswapV3Pool(pool).liquidity() > 0) {
                    hasWethPool = true;
                    break;
                }
            }

            if (!hasWethPool) revert TokenNotRoutableToWETH(tokens[i]);
        }
    }
}
