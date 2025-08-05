// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract MockUniswapV3Factory {
    function getPool(address, address, uint24) external pure returns (address) {
        return address(0x1234); // Return mock pool address
    }
}
