## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Etherscan Verification

Deploy contracts with automatic verification on block explorers:

```shell
# Setup environment
cp env.example .env
# Fill in your API keys and private key

# Deploy with verification (recommended)
forge script script/PortfolioRebalancer.s.sol \
  --rpc-url sepolia \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify

# Or use the helper script
./script/examples/DeployWithVerification.sh
```

**Required API Keys:**

- [Etherscan](https://etherscan.io/apis) - For Ethereum networks
- [Polygonscan](https://polygonscan.com/apis) - For Polygon networks
- [Arbiscan](https://arbiscan.io/apis) - For Arbitrum networks
- [Optimistic Etherscan](https://optimistic.etherscan.io/apis) - For Optimism networks
- [Basescan](https://basescan.org/apis) - For Base networks

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
