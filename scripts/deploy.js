#!/usr/bin/env node

import { 
    getProvider, 
    getAccount, 
    waitForTransaction,
    displayGasEstimate,
    saveDeploymentInfo,
    loadDeploymentInfo,
    getPredictionMarketConstructorCalldata
} from './utils.js';

/**
 * Deploy a PredictionMarket contract instance
 */
async function deployContract(classHash = null) {
    console.log('🚀 Starting PredictionMarket contract deployment...\n');

    try {
        // Initialize provider and account
        const provider = getProvider();
        const account = getAccount(provider);

        // Get class hash
        let contractClassHash = classHash;
        if (!contractClassHash) {
            // Try to load from previous declaration
            const declarationInfo = loadDeploymentInfo('PredictionMarket_Declaration');
            if (declarationInfo && declarationInfo.classHash) {
                contractClassHash = declarationInfo.classHash;
                console.log(`📋 Using class hash from previous declaration: ${contractClassHash}`);
            } else {
                throw new Error('No class hash provided and no previous declaration found. Please declare the contract first or provide a class hash.');
            }
        }

        // Get constructor calldata
        const constructorCalldata = getPredictionMarketConstructorCalldata();

        console.log('📋 Preparing deployment transaction...');

        // Estimate deployment fee
        try {
            const deployEstimate = await account.estimateDeployFee({
                classHash: contractClassHash,
                constructorCalldata: constructorCalldata
            });
            console.log('💰 Deployment fee estimate:');
            displayGasEstimate(deployEstimate);
        } catch (error) {
            console.log('⚠️  Could not estimate deployment fee:', error.message);
        }

        // Deploy the contract
        console.log('🚀 Deploying contract instance...');
        const deployResponse = await account.deployContract({
            classHash: contractClassHash,
            constructorCalldata: constructorCalldata
        });

        console.log(`🏠 Contract Address: ${deployResponse.contract_address}`);
        console.log(`📄 Transaction Hash: ${deployResponse.transaction_hash}`);

        // Wait for transaction confirmation
        console.log('⏳ Waiting for transaction confirmation...');
        await waitForTransaction(provider, deployResponse.transaction_hash);

        // Save deployment info
        const deploymentInfo = {
            contractName: 'PredictionMarket',
            classHash: contractClassHash,
            contractAddress: deployResponse.contract_address,
            transactionHash: deployResponse.transaction_hash,
            constructorCalldata: constructorCalldata,
            timestamp: new Date().toISOString(),
            network: process.env.STARKNET_NETWORK || 'sepolia'
        };

        saveDeploymentInfo('PredictionMarket_Deployment', deploymentInfo);

        console.log('\n🎉 Contract deployment completed successfully!');
        console.log(`🏠 Contract deployed at: ${deployResponse.contract_address}`);
        console.log(`🏷️  Class Hash: ${contractClassHash}`);
        console.log(`📁 Deployment info saved to deployments/`);

        return {
            classHash: contractClassHash,
            contractAddress: deployResponse.contract_address
        };

    } catch (error) {
        console.error('❌ Deployment failed:', error.message);
        
        if (error.message.includes('Class with hash') && error.message.includes('is not declared')) {
            console.log('💡 The contract class needs to be declared first. Run:');
            console.log('  npm run declare');
            console.log('  -- or --');
            console.log('  npm run deploy-full');
        }
        
        process.exit(1);
    }
}

// CLI argument parsing
function parseArgs() {
    const args = process.argv.slice(2);
    let classHash = null;
    
    for (let i = 0; i < args.length; i++) {
        switch (args[i]) {
            case '--class-hash':
            case '-c':
                if (i + 1 < args.length) {
                    classHash = args[i + 1];
                    i++; // Skip next argument
                } else {
                    console.error('❌ --class-hash requires a value');
                    process.exit(1);
                }
                break;
            case '--help':
            case '-h':
                console.log(`
🚀 PredictionMarket Deployment Script

Usage: npm run deploy [options]

Options:
  --class-hash, -c <hash>    Class hash of previously declared contract
  --help, -h                 Show this help message
  
Environment Variables (set in .env):
  STARKNET_NETWORK      Target network (sepolia, mainnet, devnet)
  STARKNET_RPC_URL      Custom RPC endpoint
  DEPLOYER_ADDRESS      Your account address
  DEPLOYER_PRIVATE_KEY  Your account private key
  OWNER_ADDRESS         Contract owner address  
  TOKEN_ADDRESS         ERC20 token address

Examples:
  npm run deploy
  npm run deploy -- --class-hash 0x123...
  node scripts/deploy.js --class-hash 0x123...
                `);
                process.exit(0);
                break;
        }
    }
    
    return { classHash };
}

// Execute if run directly
if (import.meta.url === `file://${process.argv[1]}`) {
    const { classHash } = parseArgs();
    deployContract(classHash).catch(console.error);
} 