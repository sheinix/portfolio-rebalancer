// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/IPortfolioRebalancer.sol";

/**
 * @title PortfolioRebalancerFactory
 * @notice Deploys user-owned PortfolioRebalancer proxies (vaults) with custom baskets, fees, and treasury. Admin controls parameters.
 */
contract PortfolioRebalancerFactory is AccessControl {
    address public immutable implementation;
    address public treasury;
    uint256 public feeBps;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    event VaultCreated(address indexed user, address proxy);

    /**
     * @notice Initialize factory with implementation, treasury, fee, and admin.
     * @param _implementation PortfolioRebalancer implementation address
     * @param _treasury Treasury address
     * @param _feeBps Fee in basis points
     * @param admin Admin address
     */
    constructor(address _implementation, address _treasury, uint256 _feeBps, address admin) {
        implementation = _implementation;
        treasury = _treasury;
        feeBps = _feeBps;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
    }

    /**
     * @notice Update treasury address. Only ADMIN.
     * @param newTreasury New treasury address
     */
    function setTreasury(address newTreasury) external onlyRole(ADMIN_ROLE) {
        treasury = newTreasury;
    }

    /**
     * @notice Update fee in basis points. Only ADMIN.
     * @param newFeeBps New fee (max 10%)
     */
    function setFeeBps(uint256 newFeeBps) external onlyRole(ADMIN_ROLE) {
        require(newFeeBps <= 1000, "Fee too high");
        feeBps = newFeeBps;
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
        bytes memory data = abi.encodeWithSelector(
            IPortfolioRebalancer.initialize.selector,
            tokens,
            priceFeeds,
            allocations,
            rebalanceThreshold,
            uniswapV4Factory,
            feeBps,
            treasury
        );
        proxy = address(new ERC1967Proxy(implementation, data));
        emit VaultCreated(msg.sender, proxy);
    }
} 