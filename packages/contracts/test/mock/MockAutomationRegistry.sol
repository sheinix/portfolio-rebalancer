// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract MockAutomationRegistry {
    /// @notice Mapping of upkeep ID to amount of LINK added to the upkeep
    mapping(uint256 => uint256) private upkeepFunds;
    uint256 private nextUpkeepId = 1;
    
    function registerUpkeep(
        address target,
        uint32 gasLimit,
        address admin,
        uint8 triggerType,
        address billingToken,
        bytes calldata checkData,
        bytes calldata triggerConfig,
        bytes calldata offchainConfig
    ) external returns (uint256) {
        uint256 upkeepId = nextUpkeepId++;
        upkeepFunds[upkeepId] = 0;
        return upkeepId;
    }
    
    // Simplified overload for testing
    function registerUpkeep(
        address target,
        uint32 gasLimit,
        address admin,
        uint8 triggerType,
        address billingToken
    ) external returns (uint256) {
        uint256 upkeepId = nextUpkeepId++;
        upkeepFunds[upkeepId] = 0;
        return upkeepId;
    }

    function addFunds(uint256 upkeepId, uint96 amount) external {
        upkeepFunds[upkeepId] += amount;
    }
}