// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/libraries/ValidationLibrary.sol";
import "@chainlink/shared/interfaces/AggregatorV3Interface.sol";
import "@chainlink/automation/interfaces/v2_3/IAutomationRegistryMaster2_3.sol";

/**
 * @title PriceFeedValidationTest
 * @notice Tests for price feed validation on different networks
 * @dev Tests the ValidationLibrary.validatePriceFeed and validatePriceFeeds functions
 */
contract PriceFeedValidationTest is Test {
    // Test infrastructure
    address[] public priceFeedAddresses;
    
    /// To test correct LINK address just use the registryMaster:
    IAutomationRegistryMaster2_3 public automationRegistrar;

    // Environment state
    bool public isSepoliaNetwork = false;
    string public addressBookJson;

    function setUp() public {
        console.log("Setting up PriceFeedValidation test environment...");
        
        // Detect environment and load appropriate addresses
        _loadEnvironmentAddresses();
        
        // Setup price feeds
        _setupPriceFeeds();
        
        console.log("Setup complete!");
    }

    function _loadEnvironmentAddresses() internal {
        // Try to load from address book (for Sepolia/mainnet)
        string memory filename = string.concat("addressBook/", vm.toString(block.chainid), ".json");
        console.log("Reading addresses from:", filename);
        
        try vm.readFile(filename) returns (string memory json) {
            // Sepolia network detected
            console.log("Detected Sepolia network - loading real addresses");
            isSepoliaNetwork = true;
            addressBookJson = json;
        } catch {
            // Local environment - use mock addresses
            console.log("Local environment detected - using mock addresses");
            isSepoliaNetwork = false;
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
        // Use real price feeds from Sepolia address book
        string[] memory priceFeedNames = new string[](6);
        priceFeedNames[0] = "priceFeedWETH";
        priceFeedNames[1] = "priceFeedUSDC";
        priceFeedNames[2] = "priceFeedWBTC";
        priceFeedNames[3] = "priceFeedAAVE";
        priceFeedNames[4] = "priceFeedUSDT";
        priceFeedNames[5] = "priceFeedLINK";

        for (uint256 i = 0; i < priceFeedNames.length; i++) {
            string memory feedPath = string.concat(".chainlink.", priceFeedNames[i]);
            address priceFeedAddress = vm.parseJsonAddress(addressBookJson, feedPath);
            priceFeedAddresses.push(priceFeedAddress);
            console.log("Added real price feed", priceFeedNames[i], "at:", priceFeedAddress);
        }        
    }

    function _setupMockPriceFeeds() internal {
        // Create mock price feed addresses for local testing
        for (uint256 i = 0; i < 6; i++) {
            priceFeedAddresses.push(address(uint160(0x1000 + i)));
        }
    }

    // =============== TEST LINK TOKEN ADDRESS ===============
    function test_checkLinkTokenAddress() public {
        if (isSepoliaNetwork) {
            address automationRegistryAddress = vm.parseJsonAddress(addressBookJson, ".chainlink.automationRegistry");
            address myLinkAddress = vm.parseJsonAddress(addressBookJson, ".coins.LINK");

            /// Call get link address on automation registrar:
            automationRegistrar = IAutomationRegistryMaster2_3(payable(automationRegistryAddress));
            address registryLinkAddress = automationRegistrar.getLinkAddress();
            
            assertEq(registryLinkAddress, myLinkAddress, "Registry link address does not match my link address");
            console.log("Automation Registry LINK address:", address(registryLinkAddress));
            console.log("Link token address:", myLinkAddress);
        } else {
            console.log("Skipping link token address test - not on Sepolia");
        }
    }

    // =============== PRICE FEED VALIDATION TESTS ===============

    function test_checkPriceFeedsOnSepolia() public {
        console.log("=== TESTING PRICE FEEDS ON SEPOLIA ===");
        
        // Only run this test on Sepolia
        if (!isSepoliaNetwork) {
            console.log("Skipping price feed test - not on Sepolia");
            return;
        }

        // Test the ValidationLibrary.validatePriceFeeds function
        console.log("Testing ValidationLibrary.validatePriceFeeds...");
        
        // Call the validation function through a wrapper
        _validatePriceFeedsWithLibrary();
        console.log("All price feeds passed validation!");
    }

    function test_checkPriceFeedsDetailed() public {
        console.log("=== DETAILED PRICE FEED CHECK ===");
        
        if (!isSepoliaNetwork) {
            console.log("Skipping detailed price feed test - not on Sepolia");
            return;
        }

        _debugPriceFeeds();
    }

    function _validatePriceFeedsWithLibrary() internal view {
        // Create memory arrays for the library function
        address[] memory feedsMemory = new address[](priceFeedAddresses.length);
        for (uint256 i = 0; i < priceFeedAddresses.length; i++) {
            feedsMemory[i] = priceFeedAddresses[i];
        }
        
        // Call the validation logic directly
        _validatePriceFeedsDirectly(feedsMemory);
    }

    function _validatePriceFeedsDirectly(address[] memory feeds) internal view {
        for (uint256 i = 0; i < feeds.length; i++) {
            ValidationLibrary.validatePriceFeed(feeds[i]);
        }
    }

    function _debugPriceFeeds() internal view {
        console.log("\n=== DETAILED PRICE FEED DEBUG ===");
        
        for (uint256 i = 0; i < priceFeedAddresses.length; i++) {
            console.log(string.concat("Checking price feed ", vm.toString(i), " at ", vm.toString(priceFeedAddresses[i])));
            
            try AggregatorV3Interface(priceFeedAddresses[i]).latestRoundData() returns (
                uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound
            ) {
                console.log(string.concat("  Round ID: ", vm.toString(roundId)));
                console.log(string.concat("  Answer: ", vm.toString(answer)));
                console.log(string.concat("  Started at: ", vm.toString(startedAt)));
                console.log(string.concat("  Updated at: ", vm.toString(updatedAt)));
                console.log(string.concat("  Answered in round: ", vm.toString(answeredInRound)));
                console.log(string.concat("  Block timestamp: ", vm.toString(block.timestamp)));
                console.log(string.concat("  Age (seconds): ", vm.toString(block.timestamp - updatedAt)));
                
                if (answer <= 0) {
                    console.log("  WARNING: Invalid answer (<= 0)");
                }
                if (updatedAt == 0) {
                    console.log("  WARNING: No update timestamp");
                }
                
                // Check if feed is stale (more than 1 hour old)
                if (block.timestamp - updatedAt > 3600) {
                    console.log("  WARNING: Price feed is stale (> 1 hour old)");
                }
                
            } catch Error(string memory reason) {
                console.log(string.concat("  ERROR: Price feed call failed: ", reason));
            } catch {
                console.log("  ERROR: Unknown price feed error");
            }
        }
        console.log("=== END PRICE FEED DEBUG ===");
    }
}
