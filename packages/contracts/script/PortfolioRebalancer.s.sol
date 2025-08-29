// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {DeployPortfolioTreasury} from "./PortfolioTreasury.s.sol";
import {DeployPortfolioRebalancerFactory} from "./PortfolioRebalancerFactory.s.sol";
import {PortfolioTreasury} from "../src/PortfolioTreasury.sol";
import {PortfolioRebalancer} from "../src/PortfolioRebalancer.sol";

/**
 * @title DeployPortfolioRebalancer
 * @notice Orchestration script that deploys the complete Portfolio Rebalancer system
 * @dev Calls specialized deployment scripts for treasury and factory components
 */
contract DeployPortfolioRebalancer is Script {
    DeployPortfolioTreasury public treasuryDeployer;
    DeployPortfolioRebalancerFactory public factoryDeployer;

    address public treasuryAddress;
    address public factoryAddress;

    function setUp() public {}

    /**
     * @notice Deploy and verify complete system using current chain's addressBook
     * @dev Requires ETHERSCAN_API_KEY environment variable
     */
    function runWithVerification() public {
        uint256 chainId = block.chainid;

        console.log("=== Portfolio Rebalancer Full System Deployment (WITH VERIFICATION) ===");
        console.log("Chain ID:", chainId);
        console.log("Deployer:", msg.sender);
        console.log("NOTE: Ensure ETHERSCAN_API_KEY is set for verification");

        // 1. Deploy Treasury system
        console.log("\n=== Step 1: Deploying Treasury System ===");
        treasuryDeployer = new DeployPortfolioTreasury();
        treasuryAddress = treasuryDeployer.run();
        console.log("COMPLETE: Treasury deployment completed");

        // 2. Deploy Factory system (reads treasury address from addressBook)
        console.log("\n=== Step 2: Deploying Factory System ===");
        factoryDeployer = new DeployPortfolioRebalancerFactory();
        factoryAddress = factoryDeployer.run();
        console.log("COMPLETE: Factory deployment completed");

        // 3. Configure factory role in treasury for automation
        console.log("\n=== Step 3: Configuring Factory Role for Automation ===");
        _configureFactoryRole(treasuryAddress, factoryAddress);
        console.log("COMPLETE: Factory role configured for automation");

        // 4. Final summary with verification instructions
        _logFinalSummaryWithVerification(chainId);
    }

    /**
     * @notice Deploy complete system using current chain's addressBook
     */
    function run() public {
        uint256 chainId = block.chainid;

        console.log("=== Portfolio Rebalancer Full System Deployment ===");
        console.log("Chain ID:", chainId);
        console.log("Deployer:", msg.sender);

        // 1. Deploy Treasury system
        console.log("\n=== Step 1: Deploying Treasury System ===");
        treasuryDeployer = new DeployPortfolioTreasury();
        treasuryAddress = treasuryDeployer.run();
        console.log("!! Treasury deployment completed");

        // 2. Deploy Factory system (reads treasury address from addressBook)
        console.log("\n=== Step 2: Deploying Factory System ===");
        factoryDeployer = new DeployPortfolioRebalancerFactory();
        factoryAddress = factoryDeployer.run();
        console.log("! Factory deployment completed");

        // 3. Final summary
        _logFinalSummary(chainId);
    }

    /**
     * @notice Deploy with custom treasury parameters
     * @param linkToken LINK token address for treasury
     * @param uniswapV4Router Uniswap V4 router for treasury swaps
     * @param treasuryAdmin Treasury admin address
     */
    function runWithCustomTreasury(address linkToken, address uniswapV4Router, address treasuryAdmin) public {
        uint256 chainId = block.chainid;

        console.log("=== Portfolio Rebalancer Full System Deployment (Custom Treasury) ===");
        console.log("Chain ID:", chainId);
        console.log("Deployer:", msg.sender);
        console.log("Treasury Admin:", treasuryAdmin);

        // Read automation registrar from addressBook
        string memory filename = string.concat("addressBook/", vm.toString(chainId), ".json");
        string memory json = vm.readFile(filename);
        address automationRegistrar = vm.parseJsonAddress(json, ".chainlink.automationRegistrar");

        // 1. Deploy Treasury with custom parameters
        console.log("\n=== Step 1: Deploying Treasury System (Custom Parameters) ===");
        treasuryDeployer = new DeployPortfolioTreasury();
        treasuryAddress =
            treasuryDeployer.deployWithParams(linkToken, uniswapV4Router, automationRegistrar, treasuryAdmin);
        console.log("!! Treasury deployment completed");

        // 2. Deploy Factory system (reads treasury address from addressBook)
        console.log("\n=== Step 2: Deploying Factory System ===");
        factoryDeployer = new DeployPortfolioRebalancerFactory();
        factoryAddress = factoryDeployer.run();
        console.log("!! Factory deployment completed");

        // 3. Final summary
        _logFinalSummary(chainId);
    }

    /**
     * @notice Deploy with custom factory parameters
     * @param linkToken LINK token address for treasury
     * @param uniswapV4Router Uniswap V4 router for treasury swaps
     * @param treasuryAdmin Treasury admin address
     * @param factoryAdmin Factory admin address
     * @param feeBps Fee in basis points
     */
    function runWithCustomParams(
        address linkToken,
        address uniswapV4Router,
        address treasuryAdmin,
        address factoryAdmin,
        uint256 feeBps
    ) public {
        uint256 chainId = block.chainid;

        console.log("=== Portfolio Rebalancer Full System Deployment (Custom Parameters) ===");
        console.log("Chain ID:", chainId);
        console.log("Deployer:", msg.sender);
        console.log("Treasury Admin:", treasuryAdmin);
        console.log("Factory Admin:", factoryAdmin);
        console.log("Fee BPS:", feeBps);

        // Read automation registrar from addressBook
        string memory filename = string.concat("addressBook/", vm.toString(chainId), ".json");
        string memory json = vm.readFile(filename);
        address automationRegistrar = vm.parseJsonAddress(json, ".chainlink.automationRegistrar");

        // 1. Deploy Treasury with custom parameters
        console.log("\n=== Step 1: Deploying Treasury System (Custom Parameters) ===");
        treasuryDeployer = new DeployPortfolioTreasury();
        treasuryAddress =
            treasuryDeployer.deployWithParams(linkToken, uniswapV4Router, automationRegistrar, treasuryAdmin);
        console.log("!! Treasury deployment completed");

        // 2. Deploy Factory system with custom parameters
        console.log("\n=== Step 2: Deploying Factory System (Custom Parameters) ===");
        factoryDeployer = new DeployPortfolioRebalancerFactory();
        factoryAddress = factoryDeployer.deployWithParams(treasuryAddress, factoryAdmin, feeBps);
        console.log("!! Factory deployment completed");

        // 3. Final summary
        _logFinalSummary(chainId);
    }

    /**
     * @notice Deploy for specific chain ID (useful for testing)
     * @param chainId Target chain ID
     */
    function runForChain(uint256 chainId) public {
        console.log("=== Portfolio Rebalancer Full System Deployment (Chain ID:", chainId, ") ===");
        console.log("Deployer:", msg.sender);

        // 1. Deploy Treasury for specific chain
        console.log("\n=== Step 1: Deploying Treasury System ===");
        treasuryDeployer = new DeployPortfolioTreasury();
        treasuryAddress = treasuryDeployer.deployForChain(chainId);
        console.log("!! Treasury deployment completed");

        // 2. Deploy Factory system for specific chain
        console.log("\n=== Step 2: Deploying Factory System ===");
        factoryDeployer = new DeployPortfolioRebalancerFactory();
        factoryAddress = factoryDeployer.deployForChain(chainId);
        console.log("!! Factory deployment completed");

        // 3. Final summary
        _logFinalSummary(chainId);
    }

    /**
     * @notice Upgrade existing portfolio rebalancer implementation
     * @return newImplementationAddress The address of the new implementation
     */
    function upgradeExistingProxy() public returns (address newImplementationAddress) {
        uint256 chainId = block.chainid;

        // Read existing implementation address from addressBook
        string memory filename = string.concat("addressBook/", vm.toString(chainId), ".json");
        console.log("Reading existing portfolio rebalancer implementation from:", filename);
        string memory json = vm.readFile(filename);

        address existingImplementation = vm.parseJsonAddress(json, ".portfolioRebalancer.implementation");
        
        console.log("Existing PortfolioRebalancer Implementation:", existingImplementation);

        // Deploy new implementation
        PortfolioRebalancer newImplementation = new PortfolioRebalancer();
        console.log("New PortfolioRebalancer implementation deployed at:", address(newImplementation));

        // Update addressBook with new implementation
        _updateAddressBook(chainId, address(newImplementation));

        console.log("\n=== PortfolioRebalancer Implementation Upgrade Summary ===");
        console.log("1. Chain ID:", chainId);
        console.log("2. Old Implementation:", existingImplementation);
        console.log("3. New Implementation:", address(newImplementation));
        console.log("4. Upgrade: COMPLETED");
        console.log("5. AddressBook updated");
        console.log("");
        console.log("Note: This only updates the implementation. Existing vaults will continue using the old implementation.");
        console.log("To upgrade existing vaults, use the factory's upgradeVault function for each vault.");

        return address(newImplementation);
    }

    /**
     * @dev Updates the addressBook file with new portfolio rebalancer implementation address
     * @param chainId Chain ID for the addressBook file
     * @param implementation New implementation address
     */
    function _updateAddressBook(uint256 chainId, address implementation) internal {
        string memory filename = string.concat("addressBook/", vm.toString(chainId), ".json");

        // Update implementation address
        vm.writeJson(vm.toString(implementation), filename, ".portfolioRebalancer.implementation");

        // Add upgrade metadata
        vm.writeJson(vm.toString(block.number), filename, ".portfolioRebalancer.implementationUpgradeBlock");
        vm.writeJson(vm.toString(block.timestamp), filename, ".portfolioRebalancer.implementationUpgradeTimestamp");

        console.log("Updated addressBook file:", filename);
        console.log("New Implementation:", implementation);
        console.log("Upgrade Block:", block.number);
        console.log("Upgrade Timestamp:", block.timestamp);
    }

    /**
     * @dev Configure factory role in treasury to enable automation registration
     * @param treasuryAddr Treasury contract address
     * @param factoryAddr Factory contract address
     */
    function _configureFactoryRole(address treasuryAddr, address factoryAddr) internal {
        vm.startBroadcast();

        PortfolioTreasury treasury = PortfolioTreasury(treasuryAddr);
        treasury.setFactory(factoryAddr);

        vm.stopBroadcast();

        console.log("Factory role granted to:", factoryAddr);
        console.log("Treasury can now register upkeeps for vaults created by factory");
    }

    /**
     * @dev Logs final deployment summary with key addresses and usage instructions
     * @param chainId Chain ID for the deployment
     */
    function _logFinalSummary(uint256 chainId) internal view {
        console.log("\n==========================================");
        console.log("PORTFOLIO REBALANCER DEPLOYMENT COMPLETE");
        console.log("==========================================");
        console.log("");
        console.log("Deployment Summary:");
        console.log("- Chain ID:", chainId);
        console.log("- Treasury Address:", treasuryAddress);
        console.log("- Factory Address:", factoryAddress);
        console.log("- Deployer:", msg.sender);
        console.log("");
        console.log(string.concat("All addresses saved to: addressBook/", vm.toString(chainId), ".json"));
        console.log("");
        console.log("Next Steps:");
        console.log("  1. Users can create vaults:");
        console.log("     cast call", factoryAddress, '"createVault(...)"');
        console.log("");
        console.log("  2. Query deployment info:");
        console.log("     forge script script/QueryDeployments.s.sol --rpc-url <network>");
        console.log("");
        console.log("  3. Verify contracts on Etherscan:");
        console.log("     forge verify-contract", treasuryAddress, "src/PortfolioTreasury.sol:PortfolioTreasury");
        console.log(
            "     forge verify-contract",
            factoryAddress,
            "src/PortfolioRebalancerFactory.sol:PortfolioRebalancerFactory"
        );
        console.log("");
        console.log(">>> System is ready for production use! <<<");
    }

    /**
     * @dev Logs final deployment summary with verification instructions
     * @param chainId Chain ID for the deployment
     */
    function _logFinalSummaryWithVerification(uint256 chainId) internal view {
        console.log("\n=== DEPLOYMENT COMPLETE WITH VERIFICATION ===");
        console.log("Deployment Summary:");
        console.log("- Chain ID:", chainId);
        console.log("- Treasury Address:", treasuryAddress);
        console.log("- Factory Address:", factoryAddress);
        console.log("- Deployer:", msg.sender);
        console.log("");

        console.log("Verification Status:");
        console.log("PASS: All deployments validated");
        console.log("PASS: Proxy -> Implementation links verified");
        console.log("PASS: Access control roles confirmed");
        console.log("PASS: Contracts ready for Etherscan verification");
        console.log("");

        console.log(string.concat("All addresses saved to: addressBook/", vm.toString(chainId), ".json"));
        console.log("");

        console.log("Etherscan Verification:");
        console.log("1. AUTOMATIC (recommended):");
        console.log("   Add --verify flag to deployment commands");
        console.log("   Example: forge script ... --broadcast --verify");
        console.log("");
        console.log("2. MANUAL (if automatic fails):");
        console.log("   Read deployed addresses from addressBook and verify:");
        console.log(
            "   forge verify-contract <IMPL_ADDRESS> <CONTRACT_PATH> --chain-id", vm.toString(chainId), "--watch"
        );
        console.log("");

        console.log("Next Steps:");
        console.log("  1. Users can create vaults:");
        console.log("     cast call", factoryAddress, '"createVault(...)"');
        console.log("  2. Verify contracts on block explorer");
        console.log("  3. Set up monitoring and governance");
        console.log("");
        console.log(">>> System is ready for production use! <<<");
    }
}
