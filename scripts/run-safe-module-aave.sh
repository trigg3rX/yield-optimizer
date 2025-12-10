#!/bin/bash

# Script to run the Safe Module Aave Supply Foundry script
# Requires anvil to be running with Arbitrum fork

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║     Safe Module Aave Supply - Foundry Script              ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check if anvil is running
if ! curl -s -X POST --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
     -H "Content-Type: application/json" http://127.0.0.1:8545 > /dev/null 2>&1; then
    echo -e "${RED}ERROR: Anvil is not running!${NC}"
    echo ""
    echo "Start it with:"
    echo "  anvil --fork-url https://arb1.arbitrum.io/rpc --chain-id 42161"
    exit 1
fi
echo -e "${GREEN}SUCCESS: Anvil is running${NC}"

# Navigate to foundry directory
cd "$(dirname "$0")/../foundry"

# Which script to run (default to main one)
SCRIPT="${1:-SafeModuleAaveSupply}"

echo ""
echo -e "${YELLOW}Running script: ${SCRIPT}${NC}"
echo ""

# Build first
echo -e "${BLUE}Building contracts...${NC}"
forge build

echo ""
echo -e "${BLUE}Running script...${NC}"
echo ""

# Run the script
forge script script/SafeModuleAaveSupply.s.sol:${SCRIPT} \
    --rpc-url http://127.0.0.1:8545 \
    --broadcast \
    -vvvv

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}SUCCESS: Script completed!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo "Available scripts:"
echo "  SafeModuleAaveSupply              - Main version with error handling"
echo "  SafeModuleAaveSupplyAlternative   - Direct module impersonation"
echo "  SafeModuleAaveSupplyWithTaskExecution - Full task execution flow"
echo ""
echo "Usage: $0 [ScriptName]"
echo ""
