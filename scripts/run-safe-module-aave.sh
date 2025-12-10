#!/bin/bash

# Script to run the Safe Module Aave Supply Foundry script
# 1. Creates a new Safe Wallet using src/createSafeWallet.ts
# 2. Runs the Foundry script using the created Safe address

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║     Safe Module Aave Supply - Full Flow                   ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Navigate to project root
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

echo -e "${YELLOW}Step 1: Creating Safe Wallet...${NC}"
echo ""

# Run the TypeScript script and capture output
# We use 'tee' to show output to user while capturing it
OUTPUT=$(ts-node src/createSafeWallet.ts | tee /dev/tty)

# Extract Safe Address using regex
# Looks for "Safe Address: 0x..."
SAFE_ADDR=$(echo "$OUTPUT" | grep -oP "Safe Address: \K0x[a-fA-F0-9]{40}")

if [ -z "$SAFE_ADDR" ]; then
    echo ""
    echo -e "${RED}ERROR: Failed to extract Safe Address from output!${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}Successfully captured Safe Address: ${SAFE_ADDR}${NC}"
echo ""

# Export for Foundry
export SAFE_WALLET_ADDRESS=$SAFE_ADDR

echo -e "${YELLOW}Step 2: Running Foundry Script...${NC}"
echo ""

# Navigate to foundry directory
cd foundry

# Build first
echo -e "${BLUE}Building contracts...${NC}"
forge build

echo ""
echo -e "${BLUE}Running script...${NC}"
echo ""

# Run the script
# Using the Tenderly RPC from foundry.toml (via --rpc-url)
# Note: We assume the user wants to use the configured Tenderly RPC
# If they want local anvil, they should change foundry.toml or pass args

forge script script/SafeModuleAaveSupply.s.sol:SafeModuleAaveSupply \
    --rpc-url http://127.0.0.1:8545 \
    --broadcast \
    -vvvv

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}SUCCESS: Full flow completed!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
