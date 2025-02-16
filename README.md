# Cross-Chain Rebase Token Protocol

This project is a self-learning project for developing a cross-chain rebase token protocol. Built using [Chainlink's CCIP framework](https://chain.link/cross-chain) and the Foundry smart contract development framework, it explores dynamic token supply adjustment and secure cross-chain communication.

## Table of Contents

- [Overview](#overview)
- [Project Structure](#project-structure)
- [Features](#features)
- [Installation](#installation)
- [Testing](#testing)
- [Deployment](#deployment)
- [License](#license)

## Overview

The Cross-Chain Rebase Token Protocol implements an automated rebase mechanism, allowing dynamic adjustments of token supply based on pre-defined rules. It leverages Chainlink's CCIP for decentralized cross-chain communications and uses Foundry for streamlined development, testing, and deployment.

## Project Structure

The project is organized as follows:

```sh
.
├── src/
│    ├── Constants.sol       # Global constants used across contracts
│    ├── Errors.sol          # Custom error definitions
│    ├── Events.sol          # Event declarations
│    ├── RebaseToken.sol     # Core token logic including rebase mechanism
│    ├── RebaseTokenPool.sol # Liquidity pool management for the token
│    ├── Vault.sol           # Secure vault contract for funds management
│    └── interfaces/         # Solidity interfaces (e.g., IRebaseToken.sol)
├── script/
│    ├── BridgeTokens.s.sol  # Script for bridging tokens across chains
│    ├── ConfigurePool.s.sol # Script to configure the token pool parameters
│    └── Deploy.s.sol        # Deployment script for the contracts
├── test/
│    ├── CrossChain.t.sol    # Test suite for cross-chain operations
│    └── VaultAndRebaseToken.t.sol  # Integrated tests for vault and rebase functionality
├── lib/
│    ├── chainlink/          # Chainlink contracts and utilities for CCIP integration
     ├── chainlink-local/    # Chainlink contracts and utilities for CCIP integration and testing
│    ├── forge-std/          # Foundry standard library for smart contract testing
│    └── openzeppelin-contracts/ # OpenZeppelin contracts for secure contract modules
├── foundry.toml           # Foundry configuration file (compiler settings, networks, etc.)
└── remappings.txt         # Solidity dependency remappings
```

## Features

- **Cross-Chain Communication:** Secure and reliable messaging across blockchains using Chainlink CCIP.
- **Automated Rebase Mechanism:** Dynamic supply adjustments based on economic triggers.
- **Modular Architecture:** Clean separation of contract logic for token, pool, and vault management.
- **Foundry Integration:** Rapid development, testing, and deployment with Foundry.

## Installation

### Prerequisites

- [Foundry](https://github.com/foundry-rs/foundry)
- [Node.js](https://nodejs.org/)
- Git

### Setup Steps

1. Clone the repository:

   ```bash
   git clone https://github.com/sumit03guha/ccip-rebase-token
   ```

2. Navigate to the project directory:

   ```bash
   cd ccip-rebase-token
   ```

3. Install Foundry (if not installed):

   ```bash
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```

4. Compile the contracts:

   ```bash
   forge build
   ```

## Testing

Run the tests with Foundry using:

```bash
forge test
```

## Deployment

Deployment scripts are available in the `script/` directory. To deploy the contracts, run a deployment script such as:

```bash
forge script script/Deploy.s.sol --broadcast --verify
```

Ensure your network settings are configured in `foundry.toml`.

## License

This project is licensed under the MIT License.
