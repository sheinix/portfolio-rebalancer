// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin-upgradeable/access/AccessControlUpgradeable.sol";
import "./interfaces/IPortfolioRebalancer.sol";
import "./PortfolioTreasury.sol";

/**
 * @title PortfolioRebalancerFactory
 * @notice Deploys user-owned PortfolioRebalancer proxies (vaults) with custom baskets, fees, and treasury. Admin controls parameters.
 * @dev UUPS upgradeable factory that deploys transparent proxies for gas efficiency.
 */
contract PortfolioRebalancerFactory is Initializable, UUPSUpgradeable, AccessControlUpgradeable {
    address public implementation;
    address public treasury;
    uint256 public feeBps;
    ProxyAdmin public proxyAdmin;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    event VaultCreated(address indexed user, address proxy, uint256 indexed upkeepId);

    /**
     * @notice Initialize factory with implementation, treasury, fee, admin, and proxy admin.
     * @param _implementation PortfolioRebalancer implementation address
     * @param _treasury Treasury address
     * @param _feeBps Fee in basis points
     * @param admin Admin address
     * @param _proxyAdmin ProxyAdmin contract for managing transparent proxies
     */
    function initialize(address _implementation, address _treasury, uint256 _feeBps, address admin, address _proxyAdmin)
        external
        initializer
    {
        __UUPSUpgradeable_init();
        __AccessControl_init();

        implementation = _implementation;
        treasury = _treasury;
        feeBps = _feeBps;
        proxyAdmin = ProxyAdmin(_proxyAdmin);

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
    }

    /**
     * @notice Update implementation address. Only ADMIN.
     * @param newImplementation New implementation address
     */
    function setImplementation(address newImplementation) external onlyRole(ADMIN_ROLE) {
        implementation = newImplementation;
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
     * @notice Deploy a new PortfolioRebalancer vault for the user with Chainlink Automation.
     * @param tokens ERC-20 token addresses.
     * @param priceFeeds Chainlink price feed addresses for each token.
     * @param allocations Target allocations (scaled by ALLOCATION_SCALE, sum == ALLOCATION_SCALE).
     * @param rebalanceThreshold Allowed deviation before auto-rebalance (e.g. 10,000 = 1%).
     * @param uniswapV3Factory Uniswap V3 factory address.
     * @param gasLimit Gas limit for automation performUpkeep calls.
     * @param linkAmount Amount of LINK to fund the automation upkeep.
     * @return proxy The address of the new proxy vault.
     */
    function createVault(
        address[] calldata tokens,
        address[] calldata priceFeeds,
        uint256[] calldata allocations,
        uint256 rebalanceThreshold,
        address uniswapV3Factory,
        address uniswapV3SwapRouter,
        address weth,
        uint32 gasLimit,
        uint96 linkAmount
    ) external returns (address proxy) {
        bytes memory data = abi.encodeWithSelector(
            IPortfolioRebalancer.initialize.selector,
            tokens,
            priceFeeds,
            allocations,
            rebalanceThreshold,
            uniswapV3Factory,
            uniswapV3SwapRouter,
            weth,
            feeBps,
            treasury,
            msg.sender
        );
        proxy = address(new TransparentUpgradeableProxy(implementation, address(proxyAdmin), data));

        // Register vault with Chainlink Automation via treasury
        uint256 upkeepId = PortfolioTreasury(treasury).registerAndFundUpkeep(
            proxy,
            abi.encodePacked(proxy), // Simple checkData encoding vault address
            gasLimit,
            linkAmount
        );

        emit VaultCreated(msg.sender, proxy, upkeepId);
    }

    /**
     * @notice Upgrade a user's vault implementation. Only ADMIN.
     * @param vault The vault proxy address to upgrade
     * @param newImplementation New implementation address
     */
    function upgradeVault(address vault, address newImplementation) external onlyRole(ADMIN_ROLE) {
        proxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(vault), newImplementation, "");
    }

    /**
     * @notice Upgrade a user's vault implementation with call. Only ADMIN.
     * @param vault The vault proxy address to upgrade
     * @param newImplementation New implementation address
     * @param data Call data to execute after upgrade
     */
    function upgradeVaultAndCall(address vault, address newImplementation, bytes calldata data)
        external
        onlyRole(ADMIN_ROLE)
    {
        proxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(vault), newImplementation, data);
    }

    /**
     * @dev Authorizes contract upgrades. Only ADMIN can upgrade the factory.
     */
    function _authorizeUpgrade(address) internal override onlyRole(ADMIN_ROLE) {}
}
