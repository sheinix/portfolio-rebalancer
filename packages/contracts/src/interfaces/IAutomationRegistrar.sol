// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IAutomationRegistrar
 * @notice Minimal interface for Chainlink Automation Registrar v2.3
 * @dev This interface only includes the functions we need to avoid version compatibility issues
 */
interface IAutomationRegistrar {
    struct RegistrationParams {
        address upkeepContract;
        uint96 amount;
        address adminAddress;
        uint32 gasLimit;
        uint8 triggerType;
        IERC20 billingToken;
        string name;
        bytes encryptedEmail;
        bytes checkData;
        bytes triggerConfig;
        bytes offchainConfig;
    }

    /**
     * @notice Register a new upkeep
     * @param requestParams The registration parameters
     * @return upkeepId The ID of the registered upkeep
     */
    function registerUpkeep(RegistrationParams memory requestParams) external payable returns (uint256);

    /**
     * @notice Get the LINK token address
     * @return The LINK token address
     */
    function i_LINK() external view returns (address);
}
