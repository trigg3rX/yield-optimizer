#!/bin/bash

# Comprehensive verification script for Yield Optimizer
# Tests all components to ensure everything is working

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║     Yield Optimizer - Complete Verification              ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

PASSED=0
FAILED=0

# Test 1: RPC Connection
test_rpc() {
    echo -e "${YELLOW}  Testing RPC Connection...${NC}"
    RPC_URL=$(grep "^RPC_URL=" .env 2>/dev/null | cut -d'=' -f2)
    
    if [ -z "$RPC_URL" ]; then
        echo -e "${RED}   ERROR: RPC_URL not found${NC}\n"
        return 1
    fi
    
    BLOCK=$(curl -s -X POST --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
             -H "Content-Type: application/json" "$RPC_URL" 2>/dev/null | grep -o '"result":"[^"]*"' | cut -d'"' -f4)
    
    if [ -n "$BLOCK" ]; then
        BLOCK_DEC=$(printf "%d" $BLOCK 2>/dev/null || echo "N/A")
        echo -e "${GREEN}   SUCCESS: Connected (Block: $BLOCK_DEC)${NC}\n"
        return 0
    else
        echo -e "${RED}   ERROR: Connection failed${NC}\n"
        return 1
    fi
}

# Test 2: Monitor API
test_api() {
    echo -e "${YELLOW}  Testing Monitor API...${NC}"
    
    if ! curl -s http://localhost:3000/api/monitor > /tmp/api-response.json 2>/dev/null; then
        echo -e "${RED}   ERROR: API not accessible${NC}"
        echo -e "${YELLOW}    Start API with: ./scripts/test-yield-optimizer-fork.sh${NC}\n"
        return 1
    fi
    
    if [ ! -s /tmp/api-response.json ]; then
        echo -e "${RED}   ERROR: Empty API response${NC}\n"
        return 1
    fi
    
    VALUE=$(cat /tmp/api-response.json | grep -o '"value":[0-9]*' | cut -d':' -f2 || echo "")
    AAVE=$(cat /tmp/api-response.json | grep -o '"aaveAPY":[0-9]*' | cut -d':' -f2 || echo "")
    COMPOUND=$(cat /tmp/api-response.json | grep -o '"compoundAPY":[0-9]*' | cut -d':' -f2 || echo "")
    
    if [ -n "$VALUE" ] && [ -n "$AAVE" ] && [ -n "$COMPOUND" ]; then
        AAVE_PCT=$(echo "scale=2; $AAVE / 100" | bc)
        COMPOUND_PCT=$(echo "scale=2; $COMPOUND / 100" | bc)
        DIFF_PCT=$(echo "scale=2; $VALUE / 100" | bc)
        
        echo -e "${GREEN}   SUCCESS: API working${NC}"
        echo "      Aave: ${AAVE_PCT}% | Compound: ${COMPOUND_PCT}% | Diff: ${DIFF_PCT}%"
        echo ""
        return 0
    else
        echo -e "${RED}   ERROR: Invalid API response format${NC}\n"
        return 1
    fi
}

# Test 3: Yield Monitor Script
test_yield_script() {
    echo -e "${YELLOW}  Testing Yield Monitor Script...${NC}"
    
    if npx ts-node src/yieldMonitor.ts > /tmp/yield-output.txt 2>&1; then
        if grep -q "Aave APY:" /tmp/yield-output.txt && grep -q "Compound APY:" /tmp/yield-output.txt; then
            echo -e "${GREEN}   SUCCESS: Script working${NC}\n"
            return 0
        else
            echo -e "${RED}   ERROR: Script output invalid${NC}\n"
            return 1
        fi
    else
        echo -e "${RED}   ERROR: Script failed${NC}\n"
        return 1
    fi
}

# Test 4: Trigger Condition
test_condition() {
    echo -e "${YELLOW}  Testing Trigger Condition...${NC}"
    
    THRESHOLD=$(grep "^MIN_YIELD_DIFFERENCE=" .env 2>/dev/null | cut -d'=' -f2 || echo "50")
    VALUE=$(cat /tmp/api-response.json 2>/dev/null | grep -o '"value":[0-9]*' | cut -d':' -f2 || echo "0")
    
    if [ -z "$VALUE" ]; then
        echo -e "${RED}   ERROR: Could not get yield difference${NC}\n"
        return 1
    fi
    
    THRESHOLD_PCT=$(echo "scale=2; $THRESHOLD / 100" | bc)
    VALUE_PCT=$(echo "scale=2; $VALUE / 100" | bc)
    
    echo "      Threshold: ${THRESHOLD_PCT}% | Current: ${VALUE_PCT}%"
    
    if [ "$VALUE" -ge "$THRESHOLD" ]; then
        echo -e "${GREEN}   SUCCESS: Condition MET - Will trigger!${NC}\n"
    else
        echo -e "${YELLOW}   WARNING:  Condition NOT MET - Below threshold${NC}\n"
    fi
    return 0
}

# Test 5: Environment Variables
test_env() {
    echo -e "${YELLOW}  Checking Environment Variables...${NC}"
    
    REQUIRED=("TRIGGERX_API_KEY" "PRIVATE_KEY" "SAFE_WALLET_ADDRESS" "MONITOR_URL" "TOKEN_ADDRESS")
    MISSING=()
    
    for var in "${REQUIRED[@]}"; do
        if ! grep -q "^${var}=" .env 2>/dev/null || grep -q "^${var}=$" .env 2>/dev/null; then
            MISSING+=("$var")
        fi
    done
    
    if [ ${#MISSING[@]} -eq 0 ]; then
        echo -e "${GREEN}   SUCCESS: All required variables set${NC}\n"
        return 0
    else
        echo -e "${RED}   ERROR: Missing: ${MISSING[*]}${NC}\n"
        return 1
    fi
}

# Test 6: SDK Installation
test_sdk() {
    echo -e "${YELLOW}  Checking TriggerX SDK...${NC}"
    
    if [ ! -d "node_modules/sdk-triggerx" ]; then
        echo -e "${RED}   ERROR: SDK not installed${NC}\n"
        return 1
    fi
    
    if [ ! -d "node_modules/sdk-triggerx/dist" ]; then
        echo -e "${RED}   ERROR: SDK dist folder missing${NC}\n"
        return 1
    fi
    
    if node -e "require('sdk-triggerx')" 2>/dev/null; then
        echo -e "${GREEN}   SUCCESS: SDK installed and working${NC}\n"
        return 0
    else
        echo -e "${RED}   ERROR: SDK import failed${NC}\n"
        return 1
    fi
}

# Main
main() {
    test_rpc && ((PASSED++)) || ((FAILED++))
    test_env && ((PASSED++)) || ((FAILED++))
    test_sdk && ((PASSED++)) || ((FAILED++))
    test_api && ((PASSED++)) || ((FAILED++))
    test_yield_script && ((PASSED++)) || ((FAILED++))
    test_condition && ((PASSED++)) || ((FAILED++))
    
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}SUCCESS: Passed: $PASSED${NC}"
    if [ $FAILED -gt 0 ]; then
        echo -e "${RED}ERROR: Failed: $FAILED${NC}"
    fi
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    if [ $FAILED -eq 0 ]; then
        echo -e "${GREEN}🎉 All tests passed! Yield optimizer is ready.${NC}"
        echo ""
        echo " Next steps:"
        echo "   1. Check TriggerX dashboard: https://app.triggerx.network"
        echo "   2. Verify your job is listed and active"
        echo "   3. Monitor for automatic execution when condition is met"
    else
        echo -e "${YELLOW}WARNING:  Some issues found. Please fix them before proceeding.${NC}"
    fi
    echo ""
}

main

