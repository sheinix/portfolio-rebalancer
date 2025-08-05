// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IUniswapV3.sol";
import "@chainlink/automation/interfaces/v2_3/IAutomationRegistryMaster2_3.sol";

/**
 * @title PortfolioTreasury
 * @notice Holds LINK and other tokens, swaps to LINK, and funds vault automation. Supports dynamic tokens and role-based access.
 * @dev UUPS upgradeable treasury contract.
 */
contract PortfolioTreasury is Initializable, UUPSUpgradeable, AccessControlUpgradeable {
    using SafeERC20 for IERC20;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant SWAPER_ROLE = keccak256("SWAPER_ROLE");
    bytes32 public constant FUNDER_ROLE = keccak256("FUNDER_ROLE");
    bytes32 public constant FACTORY_ROLE = keccak256("FACTORY_ROLE");

    mapping(address => bool) public supportedTokens;
    mapping(address => uint256) public upkeepOf; // vault address => upkeep ID

    address public link;
    address public uniswapV3Router;
    IAutomationRegistryMaster2_3 public automationRegistry;

    event SupportedTokenAdded(address token);
    event UniswapV3RouterChanged(address newRouter);
    event VaultFunded(address indexed vault, uint256 amount);
    event Swapped(address indexed fromToken, address indexed toToken, uint256 amountIn, uint256 amountOut);
    event Donation(address indexed donor, address indexed token, uint256 amount);
    event UpkeepRegistered(address indexed vault, uint256 indexed upkeepId, uint96 linkAmount);

    /**
     * @notice Initialize treasury with LINK address, Uniswap V3 router, automation registry, and admin.
     * @param _link LINK token address
     * @param _uniswapV3Router Uniswap V3 router address
     * @param _automationRegistry Chainlink Automation Registry address
     * @param admin Admin address
     */
    function initialize(address _link, address _uniswapV3Router, address payable _automationRegistry, address admin)
        external
        initializer
    {
        __UUPSUpgradeable_init();
        __AccessControl_init();

        link = _link;
        uniswapV3Router = _uniswapV3Router;
        automationRegistry = IAutomationRegistryMaster2_3(_automationRegistry);
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
        amountOut = ISwapRouter02(uniswapV3Router).exactInputSingle(
            ISwapRouter02.ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: link,
                fee: fee,
                recipient: address(this),
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
     * @return upkeepId The ID of the registered upkeep
     */
    function registerAndFundUpkeep(address upkeepContract, bytes calldata checkData, uint32 gasLimit, uint96 linkAmount)
        external
        onlyRole(FACTORY_ROLE)
        returns (uint256)
    {
        // Ensure we have enough LINK to fund the upkeep
        require(IERC20(link).balanceOf(address(this)) >= linkAmount, "Insufficient LINK balance");

        // Register the upkeep with Chainlink Automation Registry
        uint256 upkeepId = automationRegistry.registerUpkeep(
            upkeepContract, // target contract
            gasLimit, // gas limit for performUpkeep
            address(this), // admin (this treasury contract)
            0, // trigger type (0 = conditional)
            link, // billing token (LINK)
            checkData, // check data
            "", // trigger config (empty for conditional)
            "" // offchain config (empty)
        );

        // Add funds to the upkeep
        IERC20(link).approve(address(automationRegistry), linkAmount);
        automationRegistry.addFunds(upkeepId, linkAmount);

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
}
