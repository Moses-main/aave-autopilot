# 🛠️ Development Guide

## Prerequisites

- [Foundry](https://getfoundry.sh/) (v0.2.0 or later)
- [Node.js](https://nodejs.org/) (v18+)
- [Git](https://git-scm.com/)
- [jq](https://stedolan.github.io/jq/) (for scripts)

## Local Development Setup

1. **Clone the repository**:
   ```bash
   git clone https://github.com/Moses-main/aave-autopilot.git
   cd aave-autopilot
   ```

2. **Install dependencies**:
   ```bash
   # Install Foundry if not already installed
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   
   # Install project dependencies
   forge install
   ```

3. **Set up environment variables**:
   ```bash
   cp .env.example .env
   # Update .env with your private keys and API keys
   ```

## Testing

### Run Tests

```bash
# Run unit tests
forge test

# Run tests with gas report
forge test --gas-report

# Run forked tests against Sepolia
forge test --fork-url $RPC_URL -vvv

# Run with specific block number for consistency
forge test --fork-url $RPC_URL --fork-block-number 20000000 -vvv

# Run with coverage report
forge coverage --fork-url $SEPOLIA_RPC_URL
```

### Testing on Sepolia

To test against the Sepolia testnet:

1. Create a `.env` file with your configuration:
   ```bash
   # .env
   RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY
   PRIVATE_KEY=your_private_key
   ```

2. Run the tests:
   ```bash
   forge test --fork-url $RPC_URL -vvv
   ```

## Code Style

- Follow the Solidity Style Guide
- Use NatSpec for all public interfaces
- Keep functions small and focused
- Use custom errors instead of require with strings
- Add comprehensive test coverage for all new features

## Pull Requests

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Update documentation
6. Submit a pull request

## Versioning

We use [SemVer](https://semver.org/) for versioning. For the versions available, see the [tags on this repository](https://github.com/Moses-main/aave-autopilot/tags).

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
