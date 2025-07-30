// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {DeployPortfolioTreasury} from "./PortfolioTreasury.s.sol";
import {DeployPortfolioRebalancerFactory} from "./PortfolioRebalancerFactory.s.sol";

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
        console.log("✅ Treasury deployment completed");
        
        // 2. Deploy Factory system (reads treasury address from addressBook)
        console.log("\n=== Step 2: Deploying Factory System ===");
        factoryDeployer = new DeployPortfolioRebalancerFactory();
        factoryAddress = factoryDeployer.run();
        console.log("✅ Factory deployment completed");
        
        // 3. Final summary
        _logFinalSummary(chainId);
    }

    /**
     * @notice Deploy with custom treasury parameters
     * @param linkToken LINK token address for treasury
     * @param uniswapV4Router Uniswap V4 router for treasury swaps
     * @param treasuryAdmin Treasury admin address
     */
    function runWithCustomTreasury(
        address linkToken,
        address uniswapV4Router,
        address treasuryAdmin
    ) public {
        uint256 chainId = block.chainid;
        
        console.log("=== Portfolio Rebalancer Full System Deployment (Custom Treasury) ===");
        console.log("Chain ID:", chainId);
        console.log("Deployer:", msg.sender);
        console.log("Treasury Admin:", treasuryAdmin);
        
        // 1. Deploy Treasury with custom parameters
        console.log("\n=== Step 1: Deploying Treasury System (Custom Parameters) ===");
        treasuryDeployer = new DeployPortfolioTreasury();
        treasuryAddress = treasuryDeployer.deployWithParams(linkToken, uniswapV4Router, treasuryAdmin);
        console.log("✅ Treasury deployment completed");
        
        // 2. Deploy Factory system (reads treasury address from addressBook)
        console.log("\n=== Step 2: Deploying Factory System ===");
        factoryDeployer = new DeployPortfolioRebalancerFactory();
        factoryAddress = factoryDeployer.run();
        console.log("✅ Factory deployment completed");
        
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
        
        // 1. Deploy Treasury with custom parameters
        console.log("\n=== Step 1: Deploying Treasury System (Custom Parameters) ===");
        treasuryDeployer = new DeployPortfolioTreasury();
        treasuryAddress = treasuryDeployer.deployWithParams(linkToken, uniswapV4Router, treasuryAdmin);
        console.log("✅ Treasury deployment completed");
        
        // 2. Deploy Factory system with custom parameters
        console.log("\n=== Step 2: Deploying Factory System (Custom Parameters) ===");
        factoryDeployer = new DeployPortfolioRebalancerFactory();
        factoryAddress = factoryDeployer.deployWithParams(treasuryAddress, factoryAdmin, feeBps);
        console.log("✅ Factory deployment completed");
        
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
        console.log("✅ Treasury deployment completed");
        
        // 2. Deploy Factory system for specific chain
        console.log("\n=== Step 2: Deploying Factory System ===");
        factoryDeployer = new DeployPortfolioRebalancerFactory();
        factoryAddress = factoryDeployer.deployForChain(chainId);
        console.log("✅ Factory deployment completed");
        
        // 3. Final summary
        _logFinalSummary(chainId);
    }

    /**
     * @dev Logs final deployment summary with key addresses and usage instructions
     * @param chainId Chain ID for the deployment
     */
    function _logFinalSummary(uint256 chainId) internal view {
        console.log("\n" "==========================================");
        console.log("🎉 PORTFOLIO REBALANCER DEPLOYMENT COMPLETE");
        console.log("==========================================");
        console.log("");
        console.log("📋 Deployment Summary:");
        console.log("  • Chain ID:", chainId);
        console.log("  • Treasury Address:", treasuryAddress);
        console.log("  • Factory Address:", factoryAddress);
        console.log("  • Deployer:", msg.sender);
        console.log("");
        console.log("📁 All addresses saved to: addressBook/" + vm.toString(chainId) + ".json");
        console.log("");
        console.log("🚀 Next Steps:");
        console.log("  1. Users can create vaults:");
        console.log("     cast call", factoryAddress, '"createVault(...)"');
        console.log("");
        console.log("  2. Query deployment info:");
        console.log("     forge script script/QueryDeployments.s.sol --rpc-url <network>");
        console.log("");
        console.log("  3. Verify contracts on Etherscan:");
        console.log("     forge verify-contract", treasuryAddress, "src/PortfolioTreasury.sol:PortfolioTreasury");
        console.log("     forge verify-contract", factoryAddress, "src/PortfolioRebalancerFactory.sol:PortfolioRebalancerFactory");
        console.log("");
        console.log("✅ System is ready for production use!");
    }
}
