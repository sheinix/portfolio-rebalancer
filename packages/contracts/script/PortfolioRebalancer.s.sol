// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {PortfolioRebalancer} from "../src/PortfolioRebalancer.sol";

contract DeployPortfolioRebalancer is Script {
    PortfolioRebalancer public portfolioRebalancer;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        portfolioRebalancer = new PortfolioRebalancer();

        vm.stopBroadcast();
    }
}
