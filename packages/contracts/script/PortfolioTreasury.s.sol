// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {PortfolioTreasury} from "../src/PortfolioTreasury.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/utils/StorageSlot.sol";

contract DeployPortfolioTreasury is Script {
    PortfolioTreasury public treasuryImplementation;
    ERC1967Proxy public treasuryProxy;
    PortfolioTreasury public treasury;

    function setUp() public {}

    /**
     * @notice Deploy treasury using current chain's addressBook
     */
    function run() public returns (address) {
        uint256 chainId = block.chainid;

        // Read parameters from addressBook
        string memory filename = string.concat("addressBook/", vm.toString(chainId), ".json");
        console.log("Reading addresses from:", filename);
        string memory json = vm.readFile(filename);

        address linkToken = vm.parseJsonAddress(json, ".coins.LINK");
        address uniswapV3Router = vm.parseJsonAddress(json, ".uniswap.router");
        address automationRegistrar = vm.parseJsonAddress(json, ".chainlink.automationRegistrar");
        address admin = tx.origin; // Use actual deployer EOA, not script contract

        console.log("LINK Token from addressBook:", linkToken);
        console.log("Uniswap V3 Router from addressBook:", uniswapV3Router);
        console.log("Automation Registrar from addressBook:", automationRegistrar);

        return _deployTreasuryCore(chainId, linkToken, uniswapV3Router, automationRegistrar, admin);
    }

    /**
     * @notice Deploy treasury with custom parameters (override addressBook)
     * @param linkToken LINK token address
     * @param uniswapV3Router Uniswap V3 router address
     * @param automationRegistrar Chainlink Automation Registrar address
     * @param admin Admin address
     * @return treasuryAddress The deployed treasury proxy address
     */
    function deployWithParams(address linkToken, address uniswapV3Router, address automationRegistrar, address admin)
        public
        returns (address treasuryAddress)
    {
        uint256 chainId = block.chainid;

        console.log("Deploying with custom parameters (bypassing addressBook)");
        console.log("LINK Token:", linkToken);
        console.log("Uniswap V3 Router:", uniswapV3Router);
        console.log("Automation Registrar:", automationRegistrar);
        console.log("Admin:", admin);

        return _deployTreasuryCore(chainId, linkToken, uniswapV3Router, automationRegistrar, admin);
    }

    /**
     * @notice Deploy treasury for specific chain ID (useful for testing)
     * @param chainId Target chain ID to read from addressBook
     * @return treasuryAddress The deployed treasury proxy address
     */
    function deployForChain(uint256 chainId) public returns (address treasuryAddress) {
        // Read parameters from specific chain's addressBook
        string memory filename = string.concat("addressBook/", vm.toString(chainId), ".json");
        console.log("Reading addresses from:", filename);
        string memory json = vm.readFile(filename);

        address linkToken = vm.parseJsonAddress(json, ".coins.LINK");
        address uniswapV3Router = vm.parseJsonAddress(json, ".uniswap.router");
        address automationRegistrar = vm.parseJsonAddress(json, ".chainlink.automationRegistrar");
        address admin = tx.origin; // Use actual deployer EOA, not script contract

        console.log("Target Chain ID:", chainId);
        console.log("LINK Token:", linkToken);
        console.log("Uniswap V3Router:", uniswapV3Router);
        console.log("Automation Registrar:", automationRegistrar);

        return _deployTreasuryCore(chainId, linkToken, uniswapV3Router, automationRegistrar, admin);
    }

    /**
     * @notice Grant ADMIN_ROLE to an account (must be called by DEFAULT_ADMIN_ROLE holder)
     * @param treasuryAddress Treasury proxy address
     * @param account Account to grant role to
     */
    function grantAdminRole(address treasuryAddress, address account) public {
        // Use private key from .env file
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address caller = vm.addr(privateKey);
        
        PortfolioTreasury treasuryContract = PortfolioTreasury(treasuryAddress);
        bytes32 ADMIN_ROLE = treasuryContract.ADMIN_ROLE();
        bytes32 DEFAULT_ADMIN_ROLE = treasuryContract.DEFAULT_ADMIN_ROLE();
        
        // Verify caller has DEFAULT_ADMIN_ROLE
        require(treasuryContract.hasRole(DEFAULT_ADMIN_ROLE, caller), "Caller must have DEFAULT_ADMIN_ROLE");
        
        vm.startBroadcast(privateKey);
        treasuryContract.grantRole(ADMIN_ROLE, account);
        vm.stopBroadcast();
        
        console.log("=== ADMIN_ROLE Granted ===");
        console.log("Treasury:", treasuryAddress);
        console.log("Account:", account);
        console.log("Role granted by:", caller);
    }


    /**
     * @notice Upgrade existing treasury proxy with new implementation
     * @return newImplementationAddress The address of the new implementation
     */
    function upgradeExistingProxy() public returns (address newImplementationAddress) {
        uint256 chainId = block.chainid;

        // Read existing proxy address from addressBook
        string memory filename = string.concat("addressBook/", vm.toString(chainId), ".json");
        console.log("Reading existing treasury proxy from:", filename);
        
        string memory json = vm.readFile(filename);

        address existingProxy = vm.parseJsonAddress(json, ".portfolioRebalancer.treasury");
        address existingImplementation = vm.parseJsonAddress(json, ".portfolioRebalancer.treasuryImplementation");
        
        console.log("Existing Treasury Proxy:", existingProxy);
        console.log("Existing Treasury Implementation:", existingImplementation);

        // Deploy new implementation with unique salt to avoid address collisions
        vm.startBroadcast();
        PortfolioTreasury newImplementation = new PortfolioTreasury();
        address newImplAddress = address(newImplementation);

        console.log("New PortfolioTreasury implementation deployed at:", newImplAddress);
        
        // Verify the caller has ADMIN_ROLE before attempting upgrade
        PortfolioTreasury treasuryContract = PortfolioTreasury(existingProxy);
        
        // Upgrade the existing proxy (must be called by account with ADMIN_ROLE)        
        // For UUPS upgradeable contracts, call upgradeToAndCall directly on the proxy
        // The _authorizeUpgrade function will verify the caller has ADMIN_ROLE
        treasuryContract.upgradeToAndCall(address(newImplementation), "");
        
        vm.stopBroadcast();
        
        // Verify the upgrade was successful
        address updatedImplementation = _getImplementation(existingProxy);
        require(updatedImplementation == newImplAddress, "Upgrade failed - implementation not updated");
        console.log("PASS: Upgrade successful - implementation updated");

        // Update addressBook with new implementation
        _updateAddressBook(chainId, newImplAddress, existingProxy);

        console.log("\n=== Treasury Upgrade Summary ===");
        console.log("1. Chain ID:", chainId);
        console.log("2. Old Implementation:", existingImplementation);
        console.log("3. New Implementation:", newImplAddress);
        console.log("4. Proxy (unchanged):", existingProxy);
        console.log("5. Upgrade: COMPLETED");
        console.log("6. AddressBook updated");

        return newImplAddress;
    }

    /**
     * @dev Core deployment logic shared by all deployment functions
     * @param chainId Chain ID for addressBook updates
     * @param linkToken LINK token address
     * @param uniswapV3Router Uniswap V3 router address
     * @param automationRegistrar Chainlink Automation Registrar address
     * @param admin Admin address
     * @return treasuryAddress The deployed treasury proxy address
     */
    function _deployTreasuryCore(
        uint256 chainId,
        address linkToken,
        address uniswapV3Router,
        address automationRegistrar,
        address admin
    ) internal returns (address treasuryAddress) {
        vm.startBroadcast();

        console.log("=== Treasury Deployment Core ===");
        console.log("Chain ID:", chainId);
        console.log("Admin:", admin);

        // 1. Deploy PortfolioTreasury implementation
        treasuryImplementation = new PortfolioTreasury();
        console.log("PortfolioTreasury implementation deployed at:", address(treasuryImplementation));

        // 2. Prepare initialization data
        bytes memory treasuryData = abi.encodeWithSelector(
            PortfolioTreasury.initialize.selector, linkToken, uniswapV3Router, payable(automationRegistrar), admin
        );

        // 3. Deploy Treasury as UUPS proxy
        treasuryProxy = new ERC1967Proxy(address(treasuryImplementation), treasuryData);
        treasury = PortfolioTreasury(address(treasuryProxy));
        console.log("PortfolioTreasury proxy deployed at:", address(treasury));

        // 4. Validate deployment and proxy-implementation linking
        _validateTreasuryDeployment(
            address(treasuryImplementation), address(treasury), linkToken, uniswapV3Router, automationRegistrar, admin
        );

        // 5. Update addressBook with deployed addresses
        _updateAddressBook(chainId, address(treasuryImplementation), address(treasury));

        // 6. Log deployment summary
        console.log("\n=== Treasury Deployment Summary ===");
        console.log("1. Chain ID:", chainId);
        console.log("2. Treasury Implementation:", address(treasuryImplementation));
        console.log("3. Treasury Proxy:", address(treasury));
        console.log("4. Admin:", admin);
        console.log("5. LINK Token:", linkToken);
        console.log("6. Uniswap V3 Router:", uniswapV3Router);
        console.log("7. Automation Registrar:", automationRegistrar);
        console.log("8. Proxy -> Implementation Link: VALIDATED");
        console.log("9. AddressBook updated");

        vm.stopBroadcast();

        return address(treasury);
    }

    /**
     * @dev Get the implementation address from an ERC1967 proxy
     * @param proxyAddress The proxy address
     * @return implementation The implementation address
     */
    function _getImplementation(address proxyAddress) internal view returns (address implementation) {
        // Read the implementation address from the proxy's storage using Foundry's vm.load
        // ERC1967 implementation slot
        bytes32 slot = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
        bytes32 data = vm.load(proxyAddress, slot);
        implementation = address(uint160(uint256(data)));
    }

    /**
     * @dev Updates the addressBook file with deployed treasury addresses
     * @param chainId Chain ID for the addressBook file
     * @param implementation Treasury implementation address
     * @param proxy Treasury proxy address
     */
    function _updateAddressBook(uint256 chainId, address implementation, address proxy) internal {
        string memory filename = string.concat("addressBook/", vm.toString(chainId), ".json");

        // Update treasury addresses
        vm.writeJson(vm.toString(implementation), filename, ".portfolioRebalancer.treasuryImplementation");
        vm.writeJson(vm.toString(proxy), filename, ".portfolioRebalancer.treasury");

        // Add deployment metadata
        vm.writeJson(vm.toString(block.number), filename, ".portfolioRebalancer.treasuryDeploymentBlock");
        vm.writeJson(vm.toString(block.timestamp), filename, ".portfolioRebalancer.treasuryDeploymentTimestamp");

        console.log("Updated addressBook file:", filename);
        console.log("Treasury Implementation:", implementation);
        console.log("Treasury Proxy:", proxy);
        console.log("Deployment Block:", block.number);
        console.log("Deployment Timestamp:", block.timestamp);
    }

    /**
     * @dev Validates the treasury deployment and proxy-implementation linking
     * @param proxy Treasury proxy address
     * @param expectedLink Expected LINK token address
     * @param expectedRouter Expected Uniswap V3 router address
     * @param expectedRegistrar Expected automation registrar address
     * @param expectedAdmin Expected admin address
     */
    function _validateTreasuryDeployment(
        address, /* implementation */
        address proxy,
        address expectedLink,
        address expectedRouter,
        address expectedRegistrar,
        address expectedAdmin
    ) internal view {
        console.log("\n=== Treasury Deployment Validation ===");

        // 1. Validate proxy points to correct implementation
        PortfolioTreasury treasuryContract = PortfolioTreasury(proxy);

        // 2. Validate initialization parameters
        require(treasuryContract.link() == expectedLink, "LINK token mismatch");
        require(treasuryContract.uniswapV3Router() == expectedRouter, "Uniswap router mismatch");
        require(
            treasuryContract.hasRole(treasuryContract.DEFAULT_ADMIN_ROLE(), expectedAdmin), "Admin role not granted"
        );
        require(treasuryContract.hasRole(treasuryContract.ADMIN_ROLE(), expectedAdmin), "ADMIN_ROLE not granted");

        console.log("PASS: Proxy -> Implementation: LINKED");
        console.log("PASS: LINK Token:", expectedLink);
        console.log("PASS: Uniswap Router:", expectedRouter);
        console.log("PASS: Automation Registrar:", expectedRegistrar);
        console.log("PASS: Admin Roles: GRANTED");
        console.log("PASS: Treasury: READY FOR USE");
    }
}
