#!/usr/bin/env node

import { 
    getProvider, 
    getAccount, 
    loadSierraContract, 
    waitForTransaction,
    displayGasEstimate,
    saveDeploymentInfo 
} from './utils.js';

/**
 * Declare the PredictionMarket contract class
 */
async function declareContract() {
    console.log('🚀 Starting PredictionMarket contract declaration...\n');

    try {
        // Initialize provider and account
        const provider = getProvider();
        const account = getAccount(provider);

        // Load contract artifacts
        const { sierra, casm } = loadSierraContract('PredictionMarket');

        console.log('📋 Preparing declaration transaction...');

        // Estimate fee for declaration
        try {
            const declareEstimate = await account.estimateDeclareFee({
                contract: sierra,
                casm: casm
            });
            displayGasEstimate(declareEstimate);
        } catch (error) {
            console.log('⚠️  Could not estimate gas fee:', error.message);
        }

        // Declare the contract
        console.log('📝 Declaring contract class...');
        const declareResponse = await account.declare({
            contract: sierra,
            casm: casm
        });

        console.log(`🏷️  Class Hash: ${declareResponse.class_hash}`);
        console.log(`📄 Transaction Hash: ${declareResponse.transaction_hash}`);

        // Wait for transaction confirmation
        console.log('⏳ Waiting for transaction confirmation...');
        await waitForTransaction(provider, declareResponse.transaction_hash);

        // Save deployment info
        const deploymentInfo = {
            contractName: 'PredictionMarket',
            classHash: declareResponse.class_hash,
            transactionHash: declareResponse.transaction_hash,
            timestamp: new Date().toISOString(),
            network: process.env.STARKNET_NETWORK || 'sepolia'
        };

        saveDeploymentInfo('PredictionMarket_Declaration', deploymentInfo);

        console.log('✅ Contract declaration completed successfully!');
        console.log(`🏷️  Class Hash: ${declareResponse.class_hash}`);
        console.log(`📁 Deployment info saved to deployments/`);

    } catch (error) {
        console.error('❌ Declaration failed:', error.message);
        if (error.message.includes('Class with hash')) {
            console.log('💡 This contract class may already be declared. You can proceed with deployment.');
        }
        process.exit(1);
    }
}

// Execute if run directly
if (import.meta.url === `file://${process.argv[1]}`) {
    declareContract().catch(console.error);
} 