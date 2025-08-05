// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";

/**
 * @title QueryDeployments
 * @notice Utility script to query deployment information from addressBook files
 * @dev Useful for getting contract addresses for integration, testing, or verification
 */
contract QueryDeployments is Script {
    function setUp() public {}

    /**
     * @notice Query all deployment info for current chain
     */
    function run() public view {
        uint256 chainId = block.chainid;
        _queryChain(chainId);
    }

    /**
     * @notice Query deployment info for specific chain
     * @param chainId Target chain ID
     */
    function queryChain(uint256 chainId) public view {
        _queryChain(chainId);
    }

    /**
     * @notice Get factory address for current chain
     * @return factory Factory proxy address
     */
    function getFactory() public view returns (address factory) {
        uint256 chainId = block.chainid;
        return _getFactory(chainId);
    }

    /**
     * @notice Get factory address for specific chain
     * @param chainId Target chain ID
     * @return factory Factory proxy address
     */
    function getFactory(uint256 chainId) public view returns (address factory) {
        return _getFactory(chainId);
    }

    /**
     * @notice Get treasury address for current chain
     * @return treasury Treasury proxy address
     */
    function getTreasury() public view returns (address treasury) {
        uint256 chainId = block.chainid;
        return _getTreasury(chainId);
    }

    /**
     * @notice Get treasury address for specific chain
     * @param chainId Target chain ID
     * @return treasury Treasury proxy address
     */
    function getTreasury(uint256 chainId) public view returns (address treasury) {
        return _getTreasury(chainId);
    }

    /**
     * @notice Get all key addresses for current chain
     * @return factory Factory proxy address
     * @return treasury Treasury proxy address
     * @return proxyAdmin ProxyAdmin address
     */
    function getKeyAddresses() public view returns (address factory, address treasury, address proxyAdmin) {
        uint256 chainId = block.chainid;
        return _getKeyAddresses(chainId);
    }

    /**
     * @notice Get all key addresses for specific chain
     * @param chainId Target chain ID
     * @return factory Factory proxy address
     * @return treasury Treasury proxy address
     * @return proxyAdmin ProxyAdmin address
     */
    function getKeyAddresses(uint256 chainId)
        public
        view
        returns (address factory, address treasury, address proxyAdmin)
    {
        return _getKeyAddresses(chainId);
    }

    // Internal functions

    function _queryChain(uint256 chainId) internal view {
        string memory filename = string.concat("addressBook/", vm.toString(chainId), ".json");

        try vm.readFile(filename) returns (string memory json) {
            console.log("=== Portfolio Rebalancer Deployment Info ===");
            console.log("Chain ID:", chainId);
            console.log("Network:", vm.parseJsonString(json, ".network"));
            console.log("");

            console.log("=== Key Contract Addresses ===");
            console.log("Factory Proxy:", vm.parseJsonAddress(json, ".portfolioRebalancer.factory"));
            console.log("Treasury Proxy:", vm.parseJsonAddress(json, ".portfolioRebalancer.treasury"));
            console.log("ProxyAdmin:", vm.parseJsonAddress(json, ".portfolioRebalancer.proxyAdmin"));
            console.log("");

            console.log("=== Implementation Addresses ===");
            console.log("Portfolio Implementation:", vm.parseJsonAddress(json, ".portfolioRebalancer.implementation"));
            console.log(
                "Factory Implementation:", vm.parseJsonAddress(json, ".portfolioRebalancer.factoryImplementation")
            );
            console.log(
                "Treasury Implementation:", vm.parseJsonAddress(json, ".portfolioRebalancer.treasuryImplementation")
            );
            console.log("");

            console.log("=== Deployment Metadata ===");
            console.log("Main Deployment Block:", vm.parseJsonUint(json, ".portfolioRebalancer.deploymentBlock"));
            console.log(
                "Main Deployment Timestamp:", vm.parseJsonUint(json, ".portfolioRebalancer.deploymentTimestamp")
            );
            console.log(
                "Treasury Deployment Block:", vm.parseJsonUint(json, ".portfolioRebalancer.treasuryDeploymentBlock")
            );
            console.log(
                "Treasury Deployment Timestamp:",
                vm.parseJsonUint(json, ".portfolioRebalancer.treasuryDeploymentTimestamp")
            );
            console.log("");

            console.log("=== External Dependencies ===");
            console.log("LINK Token:", vm.parseJsonAddress(json, ".coins.LINK"));
            console.log("USDC Token:", vm.parseJsonAddress(json, ".coins.USDC"));
            console.log("WETH Token:", vm.parseJsonAddress(json, ".coins.WETH"));
            console.log("Uniswap V4 Router:", vm.parseJsonAddress(json, ".uniswap.uniswapV4Router"));
            console.log("");

            console.log("=== Integration Commands ===");
            console.log("# Create a new vault:");
            console.log(
                "cast call",
                vm.parseJsonAddress(json, ".portfolioRebalancer.factory"),
                '"createVault(address[],address[],uint256[],uint256,address)"'
            );
            console.log("");
            console.log("# Check treasury balance:");
            console.log(
                "cast call",
                vm.parseJsonAddress(json, ".coins.LINK"),
                '"balanceOf(address)"',
                vm.parseJsonAddress(json, ".portfolioRebalancer.treasury")
            );
        } catch {
            console.log("Error: AddressBook not found for chain ID:", chainId);
            console.log("Expected file:", filename);
            console.log("Make sure to deploy contracts first or check if chain ID is supported.");
        }
    }

    function _getFactory(uint256 chainId) internal view returns (address factory) {
        string memory filename = string.concat("addressBook/", vm.toString(chainId), ".json");
        string memory json = vm.readFile(filename);
        return vm.parseJsonAddress(json, ".portfolioRebalancer.factory");
    }

    function _getTreasury(uint256 chainId) internal view returns (address treasury) {
        string memory filename = string.concat("addressBook/", vm.toString(chainId), ".json");
        string memory json = vm.readFile(filename);
        return vm.parseJsonAddress(json, ".portfolioRebalancer.treasury");
    }

    function _getKeyAddresses(uint256 chainId)
        internal
        view
        returns (address factory, address treasury, address proxyAdmin)
    {
        string memory filename = string.concat("addressBook/", vm.toString(chainId), ".json");
        string memory json = vm.readFile(filename);

        factory = vm.parseJsonAddress(json, ".portfolioRebalancer.factory");
        treasury = vm.parseJsonAddress(json, ".portfolioRebalancer.treasury");
        proxyAdmin = vm.parseJsonAddress(json, ".portfolioRebalancer.proxyAdmin");
    }
}
