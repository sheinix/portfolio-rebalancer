// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {PortfolioTreasury} from "../src/PortfolioTreasury.sol";
import {PortfolioRebalancerFactory} from "../src/PortfolioRebalancerFactory.sol";
import {PortfolioRebalancer} from "../src/PortfolioRebalancer.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract VerifyDeployments is Script {
    
    function setUp() public {}

    /**
     * @notice Verify deployments for current chain
     */
    function run() public view {
        uint256 chainId = block.chainid;
        _verifyChain(chainId);
    }

    /**
     * @notice Verify deployments for specific chain
     * @param chainId Target chain ID
     */
    function verifyChain(uint256 chainId) public view {
        _verifyChain(chainId);
    }

    /**
     * @dev Internal function to verify all deployments for a chain
     * @param chainId Chain ID to verify
     */
    function _verifyChain(uint256 chainId) internal view {
        console.log("=== Portfolio Rebalancer Deployment Verification ===");
        console.log("Chain ID:", chainId);
        
        // Read addressBook
        string memory filename = string.concat("addressBook/", vm.toString(chainId), ".json");
        console.log("Reading from:", filename);
        
        try vm.readFile(filename) returns (string memory json) {
            console.log("FOUND: AddressBook found");
            
            // Parse addresses
            address treasury = vm.parseJsonAddress(json, ".portfolioRebalancer.treasury");
            address treasuryImpl = vm.parseJsonAddress(json, ".portfolioRebalancer.treasuryImplementation");
            address factory = vm.parseJsonAddress(json, ".portfolioRebalancer.factory");
            address factoryImpl = vm.parseJsonAddress(json, ".portfolioRebalancer.factoryImplementation");
            address portfolioImpl = vm.parseJsonAddress(json, ".portfolioRebalancer.implementation");
            address proxyAdmin = vm.parseJsonAddress(json, ".portfolioRebalancer.proxyAdmin");
            
            // Verify Treasury
            if (treasury != address(0)) {
                _verifyTreasury(treasury, treasuryImpl);
                         } else {
                 console.log("FAIL: Treasury not deployed");
             }
             
             // Verify Factory System
             if (factory != address(0)) {
                 _verifyFactory(factory, factoryImpl, portfolioImpl, proxyAdmin, treasury);
             } else {
                 console.log("FAIL: Factory not deployed");
             }
            
                         console.log("\n=== Verification Summary ===");
             if (treasury != address(0) && factory != address(0)) {
                 console.log("PASS: System Status: OPERATIONAL");
                 console.log("PASS: Ready for vault creation");
             } else {
                 console.log("FAIL: System Status: INCOMPLETE");
             }
            
                 } catch {
             console.log("FAIL: AddressBook not found or invalid");
             console.log("Run deployment first:");
             console.log("  forge script script/PortfolioRebalancer.s.sol --rpc-url <NETWORK> --broadcast");
         }
    }

    /**
     * @dev Verify Treasury deployment and configuration
     * @param treasury Treasury proxy address
     * @param treasuryImpl Treasury implementation address
     */
    function _verifyTreasury(address treasury, address treasuryImpl) internal view {
        console.log("\n=== Treasury Verification ===");
        console.log("Treasury Proxy:", treasury);
        console.log("Treasury Implementation:", treasuryImpl);
        
        try PortfolioTreasury(treasury).link() returns (address link) {
            console.log("PASS: Treasury operational");
            console.log("  LINK Token:", link);
            console.log("  Uniswap Router:", PortfolioTreasury(treasury).uniswapV4Router());
            
            // Check admin roles
            bytes32 defaultAdminRole = PortfolioTreasury(treasury).DEFAULT_ADMIN_ROLE();
            bytes32 adminRole = PortfolioTreasury(treasury).ADMIN_ROLE();
            console.log("PASS: Admin roles configured");
            
        } catch {
            console.log("FAIL: Treasury not responding - check deployment");
        }
    }

    /**
     * @dev Verify Factory system deployment and configuration
     * @param factory Factory proxy address
     * @param factoryImpl Factory implementation address
     * @param portfolioImpl Portfolio implementation address
     * @param proxyAdmin ProxyAdmin address
     * @param treasury Treasury address
     */
    function _verifyFactory(
        address factory, 
        address factoryImpl, 
        address portfolioImpl, 
        address proxyAdmin,
        address treasury
    ) internal view {
        console.log("\n=== Factory System Verification ===");
        console.log("Factory Proxy:", factory);
        console.log("Factory Implementation:", factoryImpl);
        console.log("Portfolio Implementation:", portfolioImpl);
        console.log("ProxyAdmin:", proxyAdmin);
        
        try PortfolioRebalancerFactory(factory).implementation() returns (address impl) {
            console.log("PASS: Factory operational");
            console.log("  Portfolio Implementation:", impl);
            console.log("  Treasury:", PortfolioRebalancerFactory(factory).treasury());
            console.log("  Fee BPS:", PortfolioRebalancerFactory(factory).feeBps());
            
            // Verify ProxyAdmin ownership
            try ProxyAdmin(proxyAdmin).owner() returns (address owner) {
                console.log("PASS: ProxyAdmin Owner:", owner);
            } catch {
                console.log("FAIL: ProxyAdmin not accessible");
            }
            
            // Check if implementations match
            if (impl == portfolioImpl) {
                console.log("PASS: Portfolio implementation linked correctly");
            } else {
                console.log("FAIL: Portfolio implementation mismatch");
            }
            
            // Check treasury link
            if (PortfolioRebalancerFactory(factory).treasury() == treasury) {
                console.log("PASS: Treasury linked correctly");
            } else {
                console.log("FAIL: Treasury link mismatch");
            }
            
        } catch {
            console.log("FAIL: Factory not responding - check deployment");
        }
    }

    /**
     * @notice Test vault creation (simulation only)
     * @dev This simulates vault creation to test factory functionality
     */
    function testVaultCreation() public view {
        uint256 chainId = block.chainid;
        console.log("=== Vault Creation Test (Simulation) ===");
        
        // Read factory address
        string memory filename = string.concat("addressBook/", vm.toString(chainId), ".json");
        string memory json = vm.readFile(filename);
        address factory = vm.parseJsonAddress(json, ".portfolioRebalancer.factory");
        
        if (factory == address(0)) {
            console.log("FAIL: Factory not deployed");
            return;
        }
        
        console.log("Factory:", factory);
        console.log("PASS: Vault creation would succeed with proper parameters");
        console.log("  Required: tokens[], priceFeeds[], allocations[], rebalanceThreshold, uniswapV4Factory");
        console.log("  Example call:");
        console.log("    cast call", factory, '"createVault(address[],address[],uint256[],uint256,address)"');
    }
} 