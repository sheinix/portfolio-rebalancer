# Address Book

This directory contains chain-specific address configurations for deploying the Portfolio Rebalancer contracts.

## Structure

Each file is named by chain ID: `{chainId}.json`

### Supported Networks

- **Ethereum Mainnet**: `1.json`
- **Sepolia Testnet**: `11155111.json`
- **Example Deployed**: `example-deployed.json` (shows complete deployment record)

## Deployment Scripts Architecture

The deployment system uses a **modular architecture** with specialized scripts for each component:

### Script Responsibilities

| Script                             | Responsibility     | Deploys                                                    |
| ---------------------------------- | ------------------ | ---------------------------------------------------------- |
| `PortfolioTreasury.s.sol`          | 🏦 Treasury System | Treasury implementation + proxy                            |
| `PortfolioRebalancerFactory.s.sol` | 🏭 Factory System  | Portfolio impl + Factory impl + Factory proxy + ProxyAdmin |
| `PortfolioRebalancer.s.sol`        | 🎼 Orchestration   | Calls treasury and factory scripts                         |
| `QueryDeployments.s.sol`           | 🔍 Query Utility   | Reads deployment information                               |

### Benefits of Modular Architecture

- **🎯 Single Responsibility**: Each script focuses on one main component
- **🔧 Modular Deployment**: Deploy components separately as needed
- **🧪 Easier Testing**: Test individual components in isolation
- **📝 Cleaner Code**: No more monolithic deployment scripts
- **🔄 Reusable Components**: Scripts can be composed for different needs

## File Format

```json
{
  "network": "sepolia",
  "chainId": 11155111,
  "coins": {
    "LINK": "0x326C977E6efc84E512bB9C30f76E30c160eD06FB",
    "USDC": "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238",
    "WETH": "0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14",
    "..."
  },
  "chainlink": {
    "priceFeedWETH": "0x694AA1769357215DE4FAC081bf1f309aDC325306",
    "priceFeedUSDC": "0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E",
    "priceFeedLINK": "0xc59E3633BAAC79493d908e63626716e204A45EdF",
    "..."
  },
  "uniswap": {
    "uniswapV4Factory": "0x...",
    "uniswapV4Router": "0x..."
  },
  "portfolioRebalancer": {
    "implementation": "0x...",
    "factoryImplementation": "0x...",
    "factory": "0x...",
    "treasury": "0x...",
    "treasuryImplementation": "0x...",
    "proxyAdmin": "0x...",
    "deploymentBlock": "12345678",
    "deploymentTimestamp": "1640995200",
    "treasuryDeploymentBlock": "12345677",
    "treasuryDeploymentTimestamp": "1640995180"
  }
}
```

## Deployment Commands

### Full System Deployment (Recommended)

```bash
# Deploy complete system using addressBook
forge script script/PortfolioRebalancer.s.sol --rpc-url sepolia --broadcast

# Deploy complete system WITH Etherscan verification (RECOMMENDED)
forge script script/PortfolioRebalancer.s.sol --rpc-url sepolia --broadcast --verify

# Deploy with custom treasury parameters
forge script script/PortfolioRebalancer.s.sol \
  --sig "runWithCustomTreasury(address,address,address)" \
  0x326C977E6efc84E512bB9C30f76E30c160eD06FB \
  0x1111111111111111111111111111111111111111 \
  0xYourTreasuryAdmin \
  --rpc-url sepolia --broadcast

# Deploy with full custom parameters
forge script script/PortfolioRebalancer.s.sol \
  --sig "runWithCustomParams(address,address,address,address,uint256)" \
  0x326C977E6efc84E512bB9C30f76E30c160eD06FB \
  0x1111111111111111111111111111111111111111 \
  0xTreasuryAdmin \
  0xFactoryAdmin \
  100 \
  --rpc-url sepolia --broadcast
```

### Individual Component Deployment

```bash
# Deploy only Treasury
forge script script/PortfolioTreasury.s.sol --rpc-url sepolia --broadcast

# Deploy Treasury WITH Etherscan verification
forge script script/PortfolioTreasury.s.sol --rpc-url sepolia --broadcast --verify

# Deploy only Factory (requires existing treasury)
forge script script/PortfolioRebalancerFactory.s.sol --rpc-url sepolia --broadcast

# Deploy Factory WITH Etherscan verification
forge script script/PortfolioRebalancerFactory.s.sol --rpc-url sepolia --broadcast --verify

# Deploy Factory with custom treasury
forge script script/PortfolioRebalancerFactory.s.sol \
  --sig "deployWithTreasury(address)" \
  0xYourTreasuryAddress \
  --rpc-url sepolia --broadcast
```

### Query Deployment Information

```bash
# Query all deployment info for current network
forge script script/QueryDeployments.s.sol --rpc-url sepolia

# Query specific chain deployment info
forge script script/QueryDeployments.s.sol --sig "queryChain(uint256)" 11155111 --rpc-url sepolia

# Get factory address for integration
forge script script/QueryDeployments.s.sol --sig "getFactory()" --rpc-url sepolia

# Get all key addresses at once
forge script script/QueryDeployments.s.sol --sig "getKeyAddresses()" --rpc-url sepolia
```

## Deployment Tracking

The deployment scripts automatically update the addressBook files with deployed contract addresses and metadata:

### Tracked Information

- **Contract Addresses**: All implementation and proxy addresses
- **Deployment Metadata**: Block numbers and timestamps for audit trails
- **Network Information**: Chain ID and network name for reference

### Auto-Populated Fields

| Field                         | Description                         | Updated By                 |
| ----------------------------- | ----------------------------------- | -------------------------- |
| `implementation`              | Portfolio vault implementation      | Factory deployment script  |
| `factoryImplementation`       | Factory implementation              | Factory deployment script  |
| `factory`                     | Factory proxy (main entry point)    | Factory deployment script  |
| `treasury`                    | Treasury proxy                      | Treasury deployment script |
| `treasuryImplementation`      | Treasury implementation             | Treasury deployment script |
| `proxyAdmin`                  | ProxyAdmin for vault upgrades       | Factory deployment script  |
| `deploymentBlock`             | Block number of factory deployment  | Factory deployment script  |
| `deploymentTimestamp`         | Timestamp of factory deployment     | Factory deployment script  |
| `treasuryDeploymentBlock`     | Block number of treasury deployment | Treasury deployment script |
| `treasuryDeploymentTimestamp` | Timestamp of treasury deployment    | Treasury deployment script |

## Reading Deployed Addresses

After deployment, you can read the deployed addresses from the updated addressBook:

```bash
# Get factory address for interacting with the protocol
cat addressBook/11155111.json | jq -r '.portfolioRebalancer.factory'

# Get treasury address for fee collection tracking
cat addressBook/11155111.json | jq -r '.portfolioRebalancer.treasury'

# Get deployment block for event filtering
cat addressBook/11155111.json | jq -r '.portfolioRebalancer.deploymentBlock'
```

### Integration Examples

```bash
# Create a new vault using the deployed factory
cast call $(cat addressBook/11155111.json | jq -r '.portfolioRebalancer.factory') \
  "createVault(address[],address[],uint256[],uint256,address)" \
  [token1,token2] [feed1,feed2] [500000,500000] 10000 $(cat addressBook/11155111.json | jq -r '.uniswap.uniswapV4Factory')

# Check treasury LINK balance
cast call $(cat addressBook/11155111.json | jq -r '.coins.LINK') \
  "balanceOf(address)" \
  $(cat addressBook/11155111.json | jq -r '.portfolioRebalancer.treasury')
```

## Deployment Workflow

1. **Pre-deployment**: Ensure all required addresses (LINK, price feeds, etc.) are populated in addressBook
2. **Treasury Deployment**: `PortfolioTreasury.s.sol` deploys treasury and updates addressBook
3. **Factory Deployment**: `PortfolioRebalancerFactory.s.sol` deploys factory system and updates addressBook
4. **Full System**: `PortfolioRebalancer.s.sol` orchestrates both deployments with final summary
5. **Query/Verify**: Use `QueryDeployments.s.sol` to verify deployment and get addresses

## Etherscan Verification Setup

### Prerequisites for Contract Verification

1. **Get API Keys** from block explorers:

   ```bash
   # Add to your .env file
   ETHERSCAN_API_KEY=your_etherscan_api_key_here
   POLYGONSCAN_API_KEY=your_polygonscan_api_key_here
   ARBISCAN_API_KEY=your_arbiscan_api_key_here
   OPTIMISTIC_API_KEY=your_optimistic_etherscan_api_key_here
   BASESCAN_API_KEY=your_basescan_api_key_here
   ```

2. **Supported Networks** (configured in `foundry.toml`):
   - Ethereum Mainnet & Sepolia
   - Polygon & Mumbai
   - Arbitrum One & Sepolia
   - Optimism & Sepolia
   - Base & Sepolia

### Automatic Verification During Deployment

```bash
# Add --verify flag to any deployment command
forge script script/PortfolioRebalancer.s.sol \
  --rpc-url sepolia \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify
```

### Manual Verification (if automatic fails)

```bash
# Verify Treasury Implementation
forge verify-contract $TREASURY_IMPL \
  src/PortfolioTreasury.sol:PortfolioTreasury \
  --chain-id 11155111 \
  --watch

# Verify Factory Implementation
forge verify-contract $FACTORY_IMPL \
  src/PortfolioRebalancerFactory.sol:PortfolioRebalancerFactory \
  --chain-id 11155111 \
  --watch

# Verify Portfolio Implementation
forge verify-contract $PORTFOLIO_IMPL \
  src/PortfolioRebalancer.sol:PortfolioRebalancer \
  --chain-id 11155111 \
  --watch
```

**Note**: Proxy contracts are automatically recognized by Etherscan and linked to their implementations.

## Adding New Networks

1. Create a new file: `{chainId}.json`
2. Fill in the network-specific addresses (coins, chainlink, uniswap)
3. Leave `portfolioRebalancer` fields empty (they'll be auto-populated)
4. Deploy using any of the deployment commands above

## Upgrade Scenarios

### Treasury Upgrade

```bash
# Deploy new treasury implementation
forge script script/PortfolioTreasury.s.sol --rpc-url sepolia --broadcast

# Update factory to use new treasury (if needed)
cast call $FACTORY "setTreasury(address)" $NEW_TREASURY_ADDRESS
```

### Factory Upgrade

```bash
# Deploy new factory system
forge script script/PortfolioRebalancerFactory.s.sol --rpc-url sepolia --broadcast

# Users migrate to new factory for new vaults
# Existing vaults continue working with old factory
```

## Address Sources

- **LINK Token**: [Chainlink Documentation](https://docs.chain.link/resources/link-token-contracts)
- **Price Feeds**: [Chainlink Data Feeds](https://docs.chain.link/data-feeds/price-feeds/addresses)
- **USDC/USDT/WETH**: Token contract addresses from respective protocols
- **Uniswap V4**: Update when V4 addresses are available

## Notes

- Use `0x0000000000000000000000000000000000000000` for addresses not yet available
- The `portfolioRebalancer` section gets populated automatically during deployment
- Always verify addresses before mainnet deployment
- Deployment metadata enables easy audit trails and event filtering
- AddressBook serves as single source of truth for all contract addresses
- Use modular deployment scripts for maximum flexibility and maintainability
