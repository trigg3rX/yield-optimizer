#!/bin/bash

# Script to create TriggerX Yield Optimizer Job
# This script validates setup and creates the job

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║     TriggerX Yield Optimizer - Job Creation               ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# Check if .env exists
if [ ! -f .env ]; then
    echo -e "${RED}ERROR: .env file not found!${NC}"
    echo ""
    echo "Please create .env file from env.example:"
    echo "  cp env.example .env"
    echo "  # Then edit .env with your credentials"
    exit 1
fi
echo -e "${GREEN}SUCCESS: .env file found${NC}"

# Check required environment variables
echo ""
echo -e "${YELLOW}Checking environment variables...${NC}"
echo ""

MISSING_VARS=()

if ! grep -q "^TRIGGERX_API_KEY=" .env 2>/dev/null || grep -q "^TRIGGERX_API_KEY=$" .env 2>/dev/null; then
    MISSING_VARS+=("TRIGGERX_API_KEY")
fi

if ! grep -q "^PRIVATE_KEY=" .env 2>/dev/null || grep -q "^PRIVATE_KEY=$" .env 2>/dev/null; then
    MISSING_VARS+=("PRIVATE_KEY")
fi

if ! grep -q "^SAFE_WALLET_ADDRESS=" .env 2>/dev/null || grep -q "^SAFE_WALLET_ADDRESS=$" .env 2>/dev/null; then
    MISSING_VARS+=("SAFE_WALLET_ADDRESS")
fi

if ! grep -q "^MONITOR_URL=" .env 2>/dev/null || grep -q "^MONITOR_URL=$" .env 2>/dev/null; then
    MISSING_VARS+=("MONITOR_URL")
fi

if [ ${#MISSING_VARS[@]} -gt 0 ]; then
    echo -e "${RED}ERROR: Missing required environment variables:${NC}"
    for var in "${MISSING_VARS[@]}"; do
        echo -e "   ${RED}•${NC} $var"
    done
    echo ""
    echo "Please add these to your .env file"
    exit 1
fi

echo -e "${GREEN}SUCCESS: All required environment variables are set${NC}"

# Check if node_modules exists
if [ ! -d "node_modules" ]; then
    echo ""
    echo -e "${YELLOW}WARNING: node_modules not found. Installing dependencies...${NC}"
    npm install
fi

# Check if SDK is installed and has dist folder
if [ ! -d "node_modules/sdk-triggerx" ] || [ ! -d "node_modules/sdk-triggerx/dist" ]; then
    echo ""
    echo -e "${YELLOW}WARNING: TriggerX SDK not found or incomplete. Installing...${NC}"
    npm install git+https://github.com/trigg3rX/triggerx-newSDK.git
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}SUCCESS: Setup validated!${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Creating TriggerX job...${NC}"
echo ""

# Run the job creation script
if npx ts-node src/triggerx-yield-optimizer.ts; then
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}SUCCESS: Job creation completed successfully!${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Next steps:"
    echo "   1. Check your job in TriggerX dashboard: https://app.triggerx.network"
    echo "   2. Monitor job execution and status"
    echo "   3. Check yields: npm run check-yields"
    echo "   4. Check balance: npm run check-balance"
    echo ""
else
    echo ""
    echo -e "${RED}ERROR: Job creation failed!${NC}"
    echo ""
    echo "Please check:"
    echo "   1. Your TRIGGERX_API_KEY is valid"
    echo "   2. Your MONITOR_URL is accessible"
    echo "   3. Your RPC_URL is working"
    echo "   4. All environment variables are correct"
    echo ""
    exit 1
fi

