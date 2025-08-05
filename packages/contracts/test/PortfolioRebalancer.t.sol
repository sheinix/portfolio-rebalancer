// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/PortfolioRebalancer.sol";
import "../src/libraries/ValidationLibrary.sol";
import "../src/libraries/PortfolioLogicLibrary.sol";
import "./mock/MockERC20.sol";
import "./mock/PortfolioRebalancerTestable.sol";

contract PortfolioRebalancerTest is Test {
    PortfolioRebalancer rebalancer;
    MockERC20[6] tokens;
    address[] tokenAddrs;
    address[] priceFeeds;
    uint256[] allocations;
    address owner = address(0xABCD);
    address treasury = address(0xBEEF);
    address uniswapV3Factory = address(0xCAFE);
    address uniswapV3SwapRouter = address(0xDEAD);
    address weth = address(0x1234);

    function setUp() public {
        _setupTokens();
        _setupAllocations();
        _setupMocking();
        rebalancer = new PortfolioRebalancer();
    }

    function _setupTokens() internal {
        for (uint256 i = 0; i < 6; i++) {
            tokens[i] = new MockERC20(
                string(abi.encodePacked("Token", vm.toString(i))),
                string(abi.encodePacked("T", vm.toString(i))),
                18,
                1_000_000 ether
            );
            tokenAddrs.push(address(tokens[i]));
            priceFeeds.push(address(uint160(0x1000 + i))); // Dummy price feed addresses
        }
    }

    function _setupAllocations() internal {
        // Initialize allocations array with even split
        allocations = new uint256[](6);
        for (uint256 i = 0; i < 6; i++) {
            allocations[i] = 166_666; // 1e6 / 6 = 166,666.67... (even split)
        }
        // Add the remainder to the last allocation to ensure sum equals 1e6
        allocations[5] = 166_670; // 166,666 * 5 + 166,670 = 1,000,000
    }

    // Helper function to set up comprehensive mocking
    function _setupMocking() internal {
        // Mock all price feeds
        for (uint256 i = 0; i < 6; i++) {
            vm.mockCall(
                address(uint160(0x1000 + i)), // priceFeeds[i]
                0,
                abi.encodeWithSignature("latestRoundData()"),
                abi.encode(uint80(1), int256(1e18), uint256(block.timestamp), uint256(block.timestamp), uint80(1))
            );

            // Mock decimals() for price feeds
            vm.mockCall(
                address(uint160(0x1000 + i)), // priceFeeds[i]
                0,
                abi.encodeWithSignature("decimals()"),
                abi.encode(uint8(18)) // Return 18 decimals for simplicity
            );
        }

        // Mock Uniswap V3 factory calls for all token pairs
        for (uint256 i = 0; i < 6; i++) {
            for (uint256 j = 0; j < 6; j++) {
                if (i != j) {
                    vm.mockCall(
                        uniswapV3Factory,
                        0,
                        abi.encodeWithSignature("getPool(address,address,uint24)"),
                        abi.encode(address(0x1234)) // Mock pool address
                    );
                }
            }
        }

        // Mock pool liquidity calls
        vm.mockCall(
            address(0x1234),
            0,
            abi.encodeWithSignature("liquidity()"),
            abi.encode(uint128(1e18)) // Mock liquidity
        );

        // Mock pool swap calls
        vm.mockCall(
            address(0x1234),
            0,
            abi.encodeWithSignature("swap(address,bool,int256,uint160,bytes)"),
            abi.encode(uint160(0), int256(1e18)) // Mock swap return: (sqrtPriceX96, amountOut)
        );
    }

    function _setupInitializedContract() internal {
        rebalancer.initialize(tokenAddrs, priceFeeds, allocations, 10_000, uniswapV3Factory, uniswapV3SwapRouter, weth, 10, treasury, owner);
    }

    // --- initialize Validation Tests ---
    function test_initialize_Revert_ExceedsMaxTokens() public {
        // Try to initialize with too many tokens
        address[] memory tooMany = new address[](7);
        address[] memory feeds = new address[](7);
        uint256[] memory allocs = new uint256[](7);
        for (uint256 i = 0; i < 7; i++) {
            tooMany[i] = address(tokens[0]);
            feeds[i] = priceFeeds[0];
            if (i < 6) {
                allocs[i] = 142_857; // 1e6 / 7 ≈ 142,857
            } else {
                allocs[i] = 142_858; // Make up the difference to get exactly 1e6
            }
        }

        vm.expectRevert(PortfolioRebalancer.ExceedsMaxTokens.selector);
        rebalancer.initialize(tooMany, feeds, allocs, 10_000, uniswapV3Factory, uniswapV3SwapRouter, weth, 10, treasury, owner);
    }

    function test_initialize_Revert_AllocationSumMismatch() public {
        // Try to initialize with mismatched allocations
        address[] memory t = new address[](2);
        address[] memory f = new address[](2);
        uint256[] memory a = new uint256[](2);
        t[0] = address(tokens[0]);
        t[1] = address(tokens[1]);
        f[0] = priceFeeds[0];
        f[1] = priceFeeds[1];
        a[0] = 500_000;
        a[1] = 400_000; // sum != 1e6

        vm.expectRevert(PortfolioRebalancer.AllocationSumMismatch.selector);
        rebalancer.initialize(t, f, a, 10_000, uniswapV3Factory, uniswapV3SwapRouter, weth, 10, treasury, owner);
    }

    function test_initialize_Revert_ZeroAddress() public {
        // Try to initialize with zero address
        address[] memory t = new address[](2);
        address[] memory f = new address[](2);
        uint256[] memory a = new uint256[](2);
        t[0] = address(0);
        t[1] = address(tokens[1]);
        f[0] = priceFeeds[0];
        f[1] = priceFeeds[1];
        a[0] = 500_000;
        a[1] = 500_000;

        vm.expectRevert(ValidationLibrary.ZeroAddress.selector);
        rebalancer.initialize(t, f, a, 10_000, uniswapV3Factory, uniswapV3SwapRouter, weth, 10, treasury, owner);
    }

    function test_initialize_Success() public {
        // Test successful initialization
        rebalancer.initialize(tokenAddrs, priceFeeds, allocations, 10_000, uniswapV3Factory, uniswapV3SwapRouter, weth, 10, treasury, owner);

        // Verify the basket was set correctly
        (address token, address priceFeed, uint256 targetAllocation) = rebalancer.basket(0);
        assertEq(token, address(tokens[0]));
        assertEq(priceFeed, priceFeeds[0]);
        assertEq(targetAllocation, allocations[0]);
        assertEq(rebalancer.rebalanceThreshold(), 10_000);
        assertEq(rebalancer.feeBps(), 10);
        assertEq(rebalancer.treasury(), treasury);
        assertEq(rebalancer.uniswapV3Factory(), uniswapV3Factory);
    }

    function test_initialize_Revert_EmptyArrays() public {
        // Try to initialize with empty arrays
        address[] memory emptyTokens = new address[](0);
        address[] memory emptyFeeds = new address[](0);
        uint256[] memory emptyAllocs = new uint256[](0);

        vm.expectRevert(PortfolioRebalancer.ExceedsMaxTokens.selector);
        rebalancer.initialize(emptyTokens, emptyFeeds, emptyAllocs, 10_000, uniswapV3Factory, uniswapV3SwapRouter, weth, 10, treasury, owner);
    }

    function test_initialize_Revert_ArrayLengthMismatch() public {
        // Try to initialize with mismatched array lengths
        address[] memory t = new address[](2);
        address[] memory f = new address[](3); // Different length
        uint256[] memory a = new uint256[](2);
        t[0] = address(tokens[0]);
        t[1] = address(tokens[1]);
        f[0] = priceFeeds[0];
        f[1] = priceFeeds[1];
        f[2] = priceFeeds[2]; // Extra feed
        a[0] = 500_000;
        a[1] = 500_000;

        vm.expectRevert(ValidationLibrary.ArrayLengthMismatch.selector);
        rebalancer.initialize(t, f, a, 10_000, uniswapV3Factory, uniswapV3SwapRouter, weth, 10, treasury, owner);
    }

    function test_initialize_Revert_ZeroTreasury() public {
        // Try to initialize with zero treasury address
        vm.expectRevert(ValidationLibrary.ZeroTreasury.selector);
        rebalancer.initialize(tokenAddrs, priceFeeds, allocations, 10_000, uniswapV3Factory, uniswapV3SwapRouter, weth, 10, address(0), owner);
    }

    function test_initialize_Revert_ZeroFactory() public {
        // Try to initialize with zero factory address
        vm.expectRevert(ValidationLibrary.ZeroFactory.selector);
        rebalancer.initialize(tokenAddrs, priceFeeds, allocations, 10_000, address(0), uniswapV3SwapRouter, weth, 10, treasury, owner);
    }

    function test_initialize_Revert_ZeroOwner() public {
        // Try to initialize with zero owner address
        vm.expectRevert(ValidationLibrary.ZeroAddress.selector);
        rebalancer.initialize(tokenAddrs, priceFeeds, allocations, 10_000, uniswapV3Factory, uniswapV3SwapRouter, weth, 10, treasury, address(0));
    }

    function test_initialize_Revert_DoubleInitialization() public {
        // Initialize once successfully
        rebalancer.initialize(tokenAddrs, priceFeeds, allocations, 10_000, uniswapV3Factory, uniswapV3SwapRouter, weth, 10, treasury, owner);

        // Try to initialize again (should revert due to initializer modifier)
        vm.expectRevert();
        rebalancer.initialize(tokenAddrs, priceFeeds, allocations, 10_000, uniswapV3Factory, uniswapV3SwapRouter, weth, 10, treasury, owner);
    }

    // --- setBasket Validation Tests ---
    function test_setBasket_Revert_ExceedsMaxTokens() public {
        _setupInitializedContract();
        // Try to set basket with too many tokens
        address[] memory tooMany = new address[](7);
        address[] memory feeds = new address[](7);
        uint256[] memory allocs = new uint256[](7);
        for (uint256 i = 0; i < 7; i++) {
            tooMany[i] = address(tokens[0]);
            feeds[i] = priceFeeds[0];
            if (i < 6) {
                allocs[i] = 142_857; // 1e6 / 7 ≈ 142,857
            } else {
                allocs[i] = 142_858; // Make up the difference to get exactly 1e6
            }
        }

        vm.prank(owner);
        vm.expectRevert(PortfolioRebalancer.ExceedsMaxTokens.selector);
        rebalancer.setBasket(tooMany, feeds, allocs);
    }

    function test_setBasket_Revert_NoPoolForToken() public {
        _setupInitializedContract();

        // Override mock so the Uniswap factory returns address(0) for getPool calls
        vm.mockCall(
            uniswapV3Factory,
            0,
            abi.encodeWithSignature("getPool(address,address,uint24)"),
            abi.encode(address(0)) // Return address(0) to simulate no pool
        );

        vm.prank(owner);
        vm.expectRevert(ValidationLibrary.NoPoolForToken.selector);
        rebalancer.setBasket(tokenAddrs, priceFeeds, allocations);
    }

    function test_setBasket_Revert_AllocationSumMismatch() public {
        _setupInitializedContract();
        // Try to set basket with mismatched allocations
        address[] memory t = new address[](2);
        address[] memory f = new address[](2);
        uint256[] memory a = new uint256[](2);
        t[0] = address(tokens[0]);
        t[1] = address(tokens[1]);
        f[0] = priceFeeds[0];
        f[1] = priceFeeds[1];
        a[0] = 500_000;
        a[1] = 400_000; // sum != 1e6

        vm.prank(owner);
        vm.expectRevert(PortfolioRebalancer.AllocationSumMismatch.selector);
        rebalancer.setBasket(t, f, a);
    }

    function test_setBasket_Revert_ZeroAddress() public {
        _setupInitializedContract();
        // Try to set basket with zero address
        address[] memory t = new address[](2);
        address[] memory f = new address[](2);
        uint256[] memory a = new uint256[](2);
        t[0] = address(0);
        t[1] = address(tokens[1]);
        f[0] = priceFeeds[0];
        f[1] = priceFeeds[1];
        a[0] = 500_000;
        a[1] = 500_000;

        vm.prank(owner);
        vm.expectRevert(ValidationLibrary.ZeroAddress.selector);
        rebalancer.setBasket(t, f, a);
    }

    function test_setBasket_Revert_EmptyArrays() public {
        _setupInitializedContract();
        // Try to set basket with empty arrays
        address[] memory emptyTokens = new address[](0);
        address[] memory emptyFeeds = new address[](0);
        uint256[] memory emptyAllocs = new uint256[](0);

        vm.prank(owner);
        vm.expectRevert(PortfolioRebalancer.ExceedsMaxTokens.selector);
        rebalancer.setBasket(emptyTokens, emptyFeeds, emptyAllocs);
    }

    function test_setBasket_Revert_ArrayLengthMismatch() public {
        _setupInitializedContract();
        // Try to set basket with mismatched array lengths
        address[] memory t = new address[](2);
        address[] memory f = new address[](3); // Different length
        uint256[] memory a = new uint256[](2);
        t[0] = address(tokens[0]);
        t[1] = address(tokens[1]);
        f[0] = priceFeeds[0];
        f[1] = priceFeeds[1];
        f[2] = priceFeeds[2]; // Extra feed
        a[0] = 500_000;
        a[1] = 500_000;

        vm.prank(owner);
        vm.expectRevert(ValidationLibrary.ArrayLengthMismatch.selector);
        rebalancer.setBasket(t, f, a);
    }

    function test_setBasket_Success() public {
        _setupInitializedContract();
        // Test successful basket update
        address[] memory newTokens = new address[](2);
        address[] memory newFeeds = new address[](2);
        uint256[] memory newAllocs = new uint256[](2);
        newTokens[0] = address(tokens[0]);
        newTokens[1] = address(tokens[1]);
        newFeeds[0] = priceFeeds[0];
        newFeeds[1] = priceFeeds[1];
        newAllocs[0] = 600_000;
        newAllocs[1] = 400_000;

        // Call as owner
        vm.prank(owner);
        // Record logs to check if BasketUpdated event was emitted
        vm.recordLogs();

        rebalancer.setBasket(newTokens, newFeeds, newAllocs);

        // Check that an event was emitted
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 1);
        // Check that it's the BasketUpdated event (topic0 is the event signature hash)
        assertEq(logs[0].topics[0], keccak256("BasketUpdated(address[],address[],uint256[])"));

        // Verify the basket was updated correctly
        (address token, address priceFeed, uint256 targetAllocation) = rebalancer.basket(0);
        assertEq(token, address(tokens[0]));
        assertEq(priceFeed, priceFeeds[0]);
        assertEq(targetAllocation, 600_000);

        (token, priceFeed, targetAllocation) = rebalancer.basket(1);
        assertEq(token, address(tokens[1]));
        assertEq(priceFeed, priceFeeds[1]);
        assertEq(targetAllocation, 400_000);
    }

    // --- setRebalanceThreshold Validation Tests ---
    function test_setRebalanceThreshold_Success() public {
        _setupInitializedContract();

        uint256 newThreshold = 50_000; // 5% threshold
        uint256 oldThreshold = rebalancer.rebalanceThreshold();

        // Record logs to check if RebalanceThresholdUpdated event was emitted
        vm.recordLogs();

        vm.prank(owner);
        rebalancer.setRebalanceThreshold(newThreshold);

        // Verify the threshold was updated correctly
        assertEq(rebalancer.rebalanceThreshold(), newThreshold);
        assertFalse(rebalancer.rebalanceThreshold() == oldThreshold);

        // Check that the RebalanceThresholdUpdated event was emitted
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 1);
        // Check that it's the RebalanceThresholdUpdated event (topic0 is the event signature hash)
        assertEq(logs[0].topics[0], keccak256("RebalanceThresholdUpdated(uint256)"));
        // Decode and verify the event data (newThreshold parameter)
        uint256 emittedThreshold = abi.decode(logs[0].data, (uint256));
        assertEq(emittedThreshold, newThreshold);
    }

    function test_setRebalanceThreshold_Revert_NotOwner() public {
        _setupInitializedContract();

        uint256 newThreshold = 50_000;

        // Try to call setRebalanceThreshold from non-owner address
        vm.prank(address(0x1234)); // Switch to non-owner
        vm.expectRevert(); // Should revert due to onlyOwner modifier
        rebalancer.setRebalanceThreshold(newThreshold);
    }

    // --- setAutomationEnabled Validation Tests ---
    function test_setAutomationEnabled_Success_Disable() public {
        _setupInitializedContract();

        // Initially automation should be enabled (set in initialize)
        assertTrue(rebalancer.automationEnabled());

        // Record logs to check if AutomationToggled event was emitted
        vm.recordLogs();

        vm.prank(owner);
        rebalancer.setAutomationEnabled(false);

        // Verify the automation was disabled
        assertFalse(rebalancer.automationEnabled());

        // Check that the AutomationToggled event was emitted
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 1);
        // Check that it's the AutomationToggled event (topic0 is the event signature hash)
        assertEq(logs[0].topics[0], keccak256("AutomationToggled(bool)"));
        // Decode and verify the event data (enabled parameter)
        bool emittedEnabled = abi.decode(logs[0].data, (bool));
        assertFalse(emittedEnabled);
    }

    function test_setAutomationEnabled_Success_Enable() public {
        _setupInitializedContract();

        // First disable automation
        vm.prank(owner);
        rebalancer.setAutomationEnabled(false);
        assertFalse(rebalancer.automationEnabled());

        // Record logs to check if AutomationToggled event was emitted
        vm.recordLogs();

        vm.prank(owner);
        rebalancer.setAutomationEnabled(true);

        // Verify the automation was enabled
        assertTrue(rebalancer.automationEnabled());

        // Check that the AutomationToggled event was emitted
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 1);
        // Check that it's the AutomationToggled event (topic0 is the event signature hash)
        assertEq(logs[0].topics[0], keccak256("AutomationToggled(bool)"));
        // Decode and verify the event data (enabled parameter)
        bool emittedEnabled = abi.decode(logs[0].data, (bool));
        assertTrue(emittedEnabled);
    }

    function test_setAutomationEnabled_Revert_NotOwner() public {
        _setupInitializedContract();

        // Try to call setAutomationEnabled from non-owner address
        vm.prank(address(0x1234)); // Switch to non-owner
        vm.expectRevert(); // Should revert due to onlyOwner modifier
        rebalancer.setAutomationEnabled(false);
    }

    // --- deposit Validation Tests ---
    function test_deposit_Revert_NotWhitelisted() public {
        _setupInitializedContract();

        // Create a token that's not in the basket (not whitelisted)
        MockERC20 nonWhitelistedToken = new MockERC20("NonWhitelisted", "NWL", 18, 1_000_000 ether);
        uint256 depositAmount = 1000 ether;

        // Give owner some tokens to deposit
        nonWhitelistedToken.transfer(owner, depositAmount);

        vm.prank(owner);
        vm.expectRevert(PortfolioRebalancer.NotWhitelisted.selector);
        rebalancer.deposit(address(nonWhitelistedToken), depositAmount, false);
    }

    function test_deposit_Revert_InvalidAmount() public {
        _setupInitializedContract();

        vm.prank(owner);
        vm.expectRevert(PortfolioRebalancer.InvalidAmount.selector);
        rebalancer.deposit(address(tokens[0]), 0, false);
    }

    function test_deposit_Revert_NotOwner() public {
        _setupInitializedContract();

        uint256 depositAmount = 1000 ether;

        // Try to call deposit from non-owner address
        vm.prank(address(0x1234)); // Switch to non-owner
        vm.expectRevert(); // Should revert due to onlyOwner modifier
        rebalancer.deposit(address(tokens[0]), depositAmount, false);
    }

    function test_deposit_Success_NoAutoRebalance() public {
        _setupInitializedContract();

        uint256 depositAmount = 1000 ether;
        address depositToken = address(tokens[0]);
        uint256 initialContractBalance = IERC20(depositToken).balanceOf(address(rebalancer));
        uint256 initialUserBalance = rebalancer.userBalances(owner, depositToken);

        // Give owner some tokens to deposit
        tokens[0].transfer(owner, depositAmount);

        vm.startPrank(owner);
        tokens[0].approve(address(rebalancer), depositAmount);

        // Record logs to check if Deposit event was emitted
        vm.recordLogs();

        rebalancer.deposit(depositToken, depositAmount, false);
        vm.stopPrank();

        // Verify state changes
        assertEq(rebalancer.userBalances(owner, depositToken), initialUserBalance + depositAmount);
        assertEq(IERC20(depositToken).balanceOf(address(rebalancer)), initialContractBalance + depositAmount);

        // Check swap approval was set (should be max uint256)
        assertEq(IERC20(depositToken).allowance(address(rebalancer), uniswapV3Factory), type(uint256).max);

        // Check that the Deposit event was emitted
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertTrue(logs.length >= 1, "At least one event should be emitted");

        // Find the Deposit event (there will be Transfer and possibly Approval events too)
        bool depositEventFound = false;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == keccak256("Deposit(address,address,uint256)")) {
                depositEventFound = true;
                // Verify indexed parameters (user and token)
                assertEq(logs[i].topics[1], bytes32(uint256(uint160(owner)))); // user
                assertEq(logs[i].topics[2], bytes32(uint256(uint160(depositToken)))); // token
                // Decode and verify the event data (amount parameter)
                uint256 emittedAmount = abi.decode(logs[i].data, (uint256));
                assertEq(emittedAmount, depositAmount);
                break;
            }
        }
        assertTrue(depositEventFound, "Deposit event should be emitted");
    }

    function test_deposit_Success_WithAutoRebalance() public {
        _setupInitializedContract();

        uint256 depositAmount = 1000 ether;
        address depositToken = address(tokens[0]);
        uint256 initialContractBalance = IERC20(depositToken).balanceOf(address(rebalancer));
        uint256 initialUserBalance = rebalancer.userBalances(owner, depositToken);

        // Give owner some tokens to deposit
        tokens[0].transfer(owner, depositAmount);

        vm.startPrank(owner);
        tokens[0].approve(address(rebalancer), depositAmount);

        // Record logs to check if Deposit event was emitted
        vm.recordLogs();

        rebalancer.deposit(depositToken, depositAmount, true);
        vm.stopPrank();

        // Verify state changes
        assertEq(rebalancer.userBalances(owner, depositToken), initialUserBalance + depositAmount);
        assertEq(IERC20(depositToken).balanceOf(address(rebalancer)), initialContractBalance + depositAmount);

        // Check swap approval was set (should be max uint256)
        assertEq(IERC20(depositToken).allowance(address(rebalancer), uniswapV3Factory), type(uint256).max);

        // Check that events were emitted (Deposit + potentially Rebalanced and SwapPlanned/SwapExecuted)
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertTrue(logs.length >= 1, "At least Deposit event should be emitted");

        // Find the Deposit event (should be the last one if rebalancing occurred)
        bool depositEventFound = false;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == keccak256("Deposit(address,address,uint256)")) {
                depositEventFound = true;
                // Verify indexed parameters (user and token)
                assertEq(logs[i].topics[1], bytes32(uint256(uint160(owner)))); // user
                assertEq(logs[i].topics[2], bytes32(uint256(uint160(depositToken)))); // token
                // Decode and verify the event data (amount parameter)
                uint256 emittedAmount = abi.decode(logs[i].data, (uint256));
                assertEq(emittedAmount, depositAmount);
                break;
            }
        }
        assertTrue(depositEventFound, "Deposit event should be emitted");
    }

    function test_deposit_Multiple_ChecksApprovalOnlyOnce() public {
        _setupInitializedContract();

        uint256 depositAmount = 500 ether;
        address depositToken = address(tokens[0]);

        // Give ourselves some tokens to deposit
        tokens[0].transfer(owner, depositAmount * 2);
        vm.startPrank(owner);
        tokens[0].approve(address(rebalancer), depositAmount * 2);

        // First deposit
        rebalancer.deposit(depositToken, depositAmount, false);
        uint256 allowanceAfterFirst = IERC20(depositToken).allowance(address(rebalancer), uniswapV3Factory);
        assertEq(allowanceAfterFirst, type(uint256).max);

        // Second deposit - allowance should still be max (not reset)
        rebalancer.deposit(depositToken, depositAmount, false);
        vm.stopPrank();
        uint256 allowanceAfterSecond = IERC20(depositToken).allowance(address(rebalancer), uniswapV3Factory);
        assertEq(allowanceAfterSecond, type(uint256).max);

        // Verify total user balance
        assertEq(rebalancer.userBalances(owner, depositToken), depositAmount * 2);
    }

    // --- withdraw Validation Tests ---
    function test_withdraw_Revert_NotWhitelisted() public {
        _setupInitializedContract();

        // Create a token that's not in the basket (not whitelisted)
        MockERC20 nonWhitelistedToken = new MockERC20("NonWhitelisted", "NWL", 18, 1_000_000 ether);
        uint256 withdrawAmount = 1000 ether;

        vm.prank(owner);
        vm.expectRevert(PortfolioRebalancer.NotWhitelisted.selector);
        rebalancer.withdraw(address(nonWhitelistedToken), withdrawAmount, false);
    }

    function test_withdraw_Revert_InvalidAmount() public {
        _setupInitializedContract();

        vm.prank(owner);
        vm.expectRevert(PortfolioRebalancer.InvalidAmount.selector);
        rebalancer.withdraw(address(tokens[0]), 0, false);
    }

    function test_withdraw_Revert_NotOwner() public {
        _setupInitializedContract();

        uint256 withdrawAmount = 1000 ether;

        // Try to call withdraw from non-owner address
        vm.prank(address(0x1234)); // Switch to non-owner
        vm.expectRevert(); // Should revert due to onlyOwner modifier
        rebalancer.withdraw(address(tokens[0]), withdrawAmount, false);
    }

    function test_withdraw_Revert_NotEnoughBalance() public {
        _setupInitializedContract();

        uint256 withdrawAmount = 1000 ether;
        address withdrawToken = address(tokens[0]);

        // Try to withdraw without having any balance
        vm.prank(owner);
        vm.expectRevert(PortfolioRebalancer.NotEnoughBalance.selector);
        rebalancer.withdraw(withdrawToken, withdrawAmount, false);
    }

    function test_withdraw_Revert_NotEnoughBalance_PartialBalance() public {
        _setupInitializedContract();

        uint256 depositAmount = 500 ether;
        uint256 withdrawAmount = 1000 ether; // More than deposited
        address token = address(tokens[0]);

        // First deposit some tokens
        tokens[0].transfer(owner, depositAmount);

        vm.startPrank(owner);
        tokens[0].approve(address(rebalancer), depositAmount);
        rebalancer.deposit(token, depositAmount, false);

        // Try to withdraw more than deposited
        vm.expectRevert(PortfolioRebalancer.NotEnoughBalance.selector);
        rebalancer.withdraw(token, withdrawAmount, false);
        vm.stopPrank();
    }

    function test_withdraw_Success_NoAutoRebalance() public {
        _setupInitializedContract();

        uint256 depositAmount = 1000 ether;
        uint256 withdrawAmount = 300 ether;
        address withdrawToken = address(tokens[0]);

        // First deposit some tokens
        tokens[0].transfer(owner, depositAmount);

        vm.startPrank(owner);
        tokens[0].approve(address(rebalancer), depositAmount);
        rebalancer.deposit(withdrawToken, depositAmount, false);

        // Get initial balances
        uint256 initialContractBalance = IERC20(withdrawToken).balanceOf(address(rebalancer));
        uint256 initialUserBalance = rebalancer.userBalances(owner, withdrawToken);
        uint256 initialOwnerBalance = IERC20(withdrawToken).balanceOf(owner);

        // Record logs to check if Withdraw event was emitted
        vm.recordLogs();

        rebalancer.withdraw(withdrawToken, withdrawAmount, false);
        vm.stopPrank();

        // Verify state changes
        assertEq(rebalancer.userBalances(owner, withdrawToken), initialUserBalance - withdrawAmount);
        assertEq(IERC20(withdrawToken).balanceOf(address(rebalancer)), initialContractBalance - withdrawAmount);
        assertEq(IERC20(withdrawToken).balanceOf(owner), initialOwnerBalance + withdrawAmount);

        // Check that events were emitted
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertTrue(logs.length >= 1, "At least one event should be emitted");

        // Find the Withdraw event (there will be Transfer events too)
        bool withdrawEventFound = false;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == keccak256("Withdraw(address,address,uint256)")) {
                withdrawEventFound = true;
                // Verify indexed parameters (user and token)
                assertEq(logs[i].topics[1], bytes32(uint256(uint160(owner)))); // user
                assertEq(logs[i].topics[2], bytes32(uint256(uint160(withdrawToken)))); // token
                // Decode and verify the event data (amount parameter)
                uint256 emittedAmount = abi.decode(logs[i].data, (uint256));
                assertEq(emittedAmount, withdrawAmount);
                break;
            }
        }
        assertTrue(withdrawEventFound, "Withdraw event should be emitted");
    }

    function test_withdraw_Success_WithAutoRebalance() public {
        _setupInitializedContract();

        uint256 depositAmount = 1000 ether;
        uint256 withdrawAmount = 300 ether;
        address withdrawToken = address(tokens[0]);

        // First deposit some tokens
        tokens[0].transfer(owner, depositAmount);

        vm.startPrank(owner);
        tokens[0].approve(address(rebalancer), depositAmount);
        rebalancer.deposit(withdrawToken, depositAmount, false);

        // Get initial balances
        uint256 initialContractBalance = IERC20(withdrawToken).balanceOf(address(rebalancer));
        uint256 initialUserBalance = rebalancer.userBalances(owner, withdrawToken);
        uint256 initialOwnerBalance = IERC20(withdrawToken).balanceOf(owner);

        // Record logs to check if Withdraw event was emitted
        vm.recordLogs();

        rebalancer.withdraw(withdrawToken, withdrawAmount, true);
        vm.stopPrank();

        // Verify state changes
        assertEq(rebalancer.userBalances(owner, withdrawToken), initialUserBalance - withdrawAmount);
        assertEq(IERC20(withdrawToken).balanceOf(address(rebalancer)), initialContractBalance - withdrawAmount);
        assertEq(IERC20(withdrawToken).balanceOf(owner), initialOwnerBalance + withdrawAmount);

        // Check that events were emitted (Withdraw + potentially Rebalanced and SwapPlanned/SwapExecuted)
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertTrue(logs.length >= 1, "At least Withdraw event should be emitted");

        // Find the Withdraw event
        bool withdrawEventFound = false;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == keccak256("Withdraw(address,address,uint256)")) {
                withdrawEventFound = true;
                // Verify indexed parameters (user and token)
                assertEq(logs[i].topics[1], bytes32(uint256(uint160(owner)))); // user
                assertEq(logs[i].topics[2], bytes32(uint256(uint160(withdrawToken)))); // token
                // Decode and verify the event data (amount parameter)
                uint256 emittedAmount = abi.decode(logs[i].data, (uint256));
                assertEq(emittedAmount, withdrawAmount);
                break;
            }
        }
        assertTrue(withdrawEventFound, "Withdraw event should be emitted");
    }

    function test_withdraw_Success_CompleteWithdrawal() public {
        _setupInitializedContract();

        uint256 depositAmount = 1000 ether;
        address withdrawToken = address(tokens[0]);

        // First deposit some tokens
        tokens[0].transfer(owner, depositAmount);
        vm.startPrank(owner);
        tokens[0].approve(address(rebalancer), depositAmount);
        rebalancer.deposit(withdrawToken, depositAmount, false);

        // Get initial balances
        uint256 initialContractBalance = IERC20(withdrawToken).balanceOf(address(rebalancer));
        uint256 initialOwnerBalance = IERC20(withdrawToken).balanceOf(owner);

        // Withdraw all tokens
        rebalancer.withdraw(withdrawToken, depositAmount, false);
        vm.stopPrank();

        // Verify complete withdrawal
        assertEq(rebalancer.userBalances(owner, withdrawToken), 0);
        assertEq(IERC20(withdrawToken).balanceOf(address(rebalancer)), initialContractBalance - depositAmount);
        assertEq(IERC20(withdrawToken).balanceOf(owner), initialOwnerBalance + depositAmount);
    }

    function test_withdraw_Multiple_PartialWithdrawals() public {
        _setupInitializedContract();

        uint256 depositAmount = 1000 ether;
        uint256 firstWithdraw = 300 ether;
        uint256 secondWithdraw = 200 ether;
        address withdrawToken = address(tokens[0]);

        // First deposit some tokens
        tokens[0].transfer(owner, depositAmount);
        vm.startPrank(owner);
        tokens[0].approve(address(rebalancer), depositAmount);
        rebalancer.deposit(withdrawToken, depositAmount, false);

        uint256 initialUserBalance = rebalancer.userBalances(owner, withdrawToken);

        // First withdrawal
        rebalancer.withdraw(withdrawToken, firstWithdraw, false);
        assertEq(rebalancer.userBalances(owner, withdrawToken), initialUserBalance - firstWithdraw);

        // Second withdrawal
        rebalancer.withdraw(withdrawToken, secondWithdraw, false);
        assertEq(rebalancer.userBalances(owner, withdrawToken), initialUserBalance - firstWithdraw - secondWithdraw);

        // Verify remaining balance
        uint256 expectedRemaining = depositAmount - firstWithdraw - secondWithdraw;
        assertEq(rebalancer.userBalances(owner, withdrawToken), expectedRemaining);
    }
    // --- Internal Function Tests ---
    // Using PortfolioRebalancerTestable to test internal functions:

    function test_exceedsDeviation() public {
        PortfolioRebalancerTestable testable = new PortfolioRebalancerTestable();

        // Test case: 5% actual vs 10% target with 2% threshold = exceeds (5% deviation > 2%)
        assertTrue(testable.test_exceedsDeviation(50_000, 100_000, 20_000)); // 5% vs 10%, threshold 2%

        // Test case: 9% actual vs 10% target with 2% threshold = does not exceed (1% deviation < 2%)
        assertFalse(testable.test_exceedsDeviation(90_000, 100_000, 20_000)); // 9% vs 10%, threshold 2%

        // Test case: exact match should not exceed
        assertFalse(testable.test_exceedsDeviation(100_000, 100_000, 10_000)); // 10% vs 10%

        // Test case: zero values
        assertFalse(testable.test_exceedsDeviation(0, 0, 10_000)); // 0% vs 0%
    }

    function test_sortDescending() public {
        PortfolioRebalancerTestable testable = new PortfolioRebalancerTestable();

        // Create array of TokenDelta structs
        TokenDelta[] memory deltas = new TokenDelta[](4);
        deltas[0] = TokenDelta(0, 100); // index 0, usd 100
        deltas[1] = TokenDelta(1, 500); // index 1, usd 500
        deltas[2] = TokenDelta(2, 200); // index 2, usd 200
        deltas[3] = TokenDelta(3, 300); // index 3, usd 300

        // Sort the array
        TokenDelta[] memory sorted = testable.test_sortDescending(deltas, 4);

        // Verify descending order: 500, 300, 200, 100
        assertEq(sorted[0].usd, 500); // index 1
        assertEq(sorted[0].index, 1);
        assertEq(sorted[1].usd, 300); // index 3
        assertEq(sorted[1].index, 3);
        assertEq(sorted[2].usd, 200); // index 2
        assertEq(sorted[2].index, 2);
        assertEq(sorted[3].usd, 100); // index 0
        assertEq(sorted[3].index, 0);
    }

    function test_computeDeltaUsd() public {
        PortfolioRebalancerTestable testable = new PortfolioRebalancerTestable();
        testable.initialize(tokenAddrs, priceFeeds, allocations, 10_000, uniswapV3Factory, uniswapV3SwapRouter, weth, 10, treasury, owner);

        // Setup test data: 6 tokens (matching the basket) with specific balances and prices
        uint256[] memory balances = new uint256[](6);
        uint256[] memory prices = new uint256[](6);

        // Set balances and prices for all 6 tokens
        balances[0] = 100 ether; // 100 tokens
        balances[1] = 50 ether; // 50 tokens
        balances[2] = 75 ether; // 75 tokens
        balances[3] = 25 ether; // 25 tokens
        balances[4] = 60 ether; // 60 tokens
        balances[5] = 40 ether; // 40 tokens

        // All tokens worth $1 for simplicity
        for (uint256 i = 0; i < 6; i++) {
            prices[i] = 1e18; // $1 per token
        }

        uint256 totalUSD = 350e18; // 100+50+75+25+60+40 = 350 tokens * $1 = $350

        // Compute deltas with our allocations (166,666, 166,666, 166,666, 166,666, 166,666, 166,670)
        int256[] memory deltas = testable.test_computeDeltaUsd(balances, prices, totalUSD);

        // Expected target values (allocation * totalUSD / 1e6):
        // Token 0: target = 166,666 * 350e18 / 1e6 = 58.3331e18, current = 100e18, delta = ~41.67e18
        // Token 1: target = 166,666 * 350e18 / 1e6 = 58.3331e18, current = 50e18, delta = ~-8.33e18
        // Token 5: target = 166,670 * 350e18 / 1e6 = 58.3345e18, current = 40e18, delta = ~-18.33e18

        // Verify that deltas are calculated correctly
        assertTrue(deltas[0] > 0, "Token 0 should have positive delta (over-allocated)");
        assertTrue(deltas[1] < 0, "Token 1 should have negative delta (under-allocated)");
        assertTrue(deltas[5] < 0, "Token 5 should have negative delta (under-allocated)");

        // Verify specific calculations
        uint256 expectedTarget = (166_666 * totalUSD) / 1_000_000; // ~58.3331e18
        assertEq(deltas[0], int256(100e18) - int256(expectedTarget), "Token 0 delta should match calculation");
        assertEq(deltas[1], int256(50e18) - int256(expectedTarget), "Token 1 delta should match calculation");

        // Verify the sum of deltas is approximately zero (conservation)
        int256 totalDelta = 0;
        for (uint256 i = 0; i < 6; i++) {
            totalDelta += deltas[i];
        }
        assertTrue(totalDelta < 1e15 && totalDelta > -1e15, "Total delta should be near zero");
    }
}
