#!/bin/bash

# Portfolio Rebalancer Deployment with Etherscan Verification
# 
# Prerequisites:
# 1. Set up .env file with API keys:
#    ETHERSCAN_API_KEY=your_key_here
#    PRIVATE_KEY=your_private_key_here
#    SEPOLIA_RPC_URL=your_rpc_url_here
#
# 2. Fund your deployer account with testnet ETH
#
# Usage: ./script/examples/DeployWithVerification.sh

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Portfolio Rebalancer Deployment with Verification ===${NC}"
echo ""

# Check if .env file exists
if [ ! -f .env ]; then
    echo -e "${RED}ERROR: .env file not found${NC}"
    echo "Create .env file with:"
    echo "ETHERSCAN_API_KEY=your_key_here"
    echo "PRIVATE_KEY=your_private_key_here"
    echo "SEPOLIA_RPC_URL=your_rpc_url_here"
    exit 1
fi

# Source environment variables
source .env

# Check required environment variables
if [ -z "$ETHERSCAN_API_KEY" ]; then
    echo -e "${RED}ERROR: ETHERSCAN_API_KEY not set in .env${NC}"
    exit 1
fi

if [ -z "$PRIVATE_KEY" ]; then
    echo -e "${RED}ERROR: PRIVATE_KEY not set in .env${NC}"
    exit 1
fi

if [ -z "$SEPOLIA_RPC_URL" ]; then
    echo -e "${YELLOW}WARNING: SEPOLIA_RPC_URL not set, using default${NC}"
    SEPOLIA_RPC_URL="https://sepolia.infura.io/v3/YOUR_PROJECT_ID"
fi

echo -e "${GREEN}✓ Environment variables loaded${NC}"
echo ""

# Get user confirmation
echo -e "${YELLOW}This will deploy to Sepolia testnet and verify on Etherscan${NC}"
echo "Network: Sepolia"
echo "RPC URL: $SEPOLIA_RPC_URL"
echo "API Key: ${ETHERSCAN_API_KEY:0:8}..."
echo ""
read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled"
    exit 0
fi

echo ""
echo -e "${GREEN}Starting deployment...${NC}"
echo ""

# Deploy with verification
echo -e "${YELLOW}Deploying complete system with Etherscan verification...${NC}"
forge script script/PortfolioRebalancer.s.sol \
    --rpc-url "$SEPOLIA_RPC_URL" \
    --private-key "$PRIVATE_KEY" \
    --broadcast \
    --verify \
    -vvv

echo ""
echo -e "${GREEN}=== Deployment Complete! ===${NC}"
echo ""
echo -e "${GREEN}Next steps:${NC}"
echo "1. Check Etherscan for verified contracts"
echo "2. Review deployed addresses in addressBook/11155111.json"
echo "3. Test vault creation using the factory"
echo ""
echo -e "${GREEN}Verification status:${NC}"
echo "- Implementation contracts should be verified automatically"
echo "- Proxy contracts will show 'More Options' -> 'Is this a proxy?' on Etherscan"
echo "- If verification failed, use manual commands from deployment output"
echo ""
echo -e "${GREEN}Done! 🚀${NC}" 