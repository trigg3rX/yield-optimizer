#!/bin/bash

# Test Yield Optimizer Job Creation on Arbitrum Mainnet Fork
# This script sets up everything needed to test on a local fork

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║  Yield Optimizer - Arbitrum Mainnet Fork Test            ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# Check if Anvil is running
check_anvil() {
    echo -e "${YELLOW} Checking if Anvil is running...${NC}"
    if ! curl -s -X POST --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
         -H "Content-Type: application/json" http://127.0.0.1:8545 > /dev/null 2>&1; then
        echo -e "${RED}ERROR: Anvil is not running!${NC}"
        echo ""
        echo "Start Anvil with:"
        echo -e "  ${GREEN}anvil --fork-url https://arb1.arbitrum.io/rpc --chain-id 42161${NC}"
        echo ""
        echo "Or if you want to fork from a specific block:"
        echo -e "  ${GREEN}anvil --fork-url https://arb1.arbitrum.io/rpc --fork-block-number <BLOCK_NUMBER> --chain-id 42161${NC}"
        echo ""
        exit 1
    fi
    
    # Get current block number
    BLOCK=$(curl -s -X POST --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
             -H "Content-Type: application/json" http://127.0.0.1:8545 | grep -o '"result":"[^"]*"' | cut -d'"' -f4)
    BLOCK_DEC=$(printf "%d" $BLOCK)
    echo -e "${GREEN}SUCCESS: Anvil is running (Block: $BLOCK_DEC)${NC}"
}

# Check .env configuration
check_env() {
    echo ""
    echo -e "${YELLOW} Checking .env configuration...${NC}"
    
    if [ ! -f .env ]; then
        echo -e "${RED}ERROR: .env file not found!${NC}"
        echo ""
        echo "Create .env from env.fork.example:"
        echo "  cp env.fork.example .env"
        exit 1
    fi
    
    # Check RPC_URL
    if ! grep -q "^RPC_URL=http://127.0.0.1:8545" .env 2>/dev/null; then
        echo -e "${YELLOW}WARNING:  RPC_URL not set to localhost${NC}"
        if grep -q "^RPC_URL=" .env; then
            sed -i 's|^RPC_URL=.*|RPC_URL=http://127.0.0.1:8545|' .env
            echo -e "${GREEN}SUCCESS: Updated RPC_URL to http://127.0.0.1:8545${NC}"
        else
            echo "RPC_URL=http://127.0.0.1:8545" >> .env
            echo -e "${GREEN}SUCCESS: Added RPC_URL${NC}"
        fi
    else
        echo -e "${GREEN}SUCCESS: RPC_URL is set correctly${NC}"
    fi
    
    # Check CHAIN_ID
    if ! grep -q "^CHAIN_ID=42161" .env 2>/dev/null; then
        echo -e "${YELLOW}WARNING:  CHAIN_ID not set to 42161${NC}"
        if grep -q "^CHAIN_ID=" .env; then
            sed -i 's|^CHAIN_ID=.*|CHAIN_ID=42161|' .env
            echo -e "${GREEN}SUCCESS: Updated CHAIN_ID to 42161${NC}"
        else
            echo "CHAIN_ID=42161" >> .env
            echo -e "${GREEN}SUCCESS: Added CHAIN_ID${NC}"
        fi
    else
        echo -e "${GREEN}SUCCESS: CHAIN_ID is set correctly${NC}"
    fi
    
    # Check MONITOR_URL
    if ! grep -q "^MONITOR_URL=http://localhost:3000" .env 2>/dev/null; then
        echo -e "${YELLOW}WARNING:  MONITOR_URL not set to localhost${NC}"
        if grep -q "^MONITOR_URL=" .env; then
            sed -i 's|^MONITOR_URL=.*|MONITOR_URL=http://localhost:3000/api/monitor|' .env
            echo -e "${GREEN}SUCCESS: Updated MONITOR_URL${NC}"
        else
            echo "MONITOR_URL=http://localhost:3000/api/monitor" >> .env
            echo -e "${GREEN}SUCCESS: Added MONITOR_URL${NC}"
        fi
    else
        echo -e "${GREEN}SUCCESS: MONITOR_URL is set correctly${NC}"
    fi
}

# Start local API server for yield monitoring
start_local_api() {
    echo ""
    echo -e "${YELLOW} Starting local yield monitor API...${NC}"
    
    # Kill existing server if running
    if lsof -Pi :3000 -sTCP:LISTEN -t >/dev/null 2>&1 ; then
        echo -e "${YELLOW}WARNING:  Port 3000 in use, killing existing process...${NC}"
        kill $(lsof -t -i:3000) 2>/dev/null || true
        sleep 1
    fi
    
    # Start API server
    node -e "
const http = require('http');
const { ethers } = require('ethers');

// Arbitrum mainnet addresses
const AAVE_DATA_PROVIDER = '0x69FA688f1Dc47d4B5d8029D5a35FB7a548310654';
const COMPOUND_COMET = '0x9c4ec768c28520B50860ea7a15bd7213a9fF58bf';
const USDC = '0xaf88d065e77c8cC2239327C5EDb3A432268e5831';
const RPC = 'http://127.0.0.1:8545';

const AAVE_ABI = ['function getReserveData(address) view returns (uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint40)'];
const COMPOUND_ABI = ['function getSupplyRate(uint256) view returns (uint64)', 'function getUtilization() view returns (uint256)'];

async function getYields() {
    const provider = new ethers.JsonRpcProvider(RPC);
    const aave = new ethers.Contract(AAVE_DATA_PROVIDER, AAVE_ABI, provider);
    const compound = new ethers.Contract(COMPOUND_COMET, COMPOUND_ABI, provider);

    try {
        const reserveData = await aave.getReserveData(USDC);
        const aaveAPY = Math.floor(Number(reserveData[5]) / 1e27 * 10000);

        const utilization = await compound.getUtilization();
        const supplyRate = await compound.getSupplyRate(utilization);
        const secondsPerYear = 365.25 * 24 * 60 * 60;
        const compoundAPY = Math.floor(Number(supplyRate) / 1e18 * secondsPerYear * 10000);

        const difference = Math.abs(aaveAPY - compoundAPY);

        return {
            value: difference,
            metadata: {
                aaveAPY,
                compoundAPY,
                difference,
                betterProtocol: aaveAPY > compoundAPY ? 'aave' : 'compound',
                timestamp: Date.now(),
                network: 'arbitrum-fork'
            }
        };
    } catch (error) {
        console.error('Error fetching yields:', error.message);
        throw error;
    }
}

const server = http.createServer(async (req, res) => {
    if (req.url === '/api/monitor' && req.method === 'GET') {
        res.setHeader('Access-Control-Allow-Origin', '*');
        res.setHeader('Content-Type', 'application/json');
        try {
            const data = await getYields();
            res.writeHead(200);
            res.end(JSON.stringify(data));
        } catch (error) {
            res.writeHead(500);
            res.end(JSON.stringify({ error: error.message }));
        }
    } else {
        res.writeHead(404);
        res.end('Not found');
    }
});

server.listen(3000, () => {
    console.log('SUCCESS: API server running on http://localhost:3000/api/monitor');
});
" > /tmp/api-server.js &

API_PID=$!
echo $API_PID > /tmp/yield-optimizer-api.pid

# Wait for server to start
sleep 2

# Test the API
if curl -s http://localhost:3000/api/monitor > /dev/null; then
    echo -e "${GREEN}SUCCESS: API server started successfully${NC}"
    echo "   URL: http://localhost:3000/api/monitor"
else
    echo -e "${RED}ERROR: Failed to start API server${NC}"
    exit 1
fi
}

# Stop API server
stop_local_api() {
    if [ -f /tmp/yield-optimizer-api.pid ]; then
        PID=$(cat /tmp/yield-optimizer-api.pid)
        if kill -0 $PID 2>/dev/null; then
            kill $PID 2>/dev/null || true
            echo -e "\n${YELLOW}🛑 Stopped local API server${NC}"
        fi
        rm /tmp/yield-optimizer-api.pid
    fi
}

# Cleanup on exit
trap stop_local_api EXIT

# Main execution
main() {
    check_anvil
    check_env
    start_local_api
    
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}SUCCESS: Setup complete! Ready to create TriggerX job${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo " Configuration:"
    echo "   • Network: Arbitrum Mainnet Fork (localhost:8545)"
    echo "   • Chain ID: 42161"
    echo "   • Monitor API: http://localhost:3000/api/monitor"
    echo ""
    echo -e "${YELLOW} Creating TriggerX job...${NC}"
    echo ""
    
    # Create the job
    if ./scripts/create-yield-optimizer-job.sh; then
        echo ""
        echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}SUCCESS: Job creation completed!${NC}"
        echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
        echo ""
        echo " Next steps:"
        echo "   1. Check your job in TriggerX dashboard: https://app.triggerx.network"
        echo "   2. Monitor job execution and status"
        echo "   3. Test yields: npm run check-yields"
        echo "   4. Check balance: npm run check-balance"
        echo ""
        echo -e "${YELLOW} The API server will keep running. Press Ctrl+C to stop.${NC}"
        echo ""
        
        # Keep running to maintain API server
        wait $API_PID
    else
        echo ""
        echo -e "${RED}ERROR: Job creation failed!${NC}"
        echo ""
        echo "Please check:"
        echo "   1. Your TRIGGERX_API_KEY is valid"
        echo "   2. Your PRIVATE_KEY is correct"
        echo "   3. Your SAFE_WALLET_ADDRESS is set"
        echo "   4. All environment variables are correct"
        echo ""
        exit 1
    fi
}

main

