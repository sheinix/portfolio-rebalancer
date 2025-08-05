// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@chainlink/shared/interfaces/AggregatorV3Interface.sol";
import "../interfaces/IUniswapV3.sol";

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

    /**
     * @dev Validates that an address is not zero
     * @param addr Address to validate
     */
    function validateNonZeroAddress(address addr) internal pure {
        if (addr == address(0)) revert ZeroAddress();
    }

    /**
     * @dev Validates that treasury address is not zero
     * @param treasury Treasury address to validate
     */
    function validateTreasury(address treasury) internal pure {
        if (treasury == address(0)) revert ZeroTreasury();
    }

    /**
     * @dev Validates that factory address is not zero
     * @param factory Factory address to validate
     */
    function validateFactory(address factory) internal pure {
        if (factory == address(0)) revert ZeroFactory();
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
            uint80, /*roundId*/ 
            int256 answer, 
            uint256, /*startedAt*/ 
            uint256 updatedAt, 
            uint80 /*answeredInRound*/
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
     * @dev Validates Uniswap V3 pools exist and have liquidity for all token pairs
     * @param tokens Array of token addresses
     * @param uniswapV3Factory Uniswap V3 factory address
     * @param defaultFee Default fee tier to use
     * @return poolAddresses 2D array of pool addresses [tokenIn][tokenOut] -> pool
     */
    function validateAndGetUniswapV3Pools(
        address[] calldata tokens,
        address uniswapV3Factory,
        uint24 defaultFee
    ) internal view returns (address[][] memory poolAddresses) {
        uint256 len = tokens.length;
        poolAddresses = new address[][](len);
        
        IUniswapV3Factory factory = IUniswapV3Factory(uniswapV3Factory);
        
        for (uint256 i = 0; i < len; i++) {
            poolAddresses[i] = new address[](len);
            for (uint256 j = 0; j < len; j++) {
                if (i == j) {
                    poolAddresses[i][j] = address(0); // No pool needed for same token
                    continue;
                }
                
                address pool = factory.getPool(tokens[i], tokens[j], defaultFee);
                if (pool == address(0)) revert NoPoolForToken();
                
                uint128 liquidity = IUniswapV3Pool(pool).liquidity();
                if (liquidity == 0) revert NoLiquidityForToken();
                
                poolAddresses[i][j] = pool;
            }
        }
    }
} 