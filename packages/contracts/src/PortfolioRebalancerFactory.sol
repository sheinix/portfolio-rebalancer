// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title PortfolioRebalancerFactory
 * @notice Deploys user-owned PortfolioRebalancer proxies (vaults) with custom baskets and settings.
 */
contract PortfolioRebalancerFactory {
    address public immutable implementation;

    event VaultCreated(address indexed user, address proxy);

    constructor(address _implementation) {
        implementation = _implementation;
    }

    /**
     * @notice Deploy a new PortfolioRebalancer vault for the user.
     * @param tokens ERC-20 token addresses.
     * @param priceFeeds Chainlink price feed addresses for each token.
     * @param allocations Target allocations (scaled by ALLOCATION_SCALE, sum == ALLOCATION_SCALE).
     * @param rebalanceThreshold Allowed deviation before auto-rebalance (e.g. 10,000 = 1%).
     * @param uniswapV4Factory Uniswap V4 factory address.
     * @return proxy The address of the new proxy vault.
     */
    function createVault(
        address[] calldata tokens,
        address[] calldata priceFeeds,
        uint256[] calldata allocations,
        uint256 rebalanceThreshold,
        address uniswapV4Factory
    ) external returns (address proxy) {
        bytes memory data = abi.encodeWithSignature(
            "initialize(address[],address[],uint256[],uint256,address)",
            tokens,
            priceFeeds,
            allocations,
            rebalanceThreshold,
            uniswapV4Factory
        );
        proxy = address(new ERC1967Proxy(implementation, data));
        emit VaultCreated(msg.sender, proxy);
    }
} 