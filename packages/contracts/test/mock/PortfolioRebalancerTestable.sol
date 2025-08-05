// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../src/PortfolioRebalancer.sol";
import "../../src/libraries/PortfolioLogicLibrary.sol";

/// This contract is used to test the PortfolioRebalancer.sol contract
/// @dev Do not deploy this contract, it is only used for testing
contract PortfolioRebalancerTestable is PortfolioRebalancer {
    function test_exceedsDeviation(uint256 pct, uint256 target, uint256 threshold) external pure returns (bool) {
        return PortfolioLogicLibrary.exceedsDeviation(pct, target, threshold);
    }

    function test_sortDescending(TokenDelta[] memory arr, uint256 count) external pure returns (TokenDelta[] memory) {
        // Add bounds checking to prevent fuzzer from causing array out-of-bounds
        if (count > arr.length) {
            count = arr.length;
        }
        PortfolioLogicLibrary.sortDescending(arr, count);
        return arr;
    }

    function test_computeDeltaUsd(uint256[] memory balances, uint256[] memory prices, uint256 totalUSD)
        external
        view
        returns (int256[] memory)
    {
        return _computeDeltaUsd(balances, prices, totalUSD);
    }
}
