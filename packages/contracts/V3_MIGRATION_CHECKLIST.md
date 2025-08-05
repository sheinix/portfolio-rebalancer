# V3 Migration Checklist

## ✅ COMPLETED

- [x] Updated address books with real V3 addresses (factory, router, quoter)
- [x] Created `IUniswapV3.sol` interface with proper V3 patterns
- [x] Updated `PortfolioRebalancer.sol` main logic
- [x] Updated pool checking to include fee parameter (`DEFAULT_FEE = 3000`)
- [x] Fixed interface imports and function signatures

## 🔄 REMAINING (Complete These)

### 1. Update Treasury Script Parameters

```bash
# In script/PortfolioTreasury.s.sol - Update ALL occurrences:
# Find: uniswapV4Router  →  Replace: uniswapV3Router
# Find: ".uniswap.uniswapV4Router"  →  Replace: ".uniswap.router"
# Find: "Uniswap V4 Router"  →  Replace: "Uniswap V3 Router"
```

### 2. Update Factory Script

```bash
# In script/PortfolioRebalancerFactory.s.sol:
# Find: uniswapV4Factory  →  Replace: uniswapV3Factory
# Find: ".uniswap.uniswapV4Factory"  →  Replace: ".uniswap.factory"
```

### 3. Update Main Deployment Script

```bash
# In script/PortfolioRebalancer.s.sol:
# Find: uniswapV4Router  →  Replace: uniswapV3Router
# Find: ".uniswap.uniswapV4Router"  →  Replace: ".uniswap.router"
```

### 4. Update Query Script

```bash
# In script/QueryDeployments.s.sol:
# Find: "Uniswap V4 Router"  →  Replace: "Uniswap V3 Router"
# Find: ".uniswap.uniswapV4Router"  →  Replace: ".uniswap.router"
```

### 5. Update Treasury Contract Methods

```solidity
// In src/PortfolioTreasury.sol - Update validation function:
require(treasuryContract.uniswapV3Router() == expectedRouter, "Uniswap router mismatch");
```

### 6. Update ALL Test Files

```bash
# In test/PortfolioRebalancer.t.sol:
# Find: uniswapV4Factory  →  Replace: uniswapV3Factory
# Find: .uniswapV4Factory()  →  Replace: .uniswapV3Factory()
# Update all test deployments to use V3 factory
```

## 🚀 Quick Fix Commands

Run these commands to complete the migration:

```bash
# 1. Update Treasury script
find packages/contracts/script -name "*.sol" -exec sed -i '' 's/uniswapV4Router/uniswapV3Router/g' {} \;
find packages/contracts/script -name "*.sol" -exec sed -i '' 's/\.uniswap\.uniswapV4Router/.uniswap.router/g' {} \;

# 2. Update Factory references
find packages/contracts -name "*.sol" -exec sed -i '' 's/uniswapV4Factory/uniswapV3Factory/g' {} \;
find packages/contracts -name "*.sol" -exec sed -i '' 's/\.uniswap\.uniswapV4Factory/.uniswap.factory/g' {} \;

# 3. Update comments
find packages/contracts -name "*.sol" -exec sed -i '' 's/Uniswap V4/Uniswap V3/g' {} \;
```

## ✅ Final Testing

1. **Compile**: `forge clean && forge compile`
2. **Test**: `forge test`
3. **Deploy**: Test on Sepolia first

## 📊 Migration Impact

**Time Estimate**: 30 minutes to complete remaining changes
**Risk Level**: 🟢 Low (patterns already established)
**Benefits**:

- ✅ Battle-tested V3 architecture
- ✅ $100B+ proven liquidity
- ✅ Complete ecosystem support
- ✅ Minimal ongoing maintenance
