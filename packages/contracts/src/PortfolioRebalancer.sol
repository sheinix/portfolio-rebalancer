// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "solmate/utils/FixedPointMathLib.sol";
import "@chainlink/shared/interfaces/AggregatorV3Interface.sol";
import "@chainlink/automation/AutomationCompatible.sol";
import "./interfaces/IUniswapV3.sol";
import "./libraries/ValidationLibrary.sol";
import "./libraries/PortfolioLogicLibrary.sol";
import "./libraries/PortfolioStructs.sol";

event SwapExecuted(
    address indexed user, address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut
);

event SwapPlanned(address indexed user, address indexed tokenIn, address indexed tokenOut, uint256 usdAmount);

/**
 * @title PortfolioRebalancer
 * @notice Upgradeable contract for managing and auto-rebalancing a basket of ERC-20 tokens per user.
 * @dev Uses Transparent Proxy pattern, Ownable, ReentrancyGuard, Chainlink Keeper-compatible, uses custom errors for gas savings.
 */
contract PortfolioRebalancer is
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    AutomationCompatibleInterface
{
    using FixedPointMathLib for uint256;
    using SafeERC20 for IERC20;
    using ValidationLibrary for address;
    using ValidationLibrary for address[];
    using PortfolioLogicLibrary for TokenInfo[];

    // Uniswap V3 factory address (set at initialization)
    address public uniswapV3Factory;

    // Default fee tier for V3 pools (0.3% = 3000)
    uint24 public constant DEFAULT_FEE = 3000;

    // Constants
    uint256 public constant MAX_TOKENS = 6;
    uint256 public constant ALLOCATION_SCALE = 1e6; // 100% = 1,000,000

    // List of basket tokens
    TokenInfo[] public basket;
    // token address => index in basket
    mapping(address => uint256) public tokenIndex;
    // token address => whitelisted
    mapping(address => bool) public isWhitelisted;

    // user => token => balance
    mapping(address => mapping(address => uint256)) public userBalances;

    // tokenA => tokenB => pool address
    mapping(address => mapping(address => address)) public swapPools;

    // Rebalance threshold (in ALLOCATION_SCALE units, e.g. 0.01 = 10,000)
    uint256 public rebalanceThreshold;

    // Immutable fee parameters
    uint256 public feeBps; // Immutable after initialization
    address public treasury; // Immutable after initialization
    bool public automationEnabled;

    // Events
    event Deposit(address indexed user, address indexed token, uint256 amount);
    event Withdraw(address indexed user, address indexed token, uint256 amount);
    event BasketUpdated(address[] tokens, address[] priceFeeds, uint256[] allocations);
    event Rebalanced(address indexed user);
    event RebalanceThresholdUpdated(uint256 newThreshold);
    event AutomationToggled(bool enabled);

    // Errors
    error NotWhitelisted();
    error InvalidToken();
    error InvalidAmount();
    error NotUser();
    error AllocationSumMismatch();
    error ExceedsMaxTokens();
    error NotEnoughBalance();
    error NoRebalanceNeeded();

    // Initializer
    /**
     * @notice Initializes the contract with all parameters. Fee and treasury are immutable after this call.
     * @param tokens ERC-20 token addresses.
     * @param priceFeeds Chainlink price feed addresses for each token.
     * @param allocations Target allocations (scaled by ALLOCATION_SCALE, sum == ALLOCATION_SCALE).
     * @param _rebalanceThreshold Allowed deviation before auto-rebalance (e.g. 10,000 = 1%).
     * @param _uniswapV3Factory Uniswap V3 factory address.
     * @param _feeBps Fee in basis points (e.g., 10 = 0.1%). Immutable after initialization.
     * @param _treasury Treasury address for fee collection. Immutable after initialization.
     * @param _owner The owner of this vault (usually the user who called createVault).
     */
    function initialize(
        address[] calldata tokens,
        address[] calldata priceFeeds,
        uint256[] calldata allocations,
        uint256 _rebalanceThreshold,
        address _uniswapV3Factory,
        uint256 _feeBps,
        address _treasury,
        address _owner
    ) external initializer {
        _treasury.validateTreasury();
        _uniswapV3Factory.validateFactory();
        _owner.validateNonZeroAddress();

        __Ownable_init(_owner);
        __ReentrancyGuard_init();
        uniswapV3Factory = _uniswapV3Factory;
        _setBasket(tokens, priceFeeds, allocations);
        rebalanceThreshold = _rebalanceThreshold;
        feeBps = _feeBps;
        treasury = _treasury;
        automationEnabled = true;
    }

    // Basket Management
    /**
     * @notice Vault owner can update the basket tokens, price feeds, and allocations.
     * @param tokens ERC-20 token addresses.
     * @param priceFeeds Chainlink price feed addresses for each token.
     * @param allocations Target allocations (scaled by ALLOCATION_SCALE, sum == ALLOCATION_SCALE).
     */
    function setBasket(address[] calldata tokens, address[] calldata priceFeeds, uint256[] calldata allocations)
        external
        onlyOwner
    {
        _setBasket(tokens, priceFeeds, allocations);
    }

    function _setBasket(address[] calldata tokens, address[] calldata priceFeeds, uint256[] calldata allocations)
        internal
    {
        uint256 len = tokens.length;
        if (len == 0 || len > MAX_TOKENS) revert ExceedsMaxTokens();
        ValidationLibrary.validateArrayLengths(len, priceFeeds.length, allocations.length);
        uint256 sum;
        _clearBasketAndWhitelist();
        
        // Validate tokens, price feeds, and pools - get pool addresses
        tokens.validateNonZeroAddresses();
        priceFeeds.validatePriceFeeds();
        address[][] memory poolAddresses = ValidationLibrary.validateAndGetUniswapV3Pools(tokens, uniswapV3Factory, DEFAULT_FEE);
        
        // Cache pool addresses for all token pairs
        for (uint256 i = 0; i < len; i++) {
            for (uint256 j = 0; j < len; j++) {
                if (i != j && poolAddresses[i][j] != address(0)) {
                    swapPools[tokens[i]][tokens[j]] = poolAddresses[i][j];
                }
            }
        }
        
        for (uint256 i = 0; i < len; i++) {
            basket.push(TokenInfo({token: tokens[i], priceFeed: priceFeeds[i], targetAllocation: allocations[i]}));
            tokenIndex[tokens[i]] = i;
            isWhitelisted[tokens[i]] = true;
            sum += allocations[i];
        }
        if (sum != ALLOCATION_SCALE) revert AllocationSumMismatch();
        emit BasketUpdated(tokens, priceFeeds, allocations);
    }

    /**
     * @dev Clears the basket array and resets the whitelist mapping.
     */
    function _clearBasketAndWhitelist() internal {
        for (uint256 i = 0; i < basket.length; i++) {
            isWhitelisted[basket[i].token] = false;
        }
        delete basket;
    }

    /**
     * @notice Vault owner can update the rebalance threshold.
     * @param newThreshold New threshold (in ALLOCATION_SCALE units).
     */
    function setRebalanceThreshold(uint256 newThreshold) external onlyOwner {
        rebalanceThreshold = newThreshold;
        emit RebalanceThresholdUpdated(newThreshold);
    }

    /**
     * @notice Toggle Chainlink automation for this vault. Only callable by the vault owner.
     * @param enabled True to enable automation, false to disable.
     */
    function setAutomationEnabled(bool enabled) external onlyOwner {
        automationEnabled = enabled;
        emit AutomationToggled(enabled);
    }

    // Deposit & Withdraw
    /**
     * @notice Deposit a whitelisted token into your vault. Only callable by the vault owner.
     * @param token ERC-20 token address.
     * @param amount Amount to deposit.
     * @param autoRebalance If true, triggers a rebalance after deposit. If false, only updates balances.
     *
     * @dev
     * Use autoRebalance = false when:
     *   - Building your initial portfolio (multiple deposits, avoid unnecessary swaps/gas).
     *   - Batching deposits for gas efficiency.
     * Use autoRebalance = true when:
     *   - You want your portfolio to match target allocations after every deposit.
     *   - You want immediate rebalancing after a single deposit.
     */
    function deposit(address token, uint256 amount, bool autoRebalance) external nonReentrant onlyOwner {
        if (!isWhitelisted[token]) revert NotWhitelisted();
        if (amount == 0) revert InvalidAmount();
        userBalances[msg.sender][token] += amount;
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        _ensureSwapApproval(token); // Infinite-approve for Uniswap V3 swaps
        if (autoRebalance) {
            (, PortfolioSnapshot memory snapshot) = _needsRebalance(msg.sender);
            _rebalance(msg.sender, snapshot);
        }
        emit Deposit(msg.sender, token, amount);
    }

    /**
     * @notice Withdraw a token from your vault. Only callable by the vault owner.
     * @param token ERC-20 token address.
     * @param amount Amount to withdraw.
     * @param autoRebalance If true, triggers a rebalance after withdrawal. If false, only updates balances.
     *
     * @dev
     * Use autoRebalance = false when:
     *   - Withdrawing as part of a batch of actions (avoid unnecessary swaps/gas).
     *   - Managing your portfolio manually for gas efficiency.
     * Use autoRebalance = true when:
     *   - You want your portfolio to match target allocations after every withdrawal.
     *   - You want immediate rebalancing after a single withdrawal.
     */
    function withdraw(address token, uint256 amount, bool autoRebalance) external nonReentrant onlyOwner {
        if (!isWhitelisted[token]) revert NotWhitelisted();
        if (amount == 0) revert InvalidAmount();
        uint256 bal = userBalances[msg.sender][token];
        if (bal < amount) revert NotEnoughBalance();
        userBalances[msg.sender][token] = bal - amount;
        IERC20(token).safeTransfer(msg.sender, amount);
        if (autoRebalance) {
            (, PortfolioSnapshot memory snapshot) = _needsRebalance(msg.sender);
            _rebalance(msg.sender, snapshot);
        }
        emit Withdraw(msg.sender, token, amount);
    }

    // Rebalance Logic
    /**
     * @notice Manually rebalance your vault to match target allocations using Uniswap V3. Only callable by the vault owner.
     */
    function rebalance() external nonReentrant onlyOwner {
        (, PortfolioSnapshot memory snapshot) = _needsRebalance(msg.sender);
        _rebalance(msg.sender, snapshot);
    }

    /**
     * @notice Chainlink Keeper checkUpkeep: checks if any user's portfolio needs rebalancing.
     * @dev For demo: only checks msg.sender (in production, would need off-chain user list or event-based triggers).
     */
    function checkUpkeep(bytes calldata) external view override returns (bool upkeepNeeded, bytes memory performData) {
        address user = msg.sender;
        (bool needs, PortfolioSnapshot memory snapshot) = _needsRebalance(user);
        if (needs) {
            upkeepNeeded = true;
            performData = abi.encode(user, snapshot);
        }
    }

    /**
     * @notice Chainlink Keeper performUpkeep: rebalances the user's portfolio if needed.
     * @param performData Encoded user address and snapshot.
     */
    function performUpkeep(bytes calldata performData) external override nonReentrant {
        (address user, PortfolioSnapshot memory snapshot) = abi.decode(performData, (address, PortfolioSnapshot));
        _rebalance(user, snapshot);
    }

    /**
     * @dev Helper function to extract user balances into an array
     */
    function _getUserBalancesArray(address user) internal view returns (uint256[] memory balances) {
        uint256 len = basket.length;
        balances = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            balances[i] = userBalances[user][basket[i].token];
        }
    }

    /**
     * @dev Checks if user's portfolio deviates from target allocations beyond threshold.
     *      Returns (needsRebalance, snapshot) for efficient reuse.
     */
    function _needsRebalance(address user) internal view returns (bool, PortfolioSnapshot memory) {
        uint256[] memory balances = _getUserBalancesArray(user);
        return PortfolioLogicLibrary.needsRebalance(basket, balances, rebalanceThreshold);
    }

    /**
     * @dev Computes the USD delta for each token: currentUsd - targetUsd.
     */
    function _computeDeltaUsd(uint256[] memory balances, uint256[] memory prices, uint256 totalUSD)
        internal
        view
        returns (int256[] memory)
    {
        return PortfolioLogicLibrary.computeDeltaUsd(basket, balances, prices, totalUSD);
    }

    /**
     * @dev Performs the rebalance for a user using Greedy Pairwise Matching. Assumes infinite approvals are set in deposit().
     *      Emits SwapPlanned before each swap and SwapExecuted after.
     */
    function _rebalance(address user, PortfolioSnapshot memory snapshot) internal {
        uint256 len = basket.length;
        uint256[] memory balances = snapshot.balances;
        uint256[] memory prices = snapshot.prices;
        uint256 totalUSD = snapshot.totalUSD;
        int256[] memory deltas = _computeDeltaUsd(balances, prices, totalUSD);

        // Partition into sellers (delta > 0) and buyers (delta < 0)
        TokenDelta[] memory sellers = new TokenDelta[](len);
        TokenDelta[] memory buyers = new TokenDelta[](len);
        uint256 sellerCount = 0;
        uint256 buyerCount = 0;
        for (uint256 i = 0; i < len; i++) {
            if (deltas[i] > 0) {
                sellers[sellerCount++] = TokenDelta(i, deltas[i]);
            } else if (deltas[i] < 0) {
                buyers[buyerCount++] = TokenDelta(i, -deltas[i]); // store as positive for easier math
            }
        }
        // Sort sellers and buyers by usd descending (simple selection sort, fine for small N)
        PortfolioLogicLibrary.sortDescending(sellers, sellerCount);
        PortfolioLogicLibrary.sortDescending(buyers, buyerCount);

        uint256 s = 0;
        uint256 b = 0;
        while (s < sellerCount && b < buyerCount) {
            uint256 tradeUsd =
                uint256(sellers[s].usd) < uint256(buyers[b].usd) ? uint256(sellers[s].usd) : uint256(buyers[b].usd);
            uint256 sellIdx = sellers[s].index;
            uint256 buyIdx = buyers[b].index;
            address tokenIn = basket[sellIdx].token;
            address tokenOut = basket[buyIdx].token;
            address pool = swapPools[tokenIn][tokenOut];
            if (pool == address(0)) {
                // skip if no pool (should not happen)
                if (sellers[s].usd <= buyers[b].usd) s++;
                else b++;
                continue;
            }
            // Calculate amountToSell in tokenIn decimals
            uint256 amountToSell = tradeUsd.divWadDown(prices[sellIdx]);
            emit SwapPlanned(user, tokenIn, tokenOut, tradeUsd);
            (, int256 amount1) = IUniswapV3Pool(pool).swap(
                address(this),
                true, // tokenIn -> tokenOut
                int256(amountToSell),
                0,
                ""
            );
            emit SwapExecuted(user, tokenIn, tokenOut, amountToSell, uint256(amount1));
            // Update deltas
            sellers[s].usd -= int256(tradeUsd);
            buyers[b].usd -= int256(tradeUsd);
            if (sellers[s].usd == 0) s++;
            if (buyers[b].usd == 0) b++;
        }
        emit Rebalanced(user);
    }



    /**
     * @dev Internal: returns the total USD value of a user's portfolio.
     */
    function _portfolioValueUSD(address user) internal view returns (uint256 total) {
        uint256[] memory balances = _getUserBalancesArray(user);
        return PortfolioLogicLibrary.portfolioValueUSD(basket, balances);
    }





    /**
     * @dev Ensures the contract has infinite approval for the token to the Uniswap V3 factory (or router/pool as needed).
     *      Only sets approval if allowance is low, to save gas.
     */
    function _ensureSwapApproval(address token) internal {
        address spender = uniswapV3Factory; // Set to router/pool if needed
        if (IERC20(token).allowance(address(this), spender) < type(uint256).max / 2) {
            IERC20(token).approve(spender, type(uint256).max);
        }
    }





    // Internal fee transfer
    /**
     * @dev Deducts the configured fee and sends it to the treasury. Fee and treasury are immutable after initialization.
     */
    function _takeFee(address token, uint256 amount) internal returns (uint256 netAmount) {
        if (feeBps == 0 || treasury == address(0)) return amount;
        uint256 fee = (amount * feeBps) / 10000;
        if (fee > 0) {
            IERC20(token).safeTransfer(treasury, fee);
        }
        return amount - fee;
    }

    // View Helpers
    /**
     * @notice Returns the basket tokens.
     */
    function getBasket() external view returns (TokenInfo[] memory) {
        return basket;
    }

    /**
     * @notice Returns a user's balances for all basket tokens.
     * @param user The user address.
     */
    function getUserBalances(address user) external view returns (uint256[] memory balances) {
        balances = new uint256[](basket.length);
        for (uint256 i = 0; i < basket.length; i++) {
            balances[i] = userBalances[user][basket[i].token];
        }
    }

    /**
     * @notice Returns the Uniswap V4 factory address.
     */
    function getUniswapV3Factory() external view returns (address) {
        return uniswapV3Factory;
    }
}
