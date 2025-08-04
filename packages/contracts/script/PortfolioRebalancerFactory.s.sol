// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {PortfolioRebalancer} from "../src/PortfolioRebalancer.sol";
import {PortfolioRebalancerFactory} from "../src/PortfolioRebalancerFactory.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployPortfolioRebalancerFactory is Script {
    PortfolioRebalancer public implementation;
    PortfolioRebalancerFactory public factory;
    ProxyAdmin public proxyAdmin;
    ERC1967Proxy public factoryProxy;

    function setUp() public {}

    /**
     * @notice Deploy factory system using current chain's treasury
     */
    function run() public returns (address factoryAddress) {
        uint256 chainId = block.chainid;
        
        // Read treasury address from addressBook
        string memory filename = string.concat("addressBook/", vm.toString(chainId), ".json");
        console.log("Reading treasury address from:", filename);
        string memory json = vm.readFile(filename);
        
        address treasuryAddress = vm.parseJsonAddress(json, ".portfolioRebalancer.treasury");
        address admin = tx.origin; // Use actual deployer EOA, not script contract
        
        console.log("Treasury address from addressBook:", treasuryAddress);
        console.log("Factory admin:", admin);
        
        return _deployFactoryCore(chainId, treasuryAddress, admin);
    }

    /**
     * @notice Deploy factory system with custom treasury address
     * @param treasuryAddress Treasury proxy address to use
     * @return factoryAddress The deployed factory proxy address
     */
    function deployWithTreasury(address treasuryAddress) public returns (address factoryAddress) {
        uint256 chainId = block.chainid;
        address admin = tx.origin; // Use actual deployer EOA, not script contract
        
        console.log("Deploying with custom treasury address");
        console.log("Treasury address:", treasuryAddress);
        console.log("Factory admin:", admin);
        
        return _deployFactoryCore(chainId, treasuryAddress, admin);
    }

    /**
     * @notice Deploy factory system with custom parameters
     * @param treasuryAddress Treasury proxy address
     * @param admin Factory admin address
     * @param feeBps Fee in basis points
     * @return factoryAddress The deployed factory proxy address
     */
    function deployWithParams(
        address treasuryAddress,
        address admin,
        uint256 feeBps
    ) public returns (address factoryAddress) {
        uint256 chainId = block.chainid;
        
        console.log("Deploying with custom parameters");
        console.log("Treasury address:", treasuryAddress);
        console.log("Factory admin:", admin);
        console.log("Fee BPS:", feeBps);
        
        return _deployFactoryCoreWithFee(chainId, treasuryAddress, admin, feeBps);
    }

    /**
     * @notice Deploy factory system for specific chain
     * @param chainId Target chain ID to read treasury from
     * @return factoryAddress The deployed factory proxy address
     */
    function deployForChain(uint256 chainId) public returns (address factoryAddress) {
        // Read treasury address from specific chain's addressBook
        string memory filename = string.concat("addressBook/", vm.toString(chainId), ".json");
        console.log("Reading treasury address from:", filename);
        string memory json = vm.readFile(filename);
        
        address treasuryAddress = vm.parseJsonAddress(json, ".portfolioRebalancer.treasury");
        address admin = tx.origin; // Use actual deployer EOA, not script contract
        
        console.log("Target Chain ID:", chainId);
        console.log("Treasury address:", treasuryAddress);
        console.log("Factory admin:", admin);
        
        return _deployFactoryCore(chainId, treasuryAddress, admin);
    }

    /**
     * @dev Core factory deployment logic with default fee
     * @param chainId Chain ID for addressBook updates
     * @param treasuryAddress Treasury proxy address
     * @param admin Factory admin address
     * @return factoryAddress The deployed factory proxy address
     */
    function _deployFactoryCore(
        uint256 chainId,
        address treasuryAddress,
        address admin
    ) internal returns (address factoryAddress) {
        return _deployFactoryCoreWithFee(chainId, treasuryAddress, admin, 50); // 0.5% default fee
    }

    /**
     * @dev Core factory deployment logic with custom fee
     * @param chainId Chain ID for addressBook updates
     * @param treasuryAddress Treasury proxy address
     * @param admin Factory admin address
     * @param feeBps Fee in basis points
     * @return factoryAddress The deployed factory proxy address
     */
    function _deployFactoryCoreWithFee(
        uint256 chainId,
        address treasuryAddress,
        address admin,
        uint256 feeBps
    ) internal returns (address factoryAddress) {
        vm.startBroadcast();

        console.log("=== Factory System Deployment Core ===");
        console.log("Chain ID:", chainId);
        console.log("Treasury Address:", treasuryAddress);
        console.log("Admin:", admin);
        console.log("Fee BPS:", feeBps);

        // 1. Deploy PortfolioRebalancer implementation (transparent proxy compatible)
        console.log("\n1. Deploying PortfolioRebalancer implementation...");
        implementation = new PortfolioRebalancer();
        console.log("PortfolioRebalancer implementation deployed at:", address(implementation));

        // 2. Deploy ProxyAdmin for managing transparent proxies (vault upgrades)
        console.log("\n2. Deploying ProxyAdmin...");
        proxyAdmin = new ProxyAdmin(admin);
        console.log("ProxyAdmin deployed at:", address(proxyAdmin));

        // 3. Deploy PortfolioRebalancerFactory implementation
        console.log("\n3. Deploying Factory implementation...");
        PortfolioRebalancerFactory factoryImpl = new PortfolioRebalancerFactory();
        console.log("Factory implementation deployed at:", address(factoryImpl));

        // 4. Deploy Factory as UUPS proxy
        console.log("\n4. Deploying Factory proxy...");
        bytes memory factoryData = abi.encodeWithSelector(
            PortfolioRebalancerFactory.initialize.selector,
            address(implementation), // portfolio implementation
            treasuryAddress,         // treasury proxy address
            feeBps,                  // fee in basis points
            admin,                   // admin
            address(proxyAdmin)      // ProxyAdmin for vault management
        );
        
        factoryProxy = new ERC1967Proxy(address(factoryImpl), factoryData);
        factory = PortfolioRebalancerFactory(address(factoryProxy));
        console.log("Factory proxy deployed at:", address(factory));

        // 5. ProxyAdmin ownership is already configured during deployment
        console.log("\n5. Configuring permissions...");
        console.log("ProxyAdmin ownership configured to:", admin);

        // 6. Validate deployment and proxy-implementation linking
        _validateFactoryDeployment(
            address(implementation),
            address(factoryImpl),
            address(factory),
            address(proxyAdmin),
            treasuryAddress,
            admin,
            feeBps
        );

        // 7. Update addressBook with all deployed addresses
        console.log("\n7. Updating addressBook...");
        _updateAddressBook(
            chainId,
            address(implementation),  // portfolio implementation
            address(factoryImpl),     // factory implementation  
            address(factory),         // factory proxy
            address(proxyAdmin)       // proxy admin
        );

        // 8. Log deployment summary
        console.log("\n=== Factory System Deployment Summary ===");
        console.log("1. Chain ID:", chainId);
        console.log("2. Portfolio Implementation:", address(implementation));
        console.log("3. Factory Implementation:", address(factoryImpl));
        console.log("4. Factory Proxy:", address(factory));
        console.log("5. ProxyAdmin:", address(proxyAdmin));
        console.log("6. Treasury Address:", treasuryAddress);
        console.log("7. Admin:", admin);
        console.log("8. Fee BPS:", feeBps);
        console.log("9. Proxy -> Implementation Links: VALIDATED");
        console.log("10. AddressBook updated");

        vm.stopBroadcast();
        
        return address(factory);
    }

    /**
     * @dev Updates the addressBook file with factory system addresses
     * @param chainId Chain ID for the addressBook file
     * @param portfolioImpl Portfolio implementation address
     * @param factoryImpl Factory implementation address
     * @param factoryProxyAddr Factory proxy address
     * @param proxyAdminAddr ProxyAdmin address
     */
    function _updateAddressBook(
        uint256 chainId,
        address portfolioImpl,
        address factoryImpl,
        address factoryProxyAddr,
        address proxyAdminAddr
    ) internal {
        string memory filename = string.concat("addressBook/", vm.toString(chainId), ".json");
        
        // Update all factory system addresses
        vm.writeJson(vm.toString(portfolioImpl), filename, ".portfolioRebalancer.implementation");
        vm.writeJson(vm.toString(factoryImpl), filename, ".portfolioRebalancer.factoryImplementation");
        vm.writeJson(vm.toString(factoryProxyAddr), filename, ".portfolioRebalancer.factory");
        vm.writeJson(vm.toString(proxyAdminAddr), filename, ".portfolioRebalancer.proxyAdmin");
        
        // Add deployment metadata
        vm.writeJson(vm.toString(block.number), filename, ".portfolioRebalancer.deploymentBlock");
        vm.writeJson(vm.toString(block.timestamp), filename, ".portfolioRebalancer.deploymentTimestamp");
        
        console.log("Updated addressBook file:", filename);
        console.log("Portfolio Implementation:", portfolioImpl);
        console.log("Factory Implementation:", factoryImpl);
        console.log("Factory Proxy:", factoryProxyAddr);
        console.log("ProxyAdmin:", proxyAdminAddr);
        console.log("Deployment Block:", block.number);
        console.log("Deployment Timestamp:", block.timestamp);
    }

    /**
     * @dev Validates the factory deployment and proxy-implementation linking
     * @param portfolioImpl Portfolio implementation address
     * @param factoryProxyAddr Factory proxy address
     * @param proxyAdminAddr ProxyAdmin address
     * @param treasuryAddr Treasury address
     * @param expectedAdmin Expected admin address
     * @param expectedFeeBps Expected fee basis points
     */
    function _validateFactoryDeployment(
        address portfolioImpl,
        address /* factoryImpl */,
        address factoryProxyAddr,
        address proxyAdminAddr,
        address treasuryAddr,
        address expectedAdmin,
        uint256 expectedFeeBps
    ) internal view {
        console.log("\n=== Factory System Deployment Validation ===");
        
        // 1. Validate factory proxy configuration
        PortfolioRebalancerFactory factoryContract = PortfolioRebalancerFactory(factoryProxyAddr);
        
        // 2. Validate factory settings
        require(factoryContract.implementation() == portfolioImpl, "Portfolio implementation mismatch");
        require(factoryContract.treasury() == treasuryAddr, "Treasury address mismatch");
        require(factoryContract.feeBps() == expectedFeeBps, "Fee BPS mismatch");
        require(factoryContract.hasRole(factoryContract.DEFAULT_ADMIN_ROLE(), expectedAdmin), "Factory admin role not granted");
        require(factoryContract.hasRole(factoryContract.ADMIN_ROLE(), expectedAdmin), "Factory ADMIN_ROLE not granted");
        
        // 3. Validate ProxyAdmin ownership
        ProxyAdmin proxyAdminContract = ProxyAdmin(proxyAdminAddr);
        require(proxyAdminContract.owner() == expectedAdmin, "ProxyAdmin ownership not transferred");
        
        console.log("PASS: Factory Proxy -> Implementation: LINKED");
        console.log("PASS: Portfolio Implementation:", portfolioImpl);
        console.log("PASS: Treasury Address:", treasuryAddr);
        console.log("PASS: Fee BPS:", expectedFeeBps);
        console.log("PASS: Factory Admin Roles: GRANTED");
        console.log("PASS: ProxyAdmin Ownership: TRANSFERRED");
        console.log("PASS: Factory System: READY FOR VAULT CREATION");
    }
} 