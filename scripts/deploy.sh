#!/bin/bash

# Deployment script for Forezy Prediction Market Contracts

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Deploying Forezy Prediction Market Contracts${NC}"

# Check if Scarb is installed
if ! command -v scarb &> /dev/null; then
    echo -e "${RED}❌ Scarb could not be found. Please install Scarb first.${NC}"
    exit 1
fi

# Check if starkli is installed (for deployment)
if ! command -v starkli &> /dev/null; then
    echo -e "${YELLOW}⚠️ Starkli not found. You may need to install it for deployment.${NC}"
fi

echo -e "${YELLOW}📦 Building contracts...${NC}"
scarb build

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Build successful!${NC}"
else
    echo -e "${RED}❌ Build failed!${NC}"
    exit 1
fi

echo -e "${YELLOW}🧪 Running tests...${NC}"
scarb test

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed!${NC}"
else
    echo -e "${RED}❌ Tests failed!${NC}"
    exit 1
fi

echo -e "${GREEN}🎉 Contracts are ready for deployment!${NC}"
echo -e "${YELLOW}📋 Next steps:${NC}"
echo "1. Set up your starknet account with starkli"
echo "2. Deploy an ERC20 token for the prediction market"
echo "3. Deploy the PredictionMarket contract with the token address"
echo ""
echo -e "${YELLOW}Example deployment command:${NC}"
echo "starkli deploy target/dev/forezy_contracts_PredictionMarket.contract_class.json \\
  --constructor-calldata <token_address> <owner_address>" 