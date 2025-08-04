# Address Book

This directory contains the contract addresses for various networks used in the Portfolio Rebalancer project.

## Networks

- `1.json` - Ethereum Mainnet
- `11155111.json` - Sepolia Testnet
- `8453.json` - Base Mainnet

## Uniswap V3 Integration Status

**✅ MIGRATED TO V3:** This project now uses Uniswap V3 with battle-tested addresses and proven liquidity.

### V3 Contract Structure

The project uses standard Uniswap V3 architecture:

- **Factory**: Creates and manages pools (`0x1F98431c8aD98523631AE4a59f267346ea31F984` on mainnet)
- **SwapRouter02**: Handles swaps (`0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45` on mainnet)
- **QuoterV2**: Price quotes (`0x61fFE014bA17989E743c5F6cB21bF9697530B21e` on mainnet)

### Current Addresses

All address books now contain **real, live V3 addresses**:

- **Mainnet**: Production addresses
- **Sepolia**: Testnet addresses
- **Base**: L2 production addresses

### V3 vs V4 Comparison

| Aspect           | V3 (Current)     | V4 (Future)            |
| ---------------- | ---------------- | ---------------------- |
| **Liquidity**    | $100B+ proven    | New, growing           |
| **Architecture** | ✅ Stable        | 🔄 Singleton (complex) |
| **Integration**  | ✅ Simple        | 🔄 Hooks required      |
| **Ecosystem**    | ✅ Complete      | 🔄 Developing          |
| **Risk**         | 🟢 Battle-tested | 🟡 New architecture    |

### Migration Notes

- ✅ **Pool lookups**: Now include fee parameter (default 3000 = 0.3%)
- ✅ **Swap routing**: Uses proven `SwapRouter02` pattern
- ✅ **Addresses**: All networks use real, deployed V3 contracts
