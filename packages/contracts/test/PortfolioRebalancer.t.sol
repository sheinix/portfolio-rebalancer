// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/PortfolioRebalancer.sol";
import "./mock/MockERC20.sol";

contract PortfolioRebalancerTest is Test {
    PortfolioRebalancer rebalancer;
    MockERC20[6] tokens;
    address[] tokenAddrs;
    address[] priceFeeds;
    uint256[] allocations;
    address owner = address(0xABCD);
    address treasury = address(0xBEEF);
    address uniswapV4Factory = address(0xCAFE);

    function setUp() public {
        _setupTokens();
        _setupAllocations();
        _setupMocking();
        rebalancer = new PortfolioRebalancer();
    }

    function _setupTokens() internal {
        for (uint i = 0; i < 6; i++) {
            tokens[i] = new MockERC20(string(abi.encodePacked("Token", vm.toString(i))), string(abi.encodePacked("T", vm.toString(i))), 18, 1_000_000 ether);
            tokenAddrs.push(address(tokens[i]));
            priceFeeds.push(address(uint160(0x1000 + i))); // Dummy price feed addresses
        }
    }

    function _setupAllocations() internal {
        // Initialize allocations array with even split
        allocations = new uint256[](6);
        for (uint i = 0; i < 6; i++) {
            allocations[i] = 166_666; // 1e6 / 6 = 166,666.67... (even split)
        }
        // Add the remainder to the last allocation to ensure sum equals 1e6
        allocations[5] = 166_670; // 166,666 * 5 + 166,670 = 1,000,000
    }

    // Helper function to set up comprehensive mocking
    function _setupMocking() internal {
        // Mock all price feeds
        for (uint i = 0; i < 6; i++) {
            vm.mockCall(
                address(uint160(0x1000 + i)), // priceFeeds[i]
                0,
                abi.encodeWithSignature("latestRoundData()"),
                abi.encode(uint80(1), int256(1e18), uint256(block.timestamp), uint256(block.timestamp), uint80(1))
            );
        }
        
        // Mock Uniswap factory calls for all token pairs
        for (uint i = 0; i < 6; i++) {
            for (uint j = 0; j < 6; j++) {
                if (i != j) {
                    vm.mockCall(
                        uniswapV4Factory,
                        0,
                        abi.encodeWithSignature("getPool(address,address)"),
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
    }

    function _setupInitializedContract() internal {
        rebalancer.initialize(tokenAddrs, priceFeeds, allocations, 10_000, uniswapV4Factory, 10, treasury);
    }

    // initialize Validation Tests
    function test_initialize_Revert_ExceedsMaxTokens() public {
        // Try to initialize with too many tokens
        address[] memory tooMany = new address[](7);
        address[] memory feeds = new address[](7);
        uint256[] memory allocs = new uint256[](7);
        for (uint i = 0; i < 7; i++) {
            tooMany[i] = address(tokens[0]);
            feeds[i] = priceFeeds[0];
            if (i < 6) {
                allocs[i] = 142_857; // 1e6 / 7 ≈ 142,857
            } else {
                allocs[i] = 142_858; // Make up the difference to get exactly 1e6
            }
        }
        
        vm.expectRevert(PortfolioRebalancer.ExceedsMaxTokens.selector);
        rebalancer.initialize(tooMany, feeds, allocs, 10_000, uniswapV4Factory, 10, treasury);
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
        rebalancer.initialize(t, f, a, 10_000, uniswapV4Factory, 10, treasury);
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
        
        vm.expectRevert(PortfolioRebalancer.ZeroAddress.selector);
        rebalancer.initialize(t, f, a, 10_000, uniswapV4Factory, 10, treasury);
    }

    function test_initialize_Success() public {
        // Test successful initialization
        rebalancer.initialize(tokenAddrs, priceFeeds, allocations, 10_000, uniswapV4Factory, 10, treasury);
        
        // Verify the basket was set correctly
        (address token, address priceFeed, uint256 targetAllocation) = rebalancer.basket(0);
        assertEq(token, address(tokens[0]));
        assertEq(priceFeed, priceFeeds[0]);
        assertEq(targetAllocation, allocations[0]);
        assertEq(rebalancer.rebalanceThreshold(), 10_000);
        assertEq(rebalancer.feeBps(), 10);
        assertEq(rebalancer.treasury(), treasury);
        assertEq(rebalancer.uniswapV4Factory(), uniswapV4Factory);
    }

    function test_initialize_Revert_EmptyArrays() public {
        // Try to initialize with empty arrays
        address[] memory emptyTokens = new address[](0);
        address[] memory emptyFeeds = new address[](0);
        uint256[] memory emptyAllocs = new uint256[](0);
        
        vm.expectRevert(PortfolioRebalancer.ExceedsMaxTokens.selector);
        rebalancer.initialize(emptyTokens, emptyFeeds, emptyAllocs, 10_000, uniswapV4Factory, 10, treasury);
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
        
        vm.expectRevert(PortfolioRebalancer.AllocationSumMismatch.selector);
        rebalancer.initialize(t, f, a, 10_000, uniswapV4Factory, 10, treasury);
    }

    function test_initialize_Revert_ZeroTreasury() public {
        // Try to initialize with zero treasury address
        vm.expectRevert(PortfolioRebalancer.ZeroTreasury.selector);
        rebalancer.initialize(tokenAddrs, priceFeeds, allocations, 10_000, uniswapV4Factory, 10, address(0));
    }

    function test_initialize_Revert_ZeroFactory() public {
        // Try to initialize with zero factory address
        vm.expectRevert(PortfolioRebalancer.ZeroFactory.selector);
        rebalancer.initialize(tokenAddrs, priceFeeds, allocations, 10_000, address(0), 10, treasury);
    }

    function test_initialize_Revert_DoubleInitialization() public {
        // Initialize once successfully
        rebalancer.initialize(tokenAddrs, priceFeeds, allocations, 10_000, uniswapV4Factory, 10, treasury);
        
        // Try to initialize again (should revert due to initializer modifier)
        vm.expectRevert();
        rebalancer.initialize(tokenAddrs, priceFeeds, allocations, 10_000, uniswapV4Factory, 10, treasury);
    }

    function test_setBasket_Revert_ExceedsMaxTokens() public {
        _setupInitializedContract();
        // Try to set basket with too many tokens
        address[] memory tooMany = new address[](7);
        address[] memory feeds = new address[](7);
        uint256[] memory allocs = new uint256[](7);
        for (uint i = 0; i < 7; i++) {
            tooMany[i] = address(tokens[0]);
            feeds[i] = priceFeeds[0];
            if (i < 6) {
                allocs[i] = 142_857; // 1e6 / 7 ≈ 142,857
            } else {
                allocs[i] = 142_858; // Make up the difference to get exactly 1e6
            }
        }
        
        vm.expectRevert(PortfolioRebalancer.ExceedsMaxTokens.selector);
        rebalancer.setBasket(tooMany, feeds, allocs);
    }

    function test_setBasket_Revert_NoPoolForToken() public {
        _setupInitializedContract();
        
        // Override mock so the Uniswap factory returns address(0) for getPool calls
        vm.mockCall(
            uniswapV4Factory,
            0,
            abi.encodeWithSignature("getPool(address,address)"),
            abi.encode(address(0)) // Return address(0) to simulate no pool
        );
        
        vm.expectRevert(PortfolioRebalancer.NoPoolForToken.selector);
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
        
        vm.expectRevert(PortfolioRebalancer.ZeroAddress.selector);
        rebalancer.setBasket(t, f, a);
    }

    function test_setBasket_Revert_EmptyArrays() public {
        _setupInitializedContract();
        // Try to set basket with empty arrays
        address[] memory emptyTokens = new address[](0);
        address[] memory emptyFeeds = new address[](0);
        uint256[] memory emptyAllocs = new uint256[](0);
        
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
        
        vm.expectRevert(PortfolioRebalancer.AllocationSumMismatch.selector);
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
        
        rebalancer.setBasket(newTokens, newFeeds, newAllocs);
        
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

    // --- _exceedsDeviation ---
    // Note: _exceedsDeviation is internal, so we test it indirectly through public functions
    // that use it, like _needsRebalance or by testing the rebalance logic

    // Note: _sortDescending is internal, so we test it indirectly through the rebalance logic
    // The sorting is used in _rebalance function when sorting sellers and buyers

    // --- _computeDeltaUsd ---
    // Note: _computeDeltaUsd is internal, so we test it indirectly through the rebalance logic
    // The delta computation is used in _rebalance function to determine trades needed

    // Add more tests for edge cases, revert scenarios, and other helpers as needed
} 