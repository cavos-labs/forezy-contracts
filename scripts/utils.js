import { Provider, Account, Contract, json, RpcProvider, constants } from 'starknet';
import fs from 'fs';
import path from 'path';
import { config } from 'dotenv';

// Load environment variables
config();

/**
 * Get the provider based on network configuration
 */
export function getProvider() {
    const network = process.env.STARKNET_NETWORK || 'sepolia';
    const rpcUrl = process.env.STARKNET_RPC_URL;

    if (rpcUrl) {
        console.log(`🌐 Using custom RPC: ${rpcUrl}`);
        return new RpcProvider({ nodeUrl: rpcUrl });
    }

    switch (network.toLowerCase()) {
        case 'mainnet':
            console.log('🌐 Using Starknet Mainnet');
            return new RpcProvider({ nodeUrl: constants.NetworkName.SN_MAIN });
        case 'sepolia':
            console.log('🌐 Using Starknet Sepolia Testnet');
            return new RpcProvider({ nodeUrl: constants.NetworkName.SN_SEPOLIA });
        case 'devnet':
        default:
            console.log('🌐 Using Local Devnet');
            return new RpcProvider({ nodeUrl: 'http://127.0.0.1:5050/rpc' });
    }
}

/**
 * Get the account for deployment
 */
export function getAccount(provider) {
    const accountAddress = process.env.DEPLOYER_ADDRESS;
    const privateKey = process.env.DEPLOYER_PRIVATE_KEY;

    if (!accountAddress || !privateKey) {
        throw new Error(
            '❌ Missing account configuration. Please set DEPLOYER_ADDRESS and DEPLOYER_PRIVATE_KEY in your .env file'
        );
    }

    console.log(`👤 Using account: ${accountAddress}`);
    return new Account(provider, accountAddress, privateKey);
}

/**
 * Load compiled contract artifacts (Sierra and CASM)
 */
export function loadSierraContract(contractName = 'PredictionMarket') {
    const sierraPath = path.join(process.cwd(), 'target', 'dev', `forezy_contracts_${contractName}.contract_class.json`);
    const casmPath = path.join(process.cwd(), 'target', 'dev', `forezy_contracts_${contractName}.compiled_contract_class.json`);
    
    if (!fs.existsSync(sierraPath)) {
        throw new Error(`Sierra contract not found at ${sierraPath}. Run 'scarb build' first.`);
    }
    
    if (!fs.existsSync(casmPath)) {
        throw new Error(`CASM contract not found at ${casmPath}. Ensure 'casm = true' in Scarb.toml and run 'scarb build'.`);
    }

    const sierra = json.parse(fs.readFileSync(sierraPath, 'utf8'));
    const casm = json.parse(fs.readFileSync(casmPath, 'utf8'));
    
    console.log(`📄 Loaded Sierra and CASM artifacts: ${contractName}`);
    console.log(`📊 Sierra program size: ${sierra.sierra_program ? sierra.sierra_program.length : 'N/A'} instructions`);
    
    return { sierra, casm };
}

/**
 * Wait for transaction confirmation
 */
export async function waitForTransaction(provider, txHash) {
    console.log(`⏳ Waiting for transaction: ${txHash}`);
    try {
        const receipt = await provider.waitForTransaction(txHash);
        console.log(`✅ Transaction confirmed in block: ${receipt.block_number || 'pending'}`);
        return receipt;
    } catch (error) {
        console.error(`❌ Transaction failed: ${error.message}`);
        throw error;
    }
}

/**
 * Display gas estimate
 */
export function displayGasEstimate(estimate) {
    console.log(`💰 Estimated fee: ${estimate.overall_fee} WEI (${Number(estimate.overall_fee) / 1e18} ETH)`);
    console.log(`⛽ Gas estimate: ${estimate.gas_consumed || 'N/A'} units`);
}

/**
 * Save deployment information to JSON file
 */
export function saveDeploymentInfo(contractName, info) {
    const deploymentsDir = path.join(process.cwd(), 'deployments');
    if (!fs.existsSync(deploymentsDir)) {
        fs.mkdirSync(deploymentsDir, { recursive: true });
    }

    const filePath = path.join(deploymentsDir, `${contractName}.json`);
    const deploymentData = {
        ...info,
        timestamp: new Date().toISOString(),
        network: process.env.STARKNET_NETWORK || 'sepolia'
    };

    fs.writeFileSync(filePath, JSON.stringify(deploymentData, null, 2));
    console.log(`💾 Deployment info saved to: ${filePath}`);
}

/**
 * Load deployment information from JSON file
 */
export function loadDeploymentInfo(contractName) {
    try {
        const filePath = path.join(process.cwd(), 'deployments', `${contractName}.json`);
        if (fs.existsSync(filePath)) {
            return json.parse(fs.readFileSync(filePath, 'utf8'));
        }
        return null;
    } catch (error) {
        console.log(`⚠️  Could not load deployment info for ${contractName}: ${error.message}`);
        return null;
    }
}

/**
 * Get constructor calldata for PredictionMarket
 */
export function getPredictionMarketConstructorCalldata() {
    const ownerAddress = process.env.OWNER_ADDRESS;
    const tokenAddress = process.env.TOKEN_ADDRESS;

    if (!ownerAddress || !tokenAddress) {
        throw new Error(
            '❌ Missing constructor parameters. Please set OWNER_ADDRESS and TOKEN_ADDRESS in your .env file'
        );
    }

    console.log(`👑 Contract owner: ${ownerAddress}`);
    console.log(`🪙 Token contract: ${tokenAddress}`);

    return [ownerAddress, tokenAddress];
} 