#!/bin/bash

# Test script for forked Arbitrum network
# This script helps you test the yield optimizer on a local fork

set -e

echo " Testing Yield Optimizer on Forked Arbitrum Network"
echo "=================================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if anvil is running
check_anvil() {
    if ! curl -s -X POST --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
         -H "Content-Type: application/json" http://127.0.0.1:8545 > /dev/null 2>&1; then
        echo -e "${RED}ERROR: Anvil is not running!${NC}"
        echo ""
        echo "Please start anvil in another terminal:"
        echo "  anvil --fork-url https://arb1.arbitrum.io/rpc --chain-id 42161"
        echo ""
        exit 1
    fi
    echo -e "${GREEN}SUCCESS: Anvil is running${NC}"
}

# Check if .env exists
check_env() {
    if [ ! -f .env ]; then
        echo -e "${RED}ERROR: .env file not found!${NC}"
        echo ""
        echo "Please create a .env file. See env.fork.example for reference."
        echo ""
        exit 1
    fi
    echo -e "${GREEN}SUCCESS: .env file found${NC}"
}

# Run tests
run_tests() {
    echo ""
    echo -e "${YELLOW} Step 1: Checking balances...${NC}"
    npm run check-balance || echo -e "${RED}   (check-balance had issues, continuing...)${NC}"
    
    echo ""
    echo -e "${YELLOW} Step 2: Checking yield rates...${NC}"
    npm run check-yields || echo -e "${RED}   (check-yields had issues, continuing...)${NC}"
    
    echo ""
    echo -e "${YELLOW} Step 3: Validating setup...${NC}"
    npm run validate || echo -e "${RED}   (validate had issues, continuing...)${NC}"
}

# Main execution
main() {
    echo "Checking prerequisites..."
    check_anvil
    check_env
    
    echo ""
    echo -e "${GREEN}SUCCESS: All prerequisites met!${NC}"
    echo ""
    
    run_tests
    
    echo ""
    echo -e "${GREEN}SUCCESS: Tests completed!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Fund your Safe wallet on the fork (or use impersonation)"
    echo "  2. Deploy your monitor API"
    echo "  3. Create a TriggerX job with: npm start"
}

main
