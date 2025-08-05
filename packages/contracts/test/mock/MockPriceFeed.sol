// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract MockPriceFeed {
    int256 private price;
    
    constructor(int256 _price) {
        price = _price;
    }
    
    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) {
        return (1, price, block.timestamp, block.timestamp, 1);
    }
    
    function decimals() external pure returns (uint8) {
        return 18;
    }
} 