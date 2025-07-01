#!/usr/bin/env node

import { 
    getProvider, 
    getAccount, 
    loadSierraContract,
    waitForTransaction,
    displayGasEstimate,
    saveDeploymentInfo,
    loadDeploymentInfo,
    getPredictionMarketConstructorCalldata
} from './utils.js';

/**
 * Declare and deploy the PredictionMarket contract in one transaction
 */
async function declareAndDeploy() {
    console.log('🚀 Starting full PredictionMarket contract declaration and deployment...\n');

    try {
        // Initialize provider and account
        const provider = getProvider();
        const account = getAccount(provider);

        // Load contract artifacts
        const { sierra, casm } = loadSierraContract('PredictionMarket');

        // Get constructor calldata
        const constructorCalldata = getPredictionMarketConstructorCalldata();

        console.log('📋 Preparing declare and deploy transaction...');

        // Try declareAndDeploy first (most efficient)
        try {
            // Estimate fee for declareAndDeploy
            try {
                const declareAndDeployEstimate = await account.estimateDeclareFee({
                    contract: sierra,
                    casm: casm
                });
                console.log('💰 Declaration fee estimate:');
                displayGasEstimate(declareAndDeployEstimate);
            } catch (error) {
                console.log('⚠️  Could not estimate declaration fee:', error.message);
            }

            console.log('📝 Declaring and deploying contract...');
            const deployResponse = await account.declareAndDeploy({
                contract: sierra,
                casm: casm,
                constructorCalldata: constructorCalldata
            });

            console.log('✅ DeclareAndDeploy successful!');
            console.log(`🏷️  Class Hash: ${deployResponse.declare.class_hash}`);
            console.log(`📄 Declare Transaction: ${deployResponse.declare.transaction_hash}`);
            console.log(`🏠 Contract Address: ${deployResponse.deploy.contract_address}`);
            console.log(`📄 Deploy Transaction: ${deployResponse.deploy.transaction_hash}`);

            // Wait for transactions
            console.log('⏳ Waiting for transactions to confirm...');
            await Promise.all([
                waitForTransaction(provider, deployResponse.declare.transaction_hash),
                waitForTransaction(provider, deployResponse.deploy.transaction_hash)
            ]);

            // Save deployment info
            const deploymentInfo = {
                contractName: 'PredictionMarket',
                classHash: deployResponse.declare.class_hash,
                contractAddress: deployResponse.deploy.contract_address,
                declareTransactionHash: deployResponse.declare.transaction_hash,
                deployTransactionHash: deployResponse.deploy.transaction_hash,
                constructorCalldata: constructorCalldata,
                timestamp: new Date().toISOString(),
                network: process.env.STARKNET_NETWORK || 'sepolia'
            };

            saveDeploymentInfo('PredictionMarket_Full_Deployment', deploymentInfo);

            console.log('\n🎉 Full deployment completed successfully!');
            console.log(`🏠 Contract deployed at: ${deployResponse.deploy.contract_address}`);
            console.log(`🏷️  Class Hash: ${deployResponse.declare.class_hash}`);
            console.log(`📁 Deployment info saved to deployments/`);

            return {
                classHash: deployResponse.declare.class_hash,
                contractAddress: deployResponse.deploy.contract_address
            };

        } catch (error) {
            console.log('⚠️  declareAndDeploy failed, trying sequential approach:', error.message);
            
            // Fallback to sequential declare then deploy
            return await sequentialDeclareAndDeploy(account, provider, sierra, casm, constructorCalldata);
        }

    } catch (error) {
        console.error('❌ Full deployment failed:', error.message);
        process.exit(1);
    }
}

/**
 * Sequential declare and deploy approach
 */
async function sequentialDeclareAndDeploy(account, provider, sierra, casm, constructorCalldata) {
    console.log('📋 Using sequential declare and deploy...');
    
    // Declare first
    console.log('📝 Declaring contract class...');
    const declareResponse = await account.declare({
        contract: sierra,
        casm: casm
    });

    console.log(`🏷️  Class Hash: ${declareResponse.class_hash}`);
    console.log(`📄 Declare Transaction: ${declareResponse.transaction_hash}`);

    // Wait for declaration
    await waitForTransaction(provider, declareResponse.transaction_hash);

    // Deploy instance
    console.log('🚀 Deploying contract instance...');
    const deployResponse = await account.deployContract({
        classHash: declareResponse.class_hash,
        constructorCalldata: constructorCalldata
    });

    console.log(`🏠 Contract Address: ${deployResponse.contract_address}`);
    console.log(`📄 Deploy Transaction: ${deployResponse.transaction_hash}`);

    // Wait for deployment
    await waitForTransaction(provider, deployResponse.transaction_hash);

    // Save deployment info
    const deploymentInfo = {
        contractName: 'PredictionMarket',
        classHash: declareResponse.class_hash,
        contractAddress: deployResponse.contract_address,
        declareTransactionHash: declareResponse.transaction_hash,
        deployTransactionHash: deployResponse.transaction_hash,
        constructorCalldata: constructorCalldata,
        timestamp: new Date().toISOString(),
        network: process.env.STARKNET_NETWORK || 'sepolia'
    };

    saveDeploymentInfo('PredictionMarket_Sequential_Deployment', deploymentInfo);

    console.log('\n🎉 Sequential deployment completed successfully!');
    console.log(`🏠 Contract deployed at: ${deployResponse.contract_address}`);
    console.log(`🏷️  Class Hash: ${declareResponse.class_hash}`);
    console.log(`📁 Deployment info saved to deployments/`);

    return {
        classHash: declareResponse.class_hash,
        contractAddress: deployResponse.contract_address
    };
}

// CLI argument parsing
function parseArgs() {
    const args = process.argv.slice(2);
    const options = {};
    
    for (let i = 0; i < args.length; i++) {
        switch (args[i]) {
            case '--help':
            case '-h':
                console.log(`
🚀 PredictionMarket Full Deployment Script

Usage: npm run deploy-full [options]

Options:
  --help, -h     Show this help message
  
Environment Variables (set in .env):
  STARKNET_NETWORK      Target network (sepolia, mainnet, devnet)
  STARKNET_RPC_URL      Custom RPC endpoint
  DEPLOYER_ADDRESS      Your account address
  DEPLOYER_PRIVATE_KEY  Your account private key
  OWNER_ADDRESS         Contract owner address  
  TOKEN_ADDRESS         ERC20 token address

Examples:
  npm run deploy-full
  node scripts/deploy-full.js
                `);
                process.exit(0);
                break;
        }
    }
    
    return options;
}

// Execute if run directly
if (import.meta.url === `file://${process.argv[1]}`) {
    parseArgs();
    declareAndDeploy().catch(console.error);
} 