#!/bin/bash

# All-in-one script to test TriggerX job on fork
# This script does everything: starts API, creates job, monitors

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║     TriggerX Job Test - Forked Network                   ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check anvil
if ! curl -s -X POST --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
     -H "Content-Type: application/json" http://127.0.0.1:8545 > /dev/null 2>&1; then
    echo -e "${RED}ERROR: Anvil is not running!${NC}"
    echo ""
    echo "Start it with:"
    echo "  anvil --fork-url https://arb1.arbitrum.io/rpc --chain-id 42161"
    exit 1
fi
echo -e "${GREEN}SUCCESS: Anvil is running${NC}"

# Check .env
if [ ! -f .env ]; then
    echo -e "${RED}ERROR: .env file not found!${NC}"
    exit 1
fi

# Check if MONITOR_URL is set to localhost
if ! grep -q "MONITOR_URL=http://localhost:3000" .env 2>/dev/null; then
    echo -e "${YELLOW}WARNING:  MONITOR_URL not set to localhost${NC}"
    echo ""
    echo "Adding to .env..."
    if ! grep -q "MONITOR_URL" .env; then
        echo "MONITOR_URL=http://localhost:3000/api/monitor" >> .env
    else
        sed -i 's|MONITOR_URL=.*|MONITOR_URL=http://localhost:3000/api/monitor|' .env
    fi
    echo -e "${GREEN}SUCCESS: Updated MONITOR_URL${NC}"
fi

# Start API server
echo -e "\n${YELLOW} Starting local API server...${NC}"

# Kill existing server if running
if lsof -Pi :3000 -sTCP:LISTEN -t >/dev/null 2>&1 ; then
    echo "Port 3000 in use, killing existing process..."
    kill $(lsof -t -i:3000) 2>/dev/null || true
    sleep 1
fi

# Start API server
node -e "
const http = require('http');
const { ethers } = require('ethers');

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
sleep 2

# Test API
if curl -s http://localhost:3000/api/monitor > /dev/null; then
    echo -e "${GREEN}SUCCESS: API server started${NC}"
else
    echo -e "${RED}ERROR: Failed to start API server${NC}"
    exit 1
fi

echo -e "\n${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}SUCCESS: Ready to create TriggerX job!${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo "API is running at: http://localhost:3000/api/monitor"
echo ""
echo -e "${YELLOW}Creating TriggerX job...${NC}"
echo ""

# Create the job
npm run test:triggerx

echo ""
echo -e "${GREEN}SUCCESS: Job creation complete!${NC}"
echo ""
echo " Next steps:"
echo "   1. Check job in TriggerX dashboard (link shown above)"
echo "   2. Monitor execution: npm run check-balance"
echo "   3. Check yields: npm run check-yields"
echo ""
echo -e "${YELLOW}Press Ctrl+C to stop the API server when done${NC}"

# Keep running
wait $API_PID

