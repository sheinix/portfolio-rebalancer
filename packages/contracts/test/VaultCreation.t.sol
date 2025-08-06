// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/PortfolioRebalancer.sol";
import "../src/PortfolioRebalancerFactory.sol";
import "../src/PortfolioTreasury.sol";
import "../test/mock/MockERC20.sol";
import "../test/mock/MockPriceFeed.sol";
import "../test/mock/MockAutomationRegistry.sol";
import "../test/mock/MockUniswapV3Factory.sol";
import "../test/mock/MockUniswapV3Pool.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@chainlink/shared/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title VaultCreationTest
 * @notice Comprehensive tests for vault creation using PortfolioRebalancerFactory
 * @dev Tests work on both local (Anvil) and Sepolia testnet environments
 *
 * @dev For Sepolia testing:
 * 1. Set PRIVATE_KEY environment variable with a private key that has LINK tokens
 * 2. Run with: forge test --fork-url $SEPOLIA_RPC_URL --match-path test/VaultCreation.t.sol
 *
 * @dev For local testing:
 * 1. Run with: forge test --match-path test/VaultCreation.t.sol
 */
contract VaultCreationTest is Test {
    // Core contracts
    PortfolioRebalancer public implementation;
    PortfolioRebalancerFactory public factory;
    PortfolioTreasury public treasury;
    ProxyAdmin public proxyAdmin;

    // Test infrastructure
    MockERC20[] public tokens;
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;
    uint256[] public allocations;

    // Environment state
    bool public isSepoliaNetwork = false;
    string public addressBookJson;

    // Environment addresses (loaded from address book or deployed locally)
    address public uniswapV3Factory;
    address public uniswapV3Router;
    address public uniswapV3SwapRouter;
    address public weth;
    address public linkToken;
    address public automationRegistry;

    // Test parameters
    address public vaultOwner = address(0x1111);
    address public factoryAdmin = address(0x2222);
    address public treasuryAdmin = address(0x3333);
    uint256 public constant REBALANCE_THRESHOLD = 10_000; // 1%
    uint256 public constant FACTORY_FEE_BPS = 10; // 0.1%
    uint32 public constant GAS_LIMIT = 500_000;
    uint96 public constant LINK_AMOUNT = 1 ether; // 5 LINK

    function setUp() public {
        console.log("Setting up VaultCreation test environment...");

        // Detect environment and load appropriate addresses
        _loadEnvironmentAddresses();

        // Deploy or setup tokens
        _setupTokens();

        // Setup price feeds
        _setupPriceFeeds();

        // Setup allocations
        _setupAllocations();

        // Deploy core infrastructure
        _deployInfrastructure();

        // Setup V3 pool mocking for local environment (after tokens are created)
        if (block.chainid == 31337) {
            // Local anvil chain
            _setupV3PoolMocking();
        }

        console.log("Setup complete!");
    }

    function _loadEnvironmentAddresses() internal {
        // Try to load from address book (for Sepolia/mainnet)
        // If not found, we'll deploy locally
        string memory filename = string.concat("addressBook/", vm.toString(block.chainid), ".json");
        console.log("Reading addresses from:", filename);
        // Check if we're on a known network by trying to load address book
        try vm.readFile(filename) returns (string memory json) {
            // Sepolia network detected
            console.log("Detected Sepolia network - loading real addresses");
            isSepoliaNetwork = true;
            addressBookJson = json;

            uniswapV3Factory = vm.parseJsonAddress(json, ".uniswap.factory");
            uniswapV3Router = vm.parseJsonAddress(json, ".uniswap.router");
            uniswapV3SwapRouter = vm.parseJsonAddress(json, ".uniswap.swapRouter");
            weth = vm.parseJsonAddress(json, ".coins.WETH");
            linkToken = vm.parseJsonAddress(json, ".coins.LINK");
            automationRegistry = vm.parseJsonAddress(json, ".chainlink.automationRegistry");

            console.log("Loaded Uniswap V3 Factory:", uniswapV3Factory);
            console.log("Loaded Uniswap V3 Router:", uniswapV3Router);
            console.log("Loaded Uniswap V3 Swap Router:", uniswapV3SwapRouter);
            console.log("Loaded LINK Token:", linkToken);
        } catch {
            // Local environment - deploy minimal infrastructure
            console.log("Local environment detected - deploying mock infrastructure");
            isSepoliaNetwork = false;
            _deployLocalInfrastructure();
        }
    }

    function _deployLocalInfrastructure() internal {
        // For local testing, deploy minimal mock contracts
        MockUniswapV3Factory mockFactory = new MockUniswapV3Factory();
        uniswapV3Factory = address(mockFactory);
        uniswapV3Router = address(0x4444); // Mock router address
        uniswapV3SwapRouter = address(0x5555); // Mock swap router address
        weth = address(0x6666); // Mock WETH address
        linkToken = address(new MockERC20("Chainlink Token", "LINK", 18, 1_000_000 ether));
        automationRegistry = address(new MockAutomationRegistry());

        // Setup mock pool liquidity
        MockUniswapV3Pool mockPool = new MockUniswapV3Pool();

        console.log("Deployed mock Uniswap V3 Factory:", uniswapV3Factory);
        console.log("Deployed mock LINK Token:", linkToken);
    }

    function _setupTokens() internal {
        if (isSepoliaNetwork) {
            console.log("Setting up real Sepolia tokens...");
            _setupSepoliaTokens();
        } else {
            console.log("Setting up mock tokens for local testing...");
            _setupMockTokens();
        }

        console.log("Setup", tokenAddresses.length, "tokens");
    }

    function _setupSepoliaTokens() internal {
        // Use real tokens from Sepolia address book
        string[] memory tokenNames = new string[](4);
        tokenNames[0] = "WETH";
        tokenNames[1] = "USDC";
        tokenNames[2] = "WBTC";
        tokenNames[3] = "AAVE";

        for (uint256 i = 0; i < tokenNames.length; i++) {
            string memory tokenPath = string.concat(".coins.", tokenNames[i]);
            address tokenAddress = vm.parseJsonAddress(addressBookJson, tokenPath);
            tokenAddresses.push(tokenAddress);
            console.log("Added real token", tokenNames[i], "at:", tokenAddress);
        }
    }

    function _setupMockTokens() internal {
        // Create mock ERC20 tokens for local testing
        for (uint256 i = 0; i < 4; i++) {
            MockERC20 token = new MockERC20(
                string(abi.encodePacked("Test Token ", vm.toString(i))),
                string(abi.encodePacked("TEST", vm.toString(i))),
                18,
                1_000_000 ether
            );
            tokens.push(token);
            tokenAddresses.push(address(token));

            // Give some tokens to the vault owner for testing
            token.transfer(vaultOwner, 10_000 ether);
        }
    }

    function _setupPriceFeeds() internal {
        if (isSepoliaNetwork) {
            console.log("Setting up real Sepolia price feeds...");
            _setupSepoliaPriceFeeds();
        } else {
            console.log("Setting up mock price feeds for local testing...");
            _setupMockPriceFeeds();
        }

        console.log("Setup", priceFeedAddresses.length, "price feeds");
    }

    function _setupSepoliaPriceFeeds() internal {
        // Map token addresses to their price feed names
        string[] memory priceFeedNames = new string[](4);
        priceFeedNames[0] = "priceFeedWETH";
        priceFeedNames[1] = "priceFeedUSDC";
        priceFeedNames[2] = "priceFeedWBTC";
        priceFeedNames[3] = "priceFeedAAVE";

        for (uint256 i = 0; i < priceFeedNames.length; i++) {
            string memory feedPath = string.concat(".chainlink.", priceFeedNames[i]);
            address priceFeedAddress = vm.parseJsonAddress(addressBookJson, feedPath);
            priceFeedAddresses.push(priceFeedAddress);
            console.log("Added real price feed", priceFeedNames[i], "at:", priceFeedAddress);
        }
    }

    function _setupMockPriceFeeds() internal {
        // Create mock price feeds for each token
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            address priceFeed = address(new MockPriceFeed(1e18)); // $1 per token
            priceFeedAddresses.push(priceFeed);
        }
    }

    function _setupAllocations() internal {
        // Create equal allocations for all tokens
        uint256 numTokens = tokenAddresses.length;
        uint256 baseAllocation = 1_000_000 / numTokens; // 1e6 / numTokens

        for (uint256 i = 0; i < numTokens; i++) {
            allocations.push(baseAllocation);
        }

        // Adjust last allocation to ensure sum equals exactly 1_000_000
        uint256 sum = baseAllocation * numTokens;
        if (sum != 1_000_000) {
            allocations[numTokens - 1] += (1_000_000 - sum);
        }

        console.log("Set up allocations with", allocations.length, "entries");
    }

    function _deployInfrastructure() internal {
        if (isSepoliaNetwork || block.chainid != 31337) {
            console.log("Loading deployed infrastructure from address book...");
            _loadDeployedInfrastructure();
        } else {
            console.log("Deploying new infrastructure for local testing...");
            _deployNewInfrastructure();
        }

        console.log("Infrastructure setup complete!");
    }

    function _loadDeployedInfrastructure() internal {
        // Load deployed contract addresses from address book
        proxyAdmin = ProxyAdmin(vm.parseJsonAddress(addressBookJson, ".portfolioRebalancer.proxyAdmin"));
        console.log("Loaded ProxyAdmin:", address(proxyAdmin));

        implementation =
            PortfolioRebalancer(vm.parseJsonAddress(addressBookJson, ".portfolioRebalancer.implementation"));
        console.log("Loaded PortfolioRebalancer implementation:", address(implementation));

        treasury = PortfolioTreasury(vm.parseJsonAddress(addressBookJson, ".portfolioRebalancer.treasury"));
        console.log("Loaded PortfolioTreasury:", address(treasury));

        factory = PortfolioRebalancerFactory(vm.parseJsonAddress(addressBookJson, ".portfolioRebalancer.factory"));
        console.log("Loaded PortfolioRebalancerFactory:", address(factory));

        // Fund treasury with LINK for automation upkeeps (only for testing)
        if (isSepoliaNetwork) {
            try this._fundTreasuryWithRealLINK() {
                console.log("Treasury LINK funding completed");
            } catch Error(string memory reason) {
                console.log("Treasury LINK funding failed:", reason);
            } catch {
                console.log("Treasury LINK funding failed with unknown error");
            }
        }
    }

    function _deployNewInfrastructure() internal {
        // Deploy fresh contracts for local testing only
        // 1. Deploy ProxyAdmin
        proxyAdmin = new ProxyAdmin(factoryAdmin);
        console.log("Deployed ProxyAdmin:", address(proxyAdmin));

        // 2. Deploy PortfolioRebalancer implementation
        implementation = new PortfolioRebalancer();
        console.log("Deployed PortfolioRebalancer implementation:", address(implementation));

        // 3. Deploy PortfolioTreasury implementation
        PortfolioTreasury treasuryImpl = new PortfolioTreasury();

        // 4. Deploy Treasury proxy
        bytes memory treasuryInitData = abi.encodeWithSelector(
            PortfolioTreasury.initialize.selector, linkToken, uniswapV3Router, automationRegistry, treasuryAdmin
        );

        TransparentUpgradeableProxy treasuryProxy =
            new TransparentUpgradeableProxy(address(treasuryImpl), address(proxyAdmin), treasuryInitData);
        treasury = PortfolioTreasury(address(treasuryProxy));
        console.log("Deployed PortfolioTreasury:", address(treasury));

        // 5. Deploy Factory implementation
        PortfolioRebalancerFactory factoryImpl = new PortfolioRebalancerFactory();

        // 6. Deploy Factory proxy
        bytes memory factoryInitData = abi.encodeWithSelector(
            PortfolioRebalancerFactory.initialize.selector,
            address(implementation),
            address(treasury),
            FACTORY_FEE_BPS,
            factoryAdmin,
            address(proxyAdmin)
        );

        TransparentUpgradeableProxy factoryProxy =
            new TransparentUpgradeableProxy(address(factoryImpl), address(proxyAdmin), factoryInitData);
        factory = PortfolioRebalancerFactory(address(factoryProxy));
        console.log("Deployed PortfolioRebalancerFactory:", address(factory));

        // 7. Grant treasury permissions to factory
        vm.startPrank(treasuryAdmin);
        treasury.grantRole(treasury.ADMIN_ROLE(), address(factory));
        treasury.grantRole(treasury.FACTORY_ROLE(), address(factory));
        vm.stopPrank();

        // 8. Fund treasury with LINK for automation upkeeps
        uint256 maxVaults = 3;
        uint256 fundingAmount = LINK_AMOUNT * maxVaults; // Same calculation as Sepolia
        MockERC20(linkToken).transfer(address(treasury), fundingAmount);
        console.log("Funded treasury with", fundingAmount / 1e18, "mock LINK for local testing");
    }

    function _setupV3PoolMocking() internal {
        // Mock the pool address that the factory returns
        address mockPoolAddress = address(0x1234);

        // Mock factory.getPool() calls to return mock pool
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            for (uint256 j = 0; j < tokenAddresses.length; j++) {
                if (i != j) {
                    vm.mockCall(
                        uniswapV3Factory,
                        abi.encodeWithSignature(
                            "getPool(address,address,uint24)", tokenAddresses[i], tokenAddresses[j], 3000
                        ),
                        abi.encode(mockPoolAddress)
                    );
                }
            }
        }

        // Mock pool.liquidity() calls to return non-zero liquidity
        vm.mockCall(mockPoolAddress, abi.encodeWithSignature("liquidity()"), abi.encode(uint128(1e18)));

        console.log("Setup V3 pool mocking");
    }

    function _fundTreasuryWithRealLINK() external {
        // Get private key from environment for Sepolia testing
        try vm.envString("PRIVATE_KEY") returns (string memory privateKeyStr) {
            uint256 deployerPrivateKey = vm.parseUint(privateKeyStr);
            address deployer = vm.addr(deployerPrivateKey);

            console.log("Using deployer address for LINK funding:", deployer);

            try IERC20(linkToken).balanceOf(deployer) returns (uint256 deployerBalance) {
                console.log("Deployer LINK balance:", deployerBalance);

                // Calculate required LINK based on test parameters
                // Each vault needs LINK_AMOUNT (5 LINK), and we create max 3 vaults in tests
                uint256 maxVaults = 3;
                uint256 requiredLINK = LINK_AMOUNT * maxVaults; // 15 LINK should be enough for testing

                if (deployerBalance >= requiredLINK) {
                    // Use deployer account to transfer LINK to treasury
                    vm.startPrank(deployer);
                    bool success = IERC20(linkToken).transfer(address(treasury), requiredLINK);
                    vm.stopPrank();

                    if (success) {
                        console.log(
                            "Successfully funded treasury with", requiredLINK / 1e18, "LINK from deployer account"
                        );
                    } else {
                        console.log("Warning: LINK transfer to treasury failed");
                    }
                } else {
                    console.log("Warning: Deployer doesn't have enough LINK tokens for treasury funding");
                    console.log("Required:", requiredLINK / 1e18, "LINK, Available:", deployerBalance / 1e18);
                    // For testing purposes, we'll continue without funding
                }
            } catch Error(string memory reason) {
                console.log("Error checking LINK balance:", reason);
            } catch {
                console.log("Unknown error when checking LINK balance");
            }
        } catch {
            console.log("PRIVATE_KEY environment variable not set - skipping treasury LINK funding");
            console.log("Note: For Sepolia testing, set PRIVATE_KEY env var to fund treasury with real LINK");
        }
    }

    // =============== VAULT CREATION TESTS ===============

    function test_createVault_Success() public {
        console.log("Testing successful vault creation...");

        vm.startPrank(vaultOwner);

        // Create vault through factory
        address vaultProxy = factory.createVault(
            tokenAddresses,
            priceFeedAddresses,
            allocations,
            REBALANCE_THRESHOLD,
            uniswapV3Factory,
            uniswapV3SwapRouter,
            weth,
            GAS_LIMIT,
            LINK_AMOUNT
        );

        vm.stopPrank();

        // Verify vault was created
        assertTrue(vaultProxy != address(0), "Vault proxy should not be zero address");
        console.log("Created vault at:", vaultProxy);

        // Verify vault is properly initialized
        PortfolioRebalancer vault = PortfolioRebalancer(vaultProxy);

        // Check initialization parameters
        assertEq(vault.owner(), vaultOwner, "Vault owner should be correct");
        assertEq(vault.treasury(), address(treasury), "Treasury should be correct");
        assertEq(vault.feeBps(), FACTORY_FEE_BPS, "Fee BPS should match factory");
        assertEq(vault.getUniswapV3Factory(), uniswapV3Factory, "Uniswap factory should be correct");
        assertEq(vault.rebalanceThreshold(), REBALANCE_THRESHOLD, "Rebalance threshold should be correct");

        // Verify basket setup
        assertEq(vault.getBasket().length, tokenAddresses.length, "Token count should match");
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            assertTrue(vault.isWhitelisted(tokenAddresses[i]), "Token should be whitelisted");
        }

        console.log("Vault creation test passed!");
    }

    function test_createVault_MultipleVaults() public {
        console.log("Testing creation of multiple vaults...");

        vm.startPrank(vaultOwner);

        // Create first vault
        address vault1 = factory.createVault(
            tokenAddresses,
            priceFeedAddresses,
            allocations,
            REBALANCE_THRESHOLD,
            uniswapV3Factory,
            uniswapV3SwapRouter,
            weth,
            GAS_LIMIT,
            LINK_AMOUNT
        );

        // Create second vault with different parameters
        uint256[] memory differentAllocations = new uint256[](2);
        differentAllocations[0] = 600_000; // 60%
        differentAllocations[1] = 400_000; // 40%

        address[] memory twoTokens = new address[](2);
        twoTokens[0] = tokenAddresses[0];
        twoTokens[1] = tokenAddresses[1];

        address[] memory twoFeeds = new address[](2);
        twoFeeds[0] = priceFeedAddresses[0];
        twoFeeds[1] = priceFeedAddresses[1];

        address vault2 = factory.createVault(
            twoTokens,
            twoFeeds,
            differentAllocations,
            5_000, // 0.5% threshold
            uniswapV3Factory,
            uniswapV3SwapRouter,
            weth,
            GAS_LIMIT,
            LINK_AMOUNT
        );

        vm.stopPrank();

        // Verify both vaults exist and are different
        assertTrue(vault1 != address(0), "First vault should exist");
        assertTrue(vault2 != address(0), "Second vault should exist");
        assertTrue(vault1 != vault2, "Vaults should be different addresses");

        // Verify different configurations
        PortfolioRebalancer v1 = PortfolioRebalancer(vault1);
        PortfolioRebalancer v2 = PortfolioRebalancer(vault2);

        assertEq(v1.getBasket().length, 4, "First vault should have 4 tokens");
        assertEq(v2.getBasket().length, 2, "Second vault should have 2 tokens");
        assertEq(v1.rebalanceThreshold(), REBALANCE_THRESHOLD, "First vault threshold");
        assertEq(v2.rebalanceThreshold(), 5_000, "Second vault threshold");

        console.log("Multiple vault creation test passed!");
    }

    function test_createVault_EmitsEvent() public {
        console.log("Testing vault creation event emission...");

        vm.startPrank(vaultOwner);

        // Expect VaultCreated event - only check that the first indexed parameter (user) matches
        // Event signature: VaultCreated(address indexed user, address proxy, uint256 indexed upkeepId)
        // Parameters: [true, false, false, false] = check 1st indexed, ignore 2nd indexed, ignore data
        vm.expectEmit(true, false, false, false);
        emit PortfolioRebalancerFactory.VaultCreated(vaultOwner, address(0), 0);

        address vaultProxy = factory.createVault(
            tokenAddresses,
            priceFeedAddresses,
            allocations,
            REBALANCE_THRESHOLD,
            uniswapV3Factory,
            uniswapV3SwapRouter,
            weth,
            GAS_LIMIT,
            LINK_AMOUNT
        );

        vm.stopPrank();

        console.log("Event emission test passed!");
    }

    function test_vault_BasicFunctionality() public {
        console.log("Testing basic vault functionality after creation...");

        vm.startPrank(vaultOwner);

        // Create vault
        address vaultProxy = factory.createVault(
            tokenAddresses,
            priceFeedAddresses,
            allocations,
            REBALANCE_THRESHOLD,
            uniswapV3Factory,
            uniswapV3SwapRouter,
            weth,
            GAS_LIMIT,
            LINK_AMOUNT
        );

        PortfolioRebalancer vault = PortfolioRebalancer(vaultProxy);

        // Test deposit functionality (only with mock tokens)
        if (!isSepoliaNetwork) {
            uint256 depositAmount = 1000 ether;
            tokens[0].approve(vaultProxy, depositAmount);

            vault.deposit(tokenAddresses[0], depositAmount, false);

            // Verify deposit was successful
            assertEq(vault.userBalances(vaultOwner, tokenAddresses[0]), depositAmount, "Deposit should be recorded");
            assertEq(tokens[0].balanceOf(vaultProxy), depositAmount, "Vault should hold tokens");
            console.log("Verified deposit functionality with mock tokens");
        } else {
            console.log("Skipped deposit test - using real Sepolia tokens (would need real token balance)");
        }

        vm.stopPrank();

        console.log("Basic functionality test passed!");
    }

    function test_createVault_WithRealSepoliaTokens() public {
        console.log("Testing vault creation with real Sepolia tokens...");

        // Skip if not on Sepolia network
        if (!isSepoliaNetwork) {
            console.log("Skipped - only runs on Sepolia network");
            return;
        }

        vm.startPrank(vaultOwner);

        // Create vault with real tokens and price feeds
        address vaultProxy = factory.createVault(
            tokenAddresses,
            priceFeedAddresses,
            allocations,
            REBALANCE_THRESHOLD,
            uniswapV3Factory,
            uniswapV3SwapRouter,
            weth,
            GAS_LIMIT,
            LINK_AMOUNT
        );

        vm.stopPrank();

        // Verify vault was created with real infrastructure
        assertTrue(vaultProxy != address(0), "Vault proxy should not be zero address");
        console.log("Created vault with real Sepolia tokens at:", vaultProxy);

        PortfolioRebalancer vault = PortfolioRebalancer(vaultProxy);

        // Verify it's using real addresses
        assertEq(vault.getUniswapV3Factory(), uniswapV3Factory, "Should use real Uniswap factory");
        assertEq(vault.treasury(), address(treasury), "Should use real treasury");

        // Log the real token configuration
        console.log("Vault configured with real tokens:");
        console.log("- WETH:", tokenAddresses[0]);
        console.log("- USDC:", tokenAddresses[1]);
        console.log("- WBTC:", tokenAddresses[2]);
        console.log("- AAVE:", tokenAddresses[3]);

        console.log("Real Sepolia vault creation test passed!");
    }

    // =============== FAILURE CASES ===============

    function test_createVault_Revert_InvalidAllocationSum() public {
        uint256[] memory invalidAllocations = new uint256[](2);
        invalidAllocations[0] = 500_000;
        invalidAllocations[1] = 400_000; // Sum = 900,000 != 1,000,000

        address[] memory twoTokens = new address[](2);
        twoTokens[0] = tokenAddresses[0];
        twoTokens[1] = tokenAddresses[1];

        address[] memory twoFeeds = new address[](2);
        twoFeeds[0] = priceFeedAddresses[0];
        twoFeeds[1] = priceFeedAddresses[1];

        vm.prank(vaultOwner);
        vm.expectRevert();
        factory.createVault(
            twoTokens, twoFeeds, invalidAllocations, REBALANCE_THRESHOLD, uniswapV3Factory, uniswapV3SwapRouter, weth, GAS_LIMIT, LINK_AMOUNT
        );
    }

    function test_createVault_Revert_ArrayLengthMismatch() public {
        address[] memory oneToken = new address[](1);
        oneToken[0] = tokenAddresses[0];

        // Use 2 price feeds for 1 token (mismatch)
        address[] memory twoFeeds = new address[](2);
        twoFeeds[0] = priceFeedAddresses[0];
        twoFeeds[1] = priceFeedAddresses[1];

        uint256[] memory oneAllocation = new uint256[](1);
        oneAllocation[0] = 1_000_000;

        vm.prank(vaultOwner);
        vm.expectRevert();
        factory.createVault(
            oneToken, twoFeeds, oneAllocation, REBALANCE_THRESHOLD, uniswapV3Factory, uniswapV3SwapRouter, weth, GAS_LIMIT, LINK_AMOUNT
        );
    }
}

// =============== MOCK CONTRACTS FOR LOCAL TESTING ===============
