// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "./interfaces/IAutomationRegistrar.sol";
import {ValidationLibrary} from "./libraries/ValidationLibrary.sol";

/**
 * @title PortfolioTreasury
 * @notice Holds LINK and other tokens, swaps to LINK, and funds vault automation. Supports dynamic tokens and role-based access.
 * @dev UUPS upgradeable treasury contract.
 */
contract PortfolioTreasury is Initializable, UUPSUpgradeable, AccessControlUpgradeable {
    using SafeERC20 for IERC20;
    using ValidationLibrary for address;
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant SWAPER_ROLE = keccak256("SWAPER_ROLE");
    bytes32 public constant FUNDER_ROLE = keccak256("FUNDER_ROLE");
    bytes32 public constant FACTORY_ROLE = keccak256("FACTORY_ROLE");

    mapping(address => bool) public supportedTokens;
    mapping(address => uint256) public upkeepOf; // vault address => upkeep ID

    address public link;
    address public uniswapV3Router;
    IAutomationRegistrar public automationRegistrar;

    event SupportedTokenAdded(address token);
    event UniswapV3RouterChanged(address newRouter);
    event VaultFunded(address indexed vault, uint256 amount);
    event Swapped(address indexed fromToken, address indexed toToken, uint256 amountIn, uint256 amountOut);
    event Donation(address indexed donor, address indexed token, uint256 amount);
    event UpkeepRegistered(address indexed vault, uint256 indexed upkeepId, uint96 linkAmount);

    /**
     * @notice Initialize treasury with LINK address, Uniswap V3 router, automation registrar, and admin.
     * @param _link LINK token address
     * @param _uniswapV3Router Uniswap V3 router address
     * @param _automationRegistrar Chainlink Automation Registrar address
     * @param admin Admin address
     */
    function initialize(address _link, address _uniswapV3Router, address payable _automationRegistrar, address admin)
        external
        initializer
    {
        __UUPSUpgradeable_init();
        __AccessControl_init();

        link = _link;
        uniswapV3Router = _uniswapV3Router;
        automationRegistrar = IAutomationRegistrar(_automationRegistrar);
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
    }

    /**
     * @notice Add a new supported token. Only ADMIN.
     * @param token ERC20 token address
     */
    function addSupportedToken(address token) external onlyRole(ADMIN_ROLE) {
        supportedTokens[token] = true;
        emit SupportedTokenAdded(token);
    }

    /**
     * @notice Change Uniswap V4 router. Only ADMIN.
     * @param newRouter New router address
     */
    function setUniswapV3Router(address newRouter) external onlyRole(ADMIN_ROLE) {
        uniswapV3Router = newRouter;
        emit UniswapV3RouterChanged(newRouter);
    }

    /**
     * @notice Swap any supported token to LINK using Uniswap V4. Only SWAPER.
     * @param tokenIn Token to swap from
     * @param amountIn Amount to swap
     * @param fee Uniswap pool fee
     * @param amountOutMin Minimum LINK to receive
     * @return amountOut Amount of LINK received
     */
    function swapToLink(address tokenIn, uint256 amountIn, uint24 fee, uint256 amountOutMin)
        external
        onlyRole(SWAPER_ROLE)
        returns (uint256 amountOut)
    {
        require(supportedTokens[tokenIn], "Not supported");
        IERC20(tokenIn).approve(uniswapV3Router, amountIn);
        amountOut = ISwapRouter(uniswapV3Router).exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: link,
                fee: fee,
                recipient: address(this),
                deadline: block.timestamp + 300, // 5 minutes deadline
                amountIn: amountIn,
                amountOutMinimum: amountOutMin,
                sqrtPriceLimitX96: 0
            })
        );
        emit Swapped(tokenIn, link, amountIn, amountOut);
    }

    /**
     * @notice Fund a vault with LINK. Only FUNDER.
     * @param vault Vault address
     * @param amount Amount of LINK to send
     */
    function fundVault(address vault, uint256 amount) external onlyRole(FUNDER_ROLE) {
        IERC20(link).safeTransfer(vault, amount);
        emit VaultFunded(vault, amount);
    }

    /**
     * @notice Donate any supported token to the treasury.
     * @param token ERC20 token address
     * @param amount Amount to donate
     */
    function donate(address token, uint256 amount) external {
        require(supportedTokens[token], "Not supported");
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        emit Donation(msg.sender, token, amount);
    }

    /**
     * @notice Register a vault for Chainlink Automation and fund its upkeep
     * @param upkeepContract The vault contract address to be automated
     * @param checkData ABI-encoded data for checkUpkeep function
     * @param gasLimit Gas limit for performUpkeep function
     * @param linkAmount Amount of LINK to fund the upkeep
     * @param admin The address that will be the admin of the upkeep
     * @param name Name of the upkeep
     * @param encryptedEmail Encrypted email for the upkeep contact
     * @return upkeepId The ID of the registered upkeep
     */
    function registerAndFundUpkeep(
        address upkeepContract, 
        bytes calldata checkData, 
        uint32 gasLimit, 
        uint96 linkAmount,
        address admin,
        string calldata name,
        bytes calldata encryptedEmail
    )
        external
        onlyRole(FACTORY_ROLE)
        returns (uint256)
    {
        ValidationLibrary.validateNonZeroAddress(admin);
        ValidationLibrary.validateNonZeroAddress(upkeepContract);

        // Ensure link amount is reasonable (at least 0.1 LINK)
        require(linkAmount >= 0.1 ether, "Link amount too low");
        // Ensure we have enough LINK to fund the upkeep
        require(IERC20(link).balanceOf(address(this)) >= linkAmount, "Insufficient LINK balance");
        // Ensure gas limit is reasonable (between 50k and 500k for most networks)
        require(gasLimit >= 50_000 && gasLimit <= 500_000, "Invalid gas limit");

        // Approve LINK for the registrar
        IERC20(link).approve(address(automationRegistrar), linkAmount);
        
        // Create RegistrationParams struct
        IAutomationRegistrar.RegistrationParams memory params = IAutomationRegistrar.RegistrationParams({
            name: name,
            encryptedEmail: encryptedEmail,
            upkeepContract: upkeepContract,
            gasLimit: gasLimit,
            adminAddress: admin,
            triggerType: 0, // 0 = conditional
            billingToken: IERC20(link),
            checkData: checkData,
            triggerConfig: "", // empty for conditional
            offchainConfig: "", // empty
            amount: linkAmount
        });

        // Register the upkeep with Chainlink Automation Registrar
        uint256 upkeepId = automationRegistrar.registerUpkeep(params);

        // Store the mapping of vault to upkeep ID
        upkeepOf[upkeepContract] = upkeepId;

        emit UpkeepRegistered(upkeepContract, upkeepId, linkAmount);

        return upkeepId;
    }

    /**
     * @notice Set factory role for a contract (only admin)
     * @param factory Factory contract address
     */
    function setFactory(address factory) external onlyRole(ADMIN_ROLE) {
        _grantRole(FACTORY_ROLE, factory);
    }

    /**
     * @dev Authorizes contract upgrades. Only ADMIN can upgrade.
     */
    function _authorizeUpgrade(address) internal override onlyRole(ADMIN_ROLE) {}

    /**
     * @dev Returns the storage slot that the proxiable contract assumes is being used to store the implementation
     * address. This is needed because we need to know this slot so the UpgradeableBeacon can set the storage slot
     * associated with this implementation.
     */
    function proxiableUUID() external pure override returns (bytes32) {
        return 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    }
}
