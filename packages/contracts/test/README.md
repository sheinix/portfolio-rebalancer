# Portfolio Rebalancer Tests

This directory contains comprehensive tests for the Portfolio Rebalancer smart contracts.

## Test Files

### `PortfolioRebalancer.t.sol`

- Unit tests for the core PortfolioRebalancer contract
- Uses mocked dependencies for isolated testing
- Tests individual contract functionality

### `VaultCreation.t.sol` ⭐ **NEW**

- **End-to-end integration tests for vault creation**
- **Tests the complete PortfolioRebalancerFactory deployment flow**
- **Works on both local (Anvil) and Sepolia testnet environments**
- **Full infrastructure setup with real or mocked dependencies**

## Running Vault Creation Tests

### Local Testing (Anvil)

```bash
# Start local node
anvil

# Run vault creation tests locally
forge test --match-contract VaultCreationTest -vvv

# Run specific test
forge test --match-test test_createVault_Success -vvv
```

### Sepolia Testnet Testing

```bash
# Set environment variables
export ETHEREUM_SEPOLIA_RPC_URL="https://sepolia.infura.io/v3/YOUR_KEY"
export PRIVATE_KEY="0x..."

# Run tests on Sepolia (uses real Uniswap V3 addresses)
forge test --match-contract VaultCreationTest --fork-url $ETHEREUM_SEPOLIA_RPC_URL -vvv
```

## What VaultCreation Tests Cover

### ✅ **Infrastructure Deployment**

- PortfolioRebalancer implementation
- PortfolioRebalancerFactory with proxy
- PortfolioTreasury with proxy
- ProxyAdmin for upgrade management
- Mock tokens and price feeds
- Uniswap V3 integration (real addresses on testnet)

### ✅ **Vault Creation Process**

- `test_createVault_Success()` - Complete vault creation (works on both environments)
- `test_createVault_MultipleVaults()` - Multiple vaults with different configs
- `test_createVault_EmitsEvent()` - Event emission verification
- `test_vault_BasicFunctionality()` - Vault deposit/withdraw after creation (mock tokens only)
- `test_createVault_WithRealSepoliaTokens()` - **Sepolia-only test with real WETH, USDC, WBTC, AAVE tokens**

### ✅ **Error Handling**

- `test_createVault_Revert_InvalidAllocationSum()` - Invalid allocation percentages
- `test_createVault_Revert_ArrayLengthMismatch()` - Mismatched array lengths

### ✅ **Multi-Environment Support**

- **Local (Anvil)**: Deploys mock infrastructure, mock tokens, mock price feeds
- **Sepolia**: Uses real Uniswap V3 contracts, **real ERC20 tokens (WETH, USDC, WBTC, AAVE), real Chainlink price feeds**
- **Mainnet**: Can use real addresses from address book

## Environment Detection

The tests automatically detect the environment:

```solidity
// Tries to load from address book
try vm.readFile(".../addressBook/11155111.json") {
    // Sepolia detected - use real addresses
    uniswapV3Factory = parseJsonAddress(json, ".uniswap.factory");
    // Load real tokens: WETH, USDC, WBTC, AAVE
    tokenAddresses.push(parseJsonAddress(json, ".coins.WETH"));
    // Load real price feeds: priceFeedWETH, priceFeedUSDC, etc.
    priceFeedAddresses.push(parseJsonAddress(json, ".chainlink.priceFeedWETH"));
    // ...
} catch {
    // Local detected - deploy mocks
    uniswapV3Factory = address(new MockUniswapV3Factory());
    tokens.push(new MockERC20("Test Token", "TEST", 18, 1_000_000 ether));
    priceFeedAddresses.push(address(new MockPriceFeed(1e18)));
    // ...
}
```

## Key Features Tested

### **Factory Deployment & Configuration**

- Proper initialization with implementation addresses
- Fee settings and admin roles
- Treasury integration

### **Vault Creation Parameters**

- **Token basket configuration** (Mock tokens locally, real WETH/USDC/WBTC/AAVE on Sepolia)
- **Price feed integration** (Mock feeds locally, real Chainlink price feeds on Sepolia)
- Allocation percentages (must sum to 1,000,000)
- Rebalance threshold settings
- Uniswap V3 factory integration

### **Chainlink Integration**

- Automation registry setup
- LINK token funding
- Upkeep registration for automated rebalancing

### **Access Control**

- Vault ownership assignment
- Treasury role management
- Factory admin permissions

## Sample Test Output

```bash
## Local Testing Output
[PASS] test_createVault_Success() (gas: 2847293)
Logs:
  Setting up VaultCreation test environment...
  Local environment detected - deploying mock infrastructure
  Deployed mock Uniswap V3 Factory: 0x...
  Deployed mock LINK Token: 0x...
  Setting up mock tokens for local testing...
  Setting up mock price feeds for local testing...
  Setup 4 tokens
  Setup 4 price feeds
  Infrastructure deployment complete!
  Created vault at: 0x...

## Sepolia Testing Output
[PASS] test_createVault_WithRealSepoliaTokens() (gas: 3124782)
Logs:
  Setting up VaultCreation test environment...
  Detected Sepolia network - loading real addresses
  Loaded Uniswap V3 Factory: 0x0227628f3F023bb0B980b67D528571c95c6DaC1c
  Setting up real Sepolia tokens...
  Added real token WETH at: 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14
  Added real token USDC at: 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238
  Added real token WBTC at: 0x29f2D40B0605204364af54EC677bD022dA425d03
  Added real token AAVE at: 0x88541670E55cC00bEEFD87eB59EDd1b7C511AC9a
  Setting up real Sepolia price feeds...
  Added real price feed priceFeedWETH at: 0x694AA1769357215DE4FAC081bf1f309aDC325306
  Created vault with real Sepolia tokens at: 0x...
```

## Usage in CI/CD

These tests are perfect for:

- ✅ **Local development** - Fast feedback with mocked dependencies
- ✅ **CI/CD pipelines** - Automated testing on every commit
- ✅ **Testnet validation** - End-to-end testing before mainnet
- ✅ **Integration testing** - Verify complete system works together

## Next Steps

1. **Run the tests**: `forge test --match-contract VaultCreationTest -vvv`
2. **Deploy to testnet**: Use the tested factory to create real vaults
3. **Monitor automation**: Verify Chainlink automation works correctly
4. **Scale testing**: Add more complex scenarios and edge cases
