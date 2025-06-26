# Forezy Prediction Market Contracts

A decentralized prediction market platform built on Starknet, inspired by Polymarket. This project implements a complete prediction market system with automated market maker (AMM) pricing, allowing users to trade shares on the outcomes of future events.

## 🌟 Features

### Core Functionality
- **User Balance Management**: Deposit and withdraw ERC20 tokens
- **Market Creation**: Create prediction markets with custom questions and outcomes
- **Share Trading**: Buy and sell shares with dynamic AMM pricing
- **Market Resolution**: Resolve markets and distribute winnings to successful predictors
- **Access Control**: Owner-based market creation and resolution

### Advanced Features
- **Constant Product AMM**: Automated market maker for dynamic pricing
- **Event System**: Comprehensive event logging for all major actions
- **Security**: Built-in protections against common exploits
- **Gas Optimization**: Efficient storage patterns and calculations

## 📋 Requirements Implemented

✅ **Issue 1: Foundational Smart Contract Structure**
- PredictionMarket contract with user balance tracking
- `deposit(amount)` and `withdraw(amount)` functions
- `getBalance(address)` view function
- Deposit and Withdraw events
- ERC20 token integration

✅ **Issue 2: Market Creation**
- Market struct with comprehensive metadata
- `createMarket()` function with access control
- Unique market ID generation
- MarketCreated events
- Initial liquidity and AMM setup

✅ **Issue 3: Share Trading**
- `buyShares()` function with AMM pricing
- Dynamic price calculation based on share distribution
- SharesBought events
- User share tracking
- Price query functions

✅ **Issue 4: Market Resolution & Winnings**
- `resolveMarket()` function with time-based constraints
- `claimWinnings()` function with proportional distribution
- Double-claim prevention
- MarketResolved and WinningsClaimed events

## 🏗️ Architecture

### Contract Structure
```
src/
├── lib.cairo              # Main library entry point
├── interfaces.cairo       # Contract interfaces and data structures
├── events.cairo          # Event definitions
├── utils.cairo           # Utility functions and AMM calculations
└── prediction_market.cairo # Main contract implementation
```

### Key Components

1. **PredictionMarket Contract**: Main contract handling all core functionality
2. **Market Struct**: Stores all market metadata and state
3. **AMM Utilities**: Constant product market maker for share pricing
4. **Access Control**: OpenZeppelin Ownable component for permissions

## 🚀 Getting Started

### Prerequisites
- [Scarb](https://docs.swmansion.com/scarb/download.html) - Cairo package manager
- [Starkli](https://github.com/xJonathanLEI/starkli) - Starknet CLI (for deployment)

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd forezy-contracts
```

2. Install dependencies:
```bash
scarb build
```

3. Run tests:
```bash
scarb test
```

### Deployment

1. Build the contracts:
```bash
./scripts/deploy.sh
```

2. Deploy an ERC20 token (for testing, you can use any existing token):
```bash
# Example with a test USDC token
export TOKEN_ADDRESS=0x...
```

3. Deploy the PredictionMarket contract:
```bash
starkli deploy target/dev/forezy_contracts_PredictionMarket.contract_class.json \
  --constructor-calldata $TOKEN_ADDRESS $OWNER_ADDRESS
```

## 📖 Usage Examples

### Creating a Market

```cairo
// Only the contract owner can create markets
let market_id = prediction_market.create_market(
    "Will Bitcoin reach $100,000 by December 31, 2024?",
    "A prediction market for Bitcoin's price reaching $100k",
    "Yes - Bitcoin will reach $100,000",
    "No - Bitcoin will not reach $100,000",
    1735689600, // December 31, 2024 timestamp
    10000000    // Initial liquidity (10 USDC with 6 decimals)
);
```

### Depositing Funds

```cairo
// First approve the prediction market contract to spend your tokens
erc20_token.approve(prediction_market_address, 1000000); // 1 USDC

// Then deposit
prediction_market.deposit(1000000); // 1 USDC
```

### Buying Shares

```cairo
// Buy "Yes" shares for 100 USDC
let shares_received = prediction_market.buy_shares(
    market_id,
    true,      // true for outcome A ("Yes"), false for outcome B ("No")
    100000000  // 100 USDC
);
```

### Resolving a Market

```cairo
// Only owner can resolve (after resolution time has passed)
prediction_market.resolve_market(market_id, true); // true if outcome A wins
```

### Claiming Winnings

```cairo
// Users with winning shares can claim their winnings
let winnings = prediction_market.claim_winnings(market_id);
```

## 🧮 AMM Pricing Mechanism

The prediction market uses a simplified constant product AMM formula:

- **Price Calculation**: `price = other_shares / (total_shares_a + total_shares_b)`
- **Share Calculation**: `shares = amount / price`
- **Initial State**: Markets start with a 50/50 distribution

### Example Price Dynamics

```
Initial: 500,000 shares A, 500,000 shares B
Price A = Price B = 0.5 (50%)

After buying 100,000 worth of A shares:
- Shares A increases → Price A increases
- Price B decreases (zero-sum)
```

## 🧪 Testing

The project includes comprehensive tests covering:

- Market creation and metadata
- Deposit and withdrawal functionality
- Share trading and price calculations
- Market resolution and winnings distribution
- Access control and error conditions

Run tests with:
```bash
scarb test
```

## 🔒 Security Considerations

### Implemented Protections
- **Access Control**: Only owners can create and resolve markets
- **Time Constraints**: Markets can only be resolved after their resolution time
- **Balance Checks**: All operations verify sufficient balances
- **Double-Claim Prevention**: Users cannot claim winnings multiple times
- **Input Validation**: All inputs are validated for correctness

### Recommended Additional Security
- **Oracle Integration**: Use price oracles for automated resolution
- **Multi-sig**: Use multi-signature wallets for owner functions
- **Timelock**: Implement timelocks for critical operations
- **Audits**: Conduct professional security audits before mainnet deployment

## 🛣️ Roadmap

### Phase 1 (Current)
- ✅ Basic prediction market functionality
- ✅ AMM pricing mechanism
- ✅ Market creation and resolution

### Phase 2 (Future)
- 🔄 Advanced AMM mechanisms (LMSR)
- 🔄 Multi-outcome markets (more than binary)
- 🔄 Automated resolution via oracles
- 🔄 Liquidity provider rewards

### Phase 3 (Future)
- 🔄 Cross-chain prediction markets
- 🔄 Social features and reputation systems
- 🔄 Advanced trading features (limit orders, etc.)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

## 📞 Support

For questions and support:
- Create an issue in this repository
- Join our Discord community
- Check the documentation

## 🙏 Acknowledgments

- [OpenZeppelin Cairo Contracts](https://github.com/OpenZeppelin/cairo-contracts) for security components
- [Starknet](https://starknet.io/) for the amazing Layer 2 platform
- [Polymarket](https://polymarket.com/) for inspiration on prediction market design
