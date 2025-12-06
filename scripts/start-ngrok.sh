#!/bin/bash

# Script to start ngrok and expose the local API endpoint

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

API_PORT=${1:-3000}
NGROK_LOG="/tmp/ngrok.log"

echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║     Starting ngrok Tunnel                                 ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# Check if ngrok is installed
if ! command -v ngrok &> /dev/null; then
    echo -e "${RED}ERROR: ngrok is not installed!${NC}"
    echo ""
    echo "Install ngrok:"
    echo "  npm install -g ngrok"
    echo "  # or visit https://ngrok.com/download"
    exit 1
fi

# Check if API is running
if ! curl -s http://localhost:${API_PORT} > /dev/null 2>&1; then
    echo -e "${YELLOW}WARNING:  Warning: API doesn't seem to be running on port ${API_PORT}${NC}"
    echo "   Make sure your API server is started before using ngrok"
    echo ""
fi

# Kill existing ngrok processes
echo -e "${YELLOW} Checking for existing ngrok processes...${NC}"
pkill -f "ngrok http ${API_PORT}" 2>/dev/null || true
sleep 1

# Start ngrok
echo -e "${GREEN} Starting ngrok tunnel on port ${API_PORT}...${NC}"
ngrok http ${API_PORT} --log=stdout > ${NGROK_LOG} 2>&1 &
NGROK_PID=$!

echo "   ngrok PID: ${NGROK_PID}"
echo "   Log file: ${NGROK_LOG}"
echo ""

# Wait for ngrok to start
echo -e "${YELLOW}⏳ Waiting for ngrok to initialize...${NC}"
sleep 4

# Get the public URL
PUBLIC_URL=$(curl -s http://127.0.0.1:4040/api/tunnels 2>/dev/null | grep -o '"public_url":"https://[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$PUBLIC_URL" ]; then
    echo -e "${RED}ERROR: Failed to get ngrok public URL${NC}"
    echo "   Check ngrok log: ${NGROK_LOG}"
    echo "   Or visit: http://127.0.0.1:4040"
    kill $NGROK_PID 2>/dev/null || true
    exit 1
fi

echo ""
echo -e "${GREEN}SUCCESS: ngrok tunnel is active!${NC}"
echo ""
echo -e "${BLUE} Public URL:${NC}"
echo "   ${PUBLIC_URL}"
echo ""
echo -e "${BLUE} API Endpoints:${NC}"
echo "   Monitor: ${PUBLIC_URL}/api/monitor"
echo ""
echo -e "${YELLOW} To update your .env file:${NC}"
echo "   MONITOR_URL=${PUBLIC_URL}/api/monitor"
echo ""
echo -e "${YELLOW} ngrok Dashboard:${NC}"
echo "   http://127.0.0.1:4040"
echo ""
echo -e "${YELLOW}WARNING:  Note: Keep this terminal open or run ngrok in background${NC}"
echo "   To stop: pkill -f 'ngrok http ${API_PORT}'"
echo ""

# Check if .env exists and offer to update
if [ -f .env ]; then
    read -p "Update MONITOR_URL in .env? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if grep -q "^MONITOR_URL=" .env; then
            sed -i "s|^MONITOR_URL=.*|MONITOR_URL=${PUBLIC_URL}/api/monitor|" .env
            echo -e "${GREEN}SUCCESS: Updated MONITOR_URL in .env${NC}"
        else
            echo "MONITOR_URL=${PUBLIC_URL}/api/monitor" >> .env
            echo -e "${GREEN}SUCCESS: Added MONITOR_URL to .env${NC}"
        fi
    fi
fi

