#!/bin/bash

# Script to verify Safe wallet configuration and network compatibility

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║     Safe Wallet Verification Tool                         ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# Check if .env exists
if [ ! -f .env ]; then
    echo -e "${RED}ERROR: .env file not found!${NC}"
    exit 1
fi

# Load environment variables
source .env 2>/dev/null || true

if [ -z "$SAFE_WALLET_ADDRESS" ]; then
    echo -e "${RED}ERROR: SAFE_WALLET_ADDRESS not set in .env${NC}"
    exit 1
fi

if [ -z "$RPC_URL" ]; then
    echo -e "${RED}ERROR: RPC_URL not set in .env${NC}"
    exit 1
fi

CHAIN_ID=${CHAIN_ID:-"42161"}

echo -e "${YELLOW} Checking Safe wallet configuration...${NC}"
echo ""
echo "   Safe Address: $SAFE_WALLET_ADDRESS"
echo "   RPC URL: $RPC_URL"
echo "   Chain ID: $CHAIN_ID"
echo ""

# Run the verification using ts-node with project dependencies
npx ts-node src/verify-safe-wallet.ts

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

