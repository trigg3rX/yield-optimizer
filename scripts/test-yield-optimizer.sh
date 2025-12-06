#!/bin/bash

# Test script to verify Yield Optimizer is working correctly
# Tests: API monitoring, job status, and trigger conditions

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║     Yield Optimizer - Verification Tests                 ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# Test 1: Check Monitor API
test_monitor_api() {
    echo -e "${YELLOW}  Testing Monitor API...${NC}"
    echo ""
    
    if ! curl -s http://localhost:3000/api/monitor > /dev/null 2>&1; then
        echo -e "${RED}ERROR: Monitor API is not running!${NC}"
        echo "   Start it with: ./scripts/test-yield-optimizer-fork.sh"
        return 1
    fi
    
    RESPONSE=$(curl -s http://localhost:3000/api/monitor)
    
    if echo "$RESPONSE" | grep -q "value"; then
        VALUE=$(echo "$RESPONSE" | grep -o '"value":[0-9]*' | cut -d':' -f2)
        AAVE_APY=$(echo "$RESPONSE" | grep -o '"aaveAPY":[0-9]*' | cut -d':' -f2)
        COMPOUND_APY=$(echo "$RESPONSE" | grep -o '"compoundAPY":[0-9]*' | cut -d':' -f2)
        
        if [ -n "$VALUE" ]; then
            VALUE_PERCENT=$(echo "scale=2; $VALUE / 100" | bc)
            AAVE_PERCENT=$(echo "scale=2; $AAVE_APY / 100" | bc)
            COMPOUND_PERCENT=$(echo "scale=2; $COMPOUND_APY / 100" | bc)
            
            echo -e "${GREEN}SUCCESS: Monitor API is working${NC}"
            echo "    Aave APY: ${AAVE_PERCENT}%"
            echo "    Compound APY: ${COMPOUND_PERCENT}%"
            echo "    Difference: ${VALUE_PERCENT}%"
            echo ""
            
            # Check if difference exceeds threshold
            THRESHOLD=$(grep "^MIN_YIELD_DIFFERENCE=" .env 2>/dev/null | cut -d'=' -f2 || echo "50")
            if [ "$VALUE" -ge "$THRESHOLD" ]; then
                echo -e "${GREEN}   SUCCESS: Difference (${VALUE_PERCENT}%) exceeds threshold (${THRESHOLD}bp = $(echo "scale=2; $THRESHOLD / 100" | bc)%)${NC}"
                echo -e "${GREEN}    Job should trigger!${NC}"
            else
                echo -e "${YELLOW}   WARNING:  Difference (${VALUE_PERCENT}%) is below threshold (${THRESHOLD}bp = $(echo "scale=2; $THRESHOLD / 100" | bc)%)${NC}"
                echo -e "${YELLOW}   INFO:  Job will not trigger yet${NC}"
            fi
            echo ""
            return 0
        fi
    fi
    
    echo -e "${RED}ERROR: Invalid API response${NC}"
    echo "   Response: $RESPONSE"
    return 1
}

# Test 2: Check current yields using yieldMonitor
test_yield_monitor() {
    echo -e "${YELLOW}  Testing Yield Monitor Script...${NC}"
    echo ""
    
    if npx ts-node src/yieldMonitor.ts 2>&1 | tee /tmp/yield-monitor-output.txt; then
        echo ""
        if grep -q "Aave APY:" /tmp/yield-monitor-output.txt && grep -q "Compound APY:" /tmp/yield-monitor-output.txt; then
            echo -e "${GREEN}SUCCESS: Yield monitor script is working${NC}"
            echo ""
            return 0
        else
            echo -e "${RED}ERROR: Yield monitor script output is invalid${NC}"
            return 1
        fi
    else
        echo -e "${RED}ERROR: Yield monitor script failed${NC}"
        return 1
    fi
}

# Test 3: Check RPC connection
test_rpc_connection() {
    echo -e "${YELLOW}  Testing RPC Connection...${NC}"
    echo ""
    
    RPC_URL=$(grep "^RPC_URL=" .env 2>/dev/null | cut -d'=' -f2)
    
    if [ -z "$RPC_URL" ]; then
        echo -e "${RED}ERROR: RPC_URL not found in .env${NC}"
        return 1
    fi
    
    BLOCK=$(curl -s -X POST --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
             -H "Content-Type: application/json" "$RPC_URL" 2>/dev/null | grep -o '"result":"[^"]*"' | cut -d'"' -f4)
    
    if [ -n "$BLOCK" ]; then
        BLOCK_DEC=$(printf "%d" $BLOCK 2>/dev/null || echo "N/A")
        echo -e "${GREEN}SUCCESS: RPC connection working${NC}"
        echo "    RPC URL: $RPC_URL"
        echo "   📦 Current Block: $BLOCK_DEC"
        echo ""
        return 0
    else
        echo -e "${RED}ERROR: RPC connection failed${NC}"
        echo "   Check your RPC_URL in .env"
        return 1
    fi
}

# Test 4: Check TriggerX job status (if job ID is available)
test_job_status() {
    echo -e "${YELLOW}  Checking TriggerX Job Status...${NC}"
    echo ""
    
    echo -e "${YELLOW}   INFO:  To check job status:${NC}"
    echo "   1. Visit: https://app.triggerx.network"
    echo "   2. Look for your job in the dashboard"
    echo "   3. Check if it's active and monitoring"
    echo ""
    echo -e "${YELLOW}    Note: Job ID was undefined in creation output${NC}"
    echo "   This might indicate the job wasn't created, or the response format differs"
    echo ""
}

# Test 5: Simulate trigger condition
test_trigger_condition() {
    echo -e "${YELLOW}  Testing Trigger Condition...${NC}"
    echo ""
    
    THRESHOLD=$(grep "^MIN_YIELD_DIFFERENCE=" .env 2>/dev/null | cut -d'=' -f2 || echo "50")
    RESPONSE=$(curl -s http://localhost:3000/api/monitor)
    VALUE=$(echo "$RESPONSE" | grep -o '"value":[0-9]*' | cut -d':' -f2 || echo "0")
    
    if [ -z "$VALUE" ] || [ "$VALUE" = "0" ]; then
        echo -e "${RED}ERROR: Could not get yield difference value${NC}"
        return 1
    fi
    
    echo "   Threshold: ${THRESHOLD}bp ($(echo "scale=2; $THRESHOLD / 100" | bc)%)"
    echo "   Current Difference: ${VALUE}bp ($(echo "scale=2; $VALUE / 100" | bc)%)"
    echo ""
    
    if [ "$VALUE" -ge "$THRESHOLD" ]; then
        echo -e "${GREEN}   SUCCESS: Condition MET - Job should trigger!${NC}"
        echo "   The yield difference exceeds the threshold"
    else
        echo -e "${YELLOW}   WARNING:  Condition NOT MET - Job will not trigger${NC}"
        echo "   The yield difference is below the threshold"
        echo ""
        echo "   To test triggering, you can:"
        echo "   1. Wait for yields to change naturally"
        echo "   2. Manually adjust the threshold temporarily"
        echo "   3. Use a test script to simulate different yield values"
    fi
    echo ""
}

# Main execution
main() {
    echo -e "${BLUE}Running verification tests...${NC}"
    echo ""
    
    TESTS_PASSED=0
    TESTS_FAILED=0
    
    # Run tests
    test_rpc_connection && ((TESTS_PASSED++)) || ((TESTS_FAILED++))
    test_monitor_api && ((TESTS_PASSED++)) || ((TESTS_FAILED++))
    test_yield_monitor && ((TESTS_PASSED++)) || ((TESTS_FAILED++))
    test_trigger_condition && ((TESTS_PASSED++)) || ((TESTS_FAILED++))
    test_job_status
    
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}Tests Passed: $TESTS_PASSED${NC}"
    if [ $TESTS_FAILED -gt 0 ]; then
        echo -e "${RED}Tests Failed: $TESTS_FAILED${NC}"
    fi
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}SUCCESS: All tests passed! Yield optimizer appears to be working.${NC}"
        echo ""
        echo " Next steps:"
        echo "   1. Verify job exists in TriggerX dashboard"
        echo "   2. Monitor job execution over time"
        echo "   3. Check if job triggers when condition is met"
    else
        echo -e "${YELLOW}WARNING:  Some tests failed. Please review the errors above.${NC}"
    fi
    echo ""
}

main

