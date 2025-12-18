# Portfolio Rebalancer

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Solidity](https://img.shields.io/badge/Solidity-^0.8.24-blue.svg)](https://docs.soliditylang.org/en/v0.8.24/)

A modular, upgradeable smart contract system for creating per-user portfolio rebalancing vaults on EVM-compatible blockchains. Each user can deploy their own vault (proxy) with a custom basket of ERC-20 tokens and target allocations, and the vault will automatically or manually rebalance using Uniswap V3 and Chainlink Automation.

> **⚠️ Disclaimer:** This is a personal project for fun and is currently in progress. The code has not been audited and should not be used in production without proper security review. Use at your own risk.

---

## Features

- **Per-user vaults:** Each user owns and configures their own rebalancing vault via proxy.
- **Customizable baskets:** Users select up to 6 ERC-20 tokens and set target allocations (must sum to 100%).
- **Automated & manual rebalancing:** Uses Chainlink Automation and Uniswap V3 for swaps.
- **Upgradeable:** Built with OpenZeppelin UUPS proxies for future-proofing.
- **Factory contract:** Easy deployment of user vaults with a single transaction.
- **Security:** All sensitive actions are restricted to the vault owner.

---

## Architecture (WIP)

![Architecture Diagram WIP](docs/architecture.png)

```
User <-> PortfolioRebalancerFactory <-> TransparentUpgradeableProxy (user's vault) <-> PortfolioRebalancer (implementation)
                                                      |
                                              PortfolioTreasury (LINK funding & automation)
```

- **PortfolioRebalancer:** The core logic contract (upgradeable, no state).
- **TransparentUpgradeableProxy:** Per-user proxy vault, holds user state and delegates to implementation.
- **PortfolioRebalancerFactory:** Deploys new proxies for users and initializes them.
- **PortfolioTreasury:** Manages LINK tokens, swaps tokens to LINK, and registers Chainlink Automation upkeeps for vaults.

---

## Prerequisites

- Node.js (>= 16.x)
- npm or yarn
- [Foundry](https://book.getfoundry.sh/) (for Solidity development)
- [OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts) and [OpenZeppelin Upgrades](https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable)

---

## Installation

```bash
# Clone the repo
$ git clone <your-repo-url>
$ cd portfolio-rebalancer

# Install dependencies for dapp (frontend)
$ cd packages/dapp && npm install

# (Optional) Install Foundry for Solidity development
$ curl -L https://foundry.paradigm.xyz | bash
$ foundryup
```

---

## Contracts

### Core Contracts

- `PortfolioRebalancer.sol` — Upgradeable vault logic (per-user, via proxy)
- `PortfolioRebalancerFactory.sol` — Deploys new user vaults (proxies)
- `PortfolioTreasury.sol` — Manages LINK tokens and Chainlink Automation registration

### Interfaces

- `IPortfolioRebalancer.sol` — Interface for PortfolioRebalancer
- `IAutomationRegistrar.sol` — Chainlink Automation Registrar interface

### Libraries

- `PortfolioLogicLibrary.sol` — Core rebalancing logic and calculations
- `PortfolioSwapLibrary.sol` — Uniswap V3 swap execution logic
- `PortfolioStructs.sol` — Shared data structures
- `ValidationLibrary.sol` — Input validation utilities

---

## Deployment & Usage

For automated deployment, use the provided scripts in `packages/contracts/script/`:

- `PortfolioRebalancer.s.sol` — Full system deployment (Treasury + Factory)
- `PortfolioTreasury.s.sol` — Treasury deployment
- `PortfolioRebalancerFactory.s.sol` — Factory deployment
- `deploy` — Bash script for multi-network deployment with verification
- `deploy-upgrades` — Bash script for upgrading existing contracts

### Manual Deployment Steps

**1. Deploy the Treasury**

Deploy `PortfolioTreasury.sol` (UUPS upgradeable) with LINK token address, Uniswap V3 router, and Chainlink Automation Registrar.

**2. Deploy the Implementation**

Deploy `PortfolioRebalancer.sol` (upgradeable) to your target network.

**3. Deploy the Factory**

Deploy `PortfolioRebalancerFactory.sol` (UUPS upgradeable), passing the implementation address, treasury address, fee basis points, admin, and proxy admin.

**4. Create a User Vault (Proxy)**

Call `createVault` on the factory contract:

```solidity
function createVault(
    address[] calldata tokens,
    address[] calldata priceFeeds,
    uint256[] calldata allocations,
    uint256 rebalanceThreshold,
    address uniswapV3Factory,
    address uniswapV3SwapRouter,
    address weth,
    uint32 gasLimit,
    uint96 linkAmount
) external returns (address proxy);
```

- The proxy is initialized with the user as the owner.
- The treasury automatically registers a Chainlink Automation upkeep for the vault.
- The user can now deposit, withdraw, and manage their vault.

**5. Interact with Your Vault**

- Use the proxy address returned by the factory to interact with your vault.
- Only the vault owner can call sensitive functions (`deposit`, `withdraw`, `rebalance`, `setBasket`, etc.).
- Chainlink Automation will automatically trigger rebalancing when thresholds are met.

---

## Security Notes

- All sensitive actions are restricted to the vault owner (per-proxy).
- The basket and allocations are per-vault, not global.
- The contract uses Chainlink price feeds and Uniswap V3 for secure, on-chain rebalancing.
- Chainlink Automation handles automatic rebalancing when allocation thresholds are exceeded.
- Upgradeability is managed via UUPS; only the owner can authorize upgrades.

---

## License

MIT
