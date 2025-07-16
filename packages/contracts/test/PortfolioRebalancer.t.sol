// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {PortfolioRebalancer} from "../src/PortfolioRebalancer.sol";

contract PortfolioRebalancerTest is Test {
    PortfolioRebalancer public portfolioRebalancer;

    function setUp() public {
        portfolioRebalancer = new PortfolioRebalancer();
    }

   
}
