// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {PortfolioTreasury} from "../src/PortfolioTreasury.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

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
        address uniswapV4Router = vm.parseJsonAddress(json, ".uniswap.uniswapV4Router");
        address admin = msg.sender;
        
        console.log("LINK Token from addressBook:", linkToken);
        console.log("Uniswap V4 Router from addressBook:", uniswapV4Router);
        
        return _deployTreasuryCore(chainId, linkToken, uniswapV4Router, admin);
    }

    /**
     * @notice Deploy treasury with custom parameters (override addressBook)
     * @param linkToken LINK token address
     * @param uniswapV4Router Uniswap V4 router address
     * @param admin Admin address
     * @return treasuryAddress The deployed treasury proxy address
     */
    function deployWithParams(
        address linkToken,
        address uniswapV4Router,
        address admin
    ) public returns (address treasuryAddress) {
        uint256 chainId = block.chainid;
        
        console.log("Deploying with custom parameters (bypassing addressBook)");
        console.log("LINK Token:", linkToken);
        console.log("Uniswap V4 Router:", uniswapV4Router);
        console.log("Admin:", admin);
        
        return _deployTreasuryCore(chainId, linkToken, uniswapV4Router, admin);
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
        address uniswapV4Router = vm.parseJsonAddress(json, ".uniswap.uniswapV4Router");
        address admin = msg.sender;
        
        console.log("Target Chain ID:", chainId);
        console.log("LINK Token:", linkToken);
        console.log("Uniswap V4 Router:", uniswapV4Router);
        
        return _deployTreasuryCore(chainId, linkToken, uniswapV4Router, admin);
    }

    /**
     * @dev Core deployment logic shared by all deployment functions
     * @param chainId Chain ID for addressBook updates
     * @param linkToken LINK token address
     * @param uniswapV4Router Uniswap V4 router address
     * @param admin Admin address
     * @return treasuryAddress The deployed treasury proxy address
     */
    function _deployTreasuryCore(
        uint256 chainId,
        address linkToken,
        address uniswapV4Router,
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
            PortfolioTreasury.initialize.selector,
            linkToken,
            uniswapV4Router,
            admin
        );

        // 3. Deploy Treasury as UUPS proxy
        treasuryProxy = new ERC1967Proxy(address(treasuryImplementation), treasuryData);
        treasury = PortfolioTreasury(address(treasuryProxy));
        console.log("PortfolioTreasury proxy deployed at:", address(treasury));

        // 4. Update addressBook with deployed addresses
        _updateAddressBook(chainId, address(treasuryImplementation), address(treasury));

        // 5. Log deployment summary
        console.log("\n=== Treasury Deployment Summary ===");
        console.log("1. Chain ID:", chainId);
        console.log("2. Treasury Implementation:", address(treasuryImplementation));
        console.log("3. Treasury Proxy:", address(treasury));
        console.log("4. Admin:", admin);
        console.log("5. LINK Token:", linkToken);
        console.log("6. Uniswap V4 Router:", uniswapV4Router);
        console.log("7. AddressBook updated");

        vm.stopBroadcast();
        
        return address(treasury);
    }

    /**
     * @dev Updates the addressBook file with deployed treasury addresses
     * @param chainId Chain ID for the addressBook file
     * @param implementation Treasury implementation address
     * @param proxy Treasury proxy address
     */
    function _updateAddressBook(uint256 chainId, address implementation, address proxy) internal {
        string memory filename = string.concat("addressBook/", vm.toString(chainId), ".json");
        
        // Read existing addressBook
        string memory json = vm.readFile(filename);
        
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
} 