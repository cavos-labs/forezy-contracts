# 🚀 Deployment Guide for Forezy Prediction Market

This guide explains how to declare and deploy the Forezy Prediction Market contracts on Starknet using the provided Starknet.js scripts.

## 📋 Prerequisites

### 1. Development Environment
- **Node.js** (v18 or higher)
- **npm** or **yarn**
- **Scarb** (Cairo package manager)
- **Starknet account** with sufficient ETH for gas fees

### 2. Build the Contracts
Before deployment, ensure your contracts are built:

```bash
# Build the Cairo contracts
scarb build

# Verify build artifacts exist
ls target/dev/forezy_contracts_PredictionMarket.*
```

### 3. Install Node Dependencies
```bash
# Install deployment dependencies
npm install

# Or with yarn
yarn install
```

## 🔧 Environment Setup

### 1. Copy Environment Template
```bash
cp env.example .env
```

### 2. Configure Environment Variables

Edit `.env` with your specific values:

```bash
# Starknet Configuration
STARKNET_NETWORK=sepolia                    # sepolia, mainnet, or devnet
STARKNET_RPC_URL=https://starknet-sepolia.public.blastapi.io

# Account Configuration
DEPLOYER_ADDRESS=0x1234...                  # Your Starknet account address
DEPLOYER_PRIVATE_KEY=0x5678...              # Your account private key

# Contract Configuration
OWNER_ADDRESS=0x9abc...                     # Contract owner (optional, defaults to DEPLOYER_ADDRESS)
TOKEN_ADDRESS=0xdef0...                     # ERC20 token address for the prediction market

# Optional: Gas limit
MAX_FEE=1000000000000000                   # Maximum fee in wei
```

### 3. Required Information

#### 🏦 **Starknet Account**
- **Address**: Your deployed Starknet account contract address
- **Private Key**: The private key that controls this account
- **Balance**: Sufficient ETH for gas fees (typically 0.01-0.1 ETH on testnet)

#### 🪙 **ERC20 Token Address**
You need the address of an ERC20 token contract. Options:

**Sepolia Testnet Tokens:**
```bash
# Example testnet tokens (verify current addresses)
USDC_SEPOLIA=0x...
ETH_SEPOLIA=0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7
```

**Mainnet Tokens:**
```bash
# Example mainnet tokens
USDC_MAINNET=0x053c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8
```

## 🚀 Deployment Methods

### Method 1: Full Deployment (Recommended)

Deploy everything in one command:

```bash
# Declare and deploy in one go
npm run deploy-full

# Or directly
node scripts/deploy-full.js
```

This script will:
1. ✅ Check if contract is already declared
2. 📝 Declare the contract class (if needed)
3. 🏗️ Deploy a contract instance
4. 💾 Save deployment information
5. 📋 Display next steps

### Method 2: Step-by-Step Deployment

For more control, use separate commands:

```bash
# Step 1: Declare the contract class
npm run declare
# or: node scripts/declare.js

# Step 2: Deploy an instance
npm run deploy
# or: node scripts/deploy.js

# Alternative: Deploy with specific class hash
npm run deploy 0x1234...class_hash...
```

### Method 3: Deploy with Existing Class Hash

If you already have a declared class hash:

```bash
node scripts/deploy.js 0x1234567890abcdef...
```

## 📊 Understanding the Output

### Successful Declaration
```
🚀 Starting PredictionMarket contract declaration...

🌐 Using Starknet Sepolia Testnet
👤 Using deployer account: 0x1234...
📄 Loaded Sierra and CASM artifacts: PredictionMarket
📋 Preparing declaration transaction...
⛽ Estimated gas fee: 1234567890123456 wei (0.001235 ETH)
📝 Declaring contract class...
📋 Declaration transaction hash: 0xabc123...
🏷️  Class hash: 0xdef456...
⏳ Declaration submitted: 0xabc123...
🔗 View on Starkscan: https://sepolia.starkscan.co/tx/0xabc123...
✅ Declaration confirmed!
💾 Deployment info saved to: deployments/PredictionMarket_Declaration_sepolia.json

🎉 Contract class declared successfully!
📋 Class Hash: 0xdef456...
```

### Successful Deployment
```
🚀 Starting PredictionMarket contract deployment...

📋 Using previously declared class hash: 0xdef456...
🏗️  Constructor parameters:
   Token Address: 0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7
   Owner Address: 0x1234...
📋 Preparing deployment transaction...
🏷️  Class Hash: 0xdef456...
⛽ Estimated gas fee: 2345678901234567 wei (0.002346 ETH)
🏗️  Deploying contract...
📋 Deployment transaction hash: 0x789xyz...
🏠 Contract address: 0x999aaa...
⏳ Deployment submitted: 0x789xyz...
✅ Deployment confirmed!
💾 Deployment info saved to: deployments/PredictionMarket_sepolia.json

🎉 Contract deployed successfully!
🏠 Contract Address: 0x999aaa...
🏷️  Class Hash: 0xdef456...
🔗 View on Starkscan: https://sepolia.starkscan.co/contract/0x999aaa...
```

## 📁 Deployment Artifacts

The scripts automatically save deployment information:

```
deployments/
├── PredictionMarket_Declaration_sepolia.json
└── PredictionMarket_sepolia.json
```

Example deployment file:
```json
{
  "contractName": "PredictionMarket",
  "classHash": "0xdef456...",
  "contractAddress": "0x999aaa...",
  "txHash": "0x789xyz...",
  "network": "sepolia",
  "timestamp": "2024-01-15T10:30:00.000Z",
  "deployer": "0x1234..."
}
```

## 🛠️ Post-Deployment Steps

### 1. Verify Deployment
Visit Starkscan to verify your contract:
- **Sepolia**: `https://sepolia.starkscan.co/contract/{CONTRACT_ADDRESS}`
- **Mainnet**: `https://starkscan.co/contract/{CONTRACT_ADDRESS}`

### 2. Fund the Owner Account
The contract owner needs tokens to create markets:

```javascript
// Example: Transfer tokens to owner
await erc20Token.transfer(ownerAddress, amount);
```

### 3. Approve Token Spending
The prediction market contract needs approval to handle tokens:

```javascript
// Approve the prediction market to spend tokens
await erc20Token.approve(predictionMarketAddress, maxAmount);
```

### 4. Create Your First Market
```javascript
import { Contract, Provider, Account } from 'starknet';

const provider = new Provider({ sequencer: { network: 'sepolia' } });
const account = new Account(provider, ownerAddress, ownerPrivateKey);

const contract = new Contract(abi, contractAddress, account);

// Create a market
await contract.create_market(
    "Will Bitcoin reach $100,000 by December 31, 2024?",
    "A prediction market for Bitcoin's price reaching $100k by end of 2024",
    "Yes - Bitcoin will reach $100,000",
    "No - Bitcoin will not reach $100,000",
    1735689600, // December 31, 2024 timestamp
    1000000     // 1 USDC initial liquidity (6 decimals)
);
```

## 🆘 Troubleshooting

### Common Errors and Solutions

#### ❌ "Contract artifact not found"
```bash
Error: Contract artifact not found at target/dev/forezy_contracts_PredictionMarket.contract_class.json
```
**Solution**: Build the contracts first
```bash
scarb build
```

#### ℹ️ "CASM not found, using Sierra-only declaration"
This is normal and not an error. Modern Starknet deployments can use Sierra files without CASM:
```
📄 Loaded Sierra artifact: PredictionMarket (CASM not found, using Sierra-only declaration)
```
Your deployment will proceed normally.

#### ❌ "DEPLOYER_ADDRESS and DEPLOYER_PRIVATE_KEY must be set"
**Solution**: Set environment variables
```bash
# Add to .env file
DEPLOYER_ADDRESS=0x...
DEPLOYER_PRIVATE_KEY=0x...
```

#### ❌ "InsufficientAccountBalance"
**Solution**: Fund your account with ETH
- Get testnet ETH from [Starknet Faucet](https://faucet.goerli.starknet.io/)
- For mainnet, bridge ETH to Starknet

#### ❌ "TOKEN_ADDRESS must be set"
**Solution**: Set a valid ERC20 token address
```bash
# Add to .env file
TOKEN_ADDRESS=0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7
```

#### ❌ "Class with hash X already declared"
This is actually not an error! The contract class exists and you can deploy instances:
```bash
# Use the existing class hash for deployment
npm run deploy
```

### Network Issues

#### RPC Endpoint Problems
If you experience RPC issues, try alternative endpoints:

```bash
# Infura
STARKNET_RPC_URL=https://starknet-sepolia.infura.io/v3/YOUR_API_KEY

# Alchemy  
STARKNET_RPC_URL=https://starknet-sepolia.g.alchemy.com/v2/YOUR_API_KEY

# Public endpoints
STARKNET_RPC_URL=https://starknet-sepolia.public.blastapi.io
```

### Getting Help

#### Command Line Help
```bash
# Get help for any script
npm run deploy-full -- --help
npm run declare -- --help
npm run deploy -- --help
```

#### Useful Resources
- [Starknet Documentation](https://docs.starknet.io/)
- [Starknet.js Documentation](https://www.starknetjs.com/)
- [Starkscan Explorer](https://starkscan.co/)
- [Starknet Faucet](https://faucet.goerli.starknet.io/)

## 🔒 Security Notes

### 🚨 Private Key Security
- **Never** commit private keys to version control
- Use environment variables or secure key management
- Consider using hardware wallets for mainnet deployments

### 🛡️ Mainnet Deployment Checklist
Before deploying to mainnet:

- [ ] ✅ Thoroughly test on Sepolia testnet
- [ ] ✅ Audit the contract code
- [ ] ✅ Verify constructor parameters
- [ ] ✅ Double-check token addresses
- [ ] ✅ Use a hardware wallet or secure key storage
- [ ] ✅ Start with small amounts for testing
- [ ] ✅ Have a plan for contract upgrades (if needed)

## 📈 Next Steps

After successful deployment:

1. **Test Basic Functions**: Deposit, withdraw, check balances
2. **Create Test Markets**: Start with simple binary prediction markets  
3. **Invite Beta Users**: Gradually expand the user base
4. **Monitor Performance**: Track gas usage and transaction success
5. **Iterate**: Gather feedback and plan improvements

---

🎉 **Congratulations!** You've successfully deployed your Polymarket-style prediction market on Starknet!

For questions or support, please check the project documentation or create an issue in the repository. 