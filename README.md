# PigLo Game implementation for Flow EVM

This repository contains a smart contract that demonstrates Flow EVM's native secure randomness with a simple game inspired by Hi-Lo and Pig.

Contracts adapted from: https://github.com/onflow/random-coin-toss

## Project Structure

```bash
.
├── src
|   ├── mocks
|   |   ├── MockCadenceRandomConsumer.sol # Used to create tests
|   ├── CadenceArchUtils.sol # Util library for calling randomness
|   ├── CadenceArchRandomConsumer.sol # Helper contract for randomness
|   ├── PigLo.sol # The main contract with the game
│   ├── Xorshift128plus.sol.sol    # Util library for bit shifting
├── test
|   ├── CadenceRandomConsumer.t.sol #Tests for the random consumer
│   ├── PigLo.t.sol        # Tests for PigLo contract
├── foundry.toml              # Foundry configuration file
├── script
└── README.md                 # This file
```

## Prerequisites

Before you begin, ensure you have met the following requirements:

- [Foundry](https://github.com/foundry-rs/foundry) installed for compiling, testing, and deploying smart contracts.
- A compatible Solidity compiler version (check `foundry.toml` for the exact version).

## Installation

1. **Clone the repository**:

   ```bash
   git clone https://github.com/TimMackenzie/pig-lo
   cd pig-lo
   ```

2. **Install dependencies** (if any):

   ```bash
   forge install
   ```

3. **Compile the contracts**:

   ```bash
   forge build
   ```

## Running Tests

The repository includes test files written for Foundry.

To run all tests:

```bash
forge test
```


## Contracts

### `PigLo.sol`
The game contract that supports playing rounds of HiLo where score is reset upon any loss.  This contract only works on the Flow EVM because it requires the secure randomness capabilities.


## Testing Overview

**`PigLo.t.sol`**:

This demonstrates a few primary paths, including a fuzz test.  There may be missing edge cases that should be added.

## Deployment

To deploy the contracts to a network, you can use the deployment script provided under `script/Deploy.s.sol`. Make sure your deployment script is configured properly with network and contract addresses if necessary.

Run the deployment:

```bash
forge script script/Deploy.s.sol --rpc-url <your_rpc_url>
```

## Contribution

If you’d like to contribute to this project, please fork the repository and use a feature branch. Pull requests are welcome.

## License

This project is licensed under the MIT License - see the `LICENSE` file for details.

---

This README should give users and developers enough context to get started with your project, including installation, testing, and contributing.
