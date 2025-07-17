// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IUniswapV4.sol";

/**
 * @title PortfolioTreasury
 * @notice Holds LINK and other tokens, swaps to LINK, and funds vault automation. Supports dynamic tokens and role-based access.
 */
contract PortfolioTreasury is AccessControl {
    using SafeERC20 for IERC20;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant SWAPER_ROLE = keccak256("SWAPER_ROLE");
    bytes32 public constant FUNDER_ROLE = keccak256("FUNDER_ROLE");

    mapping(address => bool) public supportedTokens;
    address public link;
    address public uniswapV4Router;

    event SupportedTokenAdded(address token);
    event UniswapV4RouterChanged(address newRouter);
    event VaultFunded(address indexed vault, uint256 amount);
    event Swapped(address indexed fromToken, address indexed toToken, uint256 amountIn, uint256 amountOut);
    event Donation(address indexed donor, address indexed token, uint256 amount);

    /**
     * @notice Initialize treasury with LINK address, Uniswap V4 router, and admin.
     * @param _link LINK token address
     * @param _uniswapV4Router Uniswap V4 router address
     * @param admin Admin address
     */
    constructor(address _link, address _uniswapV4Router, address admin) {
        link = _link;
        uniswapV4Router = _uniswapV4Router;
        _setupRole(DEFAULT_ADMIN_ROLE, admin);
        _setupRole(ADMIN_ROLE, admin);
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
    function setUniswapV4Router(address newRouter) external onlyRole(ADMIN_ROLE) {
        uniswapV4Router = newRouter;
        emit UniswapV4RouterChanged(newRouter);
    }

    /**
     * @notice Swap any supported token to LINK using Uniswap V4. Only SWAPER.
     * @param tokenIn Token to swap from
     * @param amountIn Amount to swap
     * @param fee Uniswap pool fee
     * @param amountOutMin Minimum LINK to receive
     * @return amountOut Amount of LINK received
     */
    function swapToLink(address tokenIn, uint256 amountIn, uint24 fee, uint256 amountOutMin) external onlyRole(SWAPER_ROLE) returns (uint256 amountOut) {
        require(supportedTokens[tokenIn], "Not supported");
        IERC20(tokenIn).safeApprove(uniswapV4Router, amountIn);
        amountOut = IUniswapV4Router(uniswapV4Router).exactInputSingle(
            tokenIn,
            link,
            fee,
            address(this),
            amountIn,
            amountOutMin,
            0
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
} 