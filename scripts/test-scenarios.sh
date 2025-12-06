#!/bin/bash

# Comprehensive Fork Testing Script
# Tests various yield optimizer scenarios on forked Arbitrum

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Addresses
SAFE="0xC9C19C9d84Bf5f6AF1047DE5a0B5cb2aBf90D5F2"
EOA="0x844294eBecC14e934d9d72a319E6Fa9DbAf95Bc5"
USDC="0xaf88d065e77c8cC2239327C5EDb3A432268e5831"
AAVE_POOL="0x794a61358D6845594F94dc1DB02A252b5b4814aD"
COMPOUND="0x9c4ec768c28520B50860ea7a15bd7213a9fF58bf"
USDC_WHALE="0x489ee077994B6658eAfA855C308275EAd8097C4A"
PRIVATE_KEY="c7453a61c8123d48bae72508c3d001cd92aacac1d2acb24d8be66ebb0b8c60a8"
RPC="http://127.0.0.1:8545"

echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║     YIELD OPTIMIZER - COMPREHENSIVE FORK TESTING          ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check if anvil is running
check_anvil() {
    if ! curl -s -X POST --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
         -H "Content-Type: application/json" $RPC > /dev/null 2>&1; then
        echo -e "${RED}ERROR: Anvil is not running!${NC}"
        echo "Start it with: anvil --fork-url https://arb1.arbitrum.io/rpc --chain-id 42161"
        exit 1
    fi
    echo -e "${GREEN}SUCCESS: Anvil is running${NC}"
}

# Helper function to get USDC balance
get_usdc_balance() {
    local addr=$1
    cast call $USDC "balanceOf(address)(uint256)" $addr --rpc-url $RPC 2>/dev/null | head -1
}

# Helper function to get Compound balance
get_compound_balance() {
    local addr=$1
    cast call $COMPOUND "balanceOf(address)(uint256)" $addr --rpc-url $RPC 2>/dev/null | head -1
}

# Create snapshot for rollback
create_snapshot() {
    SNAPSHOT=$(cast rpc evm_snapshot --rpc-url $RPC | tr -d '"')
    echo $SNAPSHOT
}

# Revert to snapshot
revert_snapshot() {
    local snap=$1
    cast rpc evm_revert $snap --rpc-url $RPC > /dev/null 2>&1
}

# Fund an address with ETH and USDC
fund_address() {
    local addr=$1
    local usdc_amount=$2
    
    # Fund with ETH
    cast rpc anvil_setBalance $addr 0x8AC7230489E80000 --rpc-url $RPC > /dev/null
    
    # Fund with USDC from whale
    cast rpc anvil_impersonateAccount $USDC_WHALE --rpc-url $RPC > /dev/null
    cast rpc anvil_setBalance $USDC_WHALE 0x8AC7230489E80000 --rpc-url $RPC > /dev/null
    cast send $USDC "transfer(address,uint256)" $addr $usdc_amount \
        --from $USDC_WHALE --rpc-url $RPC --unlocked > /dev/null 2>&1
    cast rpc anvil_stopImpersonatingAccount $USDC_WHALE --rpc-url $RPC > /dev/null
}

# ═══════════════════════════════════════════════════════════════
# SCENARIO 1: Fresh Start - Deposit to Higher Yielding Protocol
# ═══════════════════════════════════════════════════════════════
scenario_1() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}SCENARIO 1: Fresh Start - Deposit to Higher Yielding Protocol${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    
    local snap=$(create_snapshot)
    
    # Reset and fund
    fund_address $SAFE 1000000000  # 1000 USDC
    
    echo -e "\n Checking current yields..."
    npm run check-yields --silent 2>/dev/null | grep -E "(Aave APY|Compound APY|Better protocol)"
    
    echo -e "\n Initial Safe balance: $(get_usdc_balance $SAFE) (raw USDC)"
    
    # Deposit to Compound (assuming it has higher APY)
    echo -e "\n Depositing 500 USDC to Compound..."
    cast rpc anvil_impersonateAccount $SAFE --rpc-url $RPC > /dev/null
    cast send $USDC "approve(address,uint256)" $COMPOUND 500000000 \
        --from $SAFE --rpc-url $RPC --unlocked > /dev/null 2>&1
    cast send $COMPOUND "supply(address,uint256)" $USDC 500000000 \
        --from $SAFE --rpc-url $RPC --unlocked > /dev/null 2>&1
    cast rpc anvil_stopImpersonatingAccount $SAFE --rpc-url $RPC > /dev/null
    
    echo -e "${GREEN}SUCCESS: Deposited to Compound${NC}"
    echo -e "   Compound balance: $(get_compound_balance $SAFE)"
    echo -e "   Wallet balance: $(get_usdc_balance $SAFE)"
    
    revert_snapshot $snap
    echo -e "${GREEN}SUCCESS: Scenario 1 Complete - State reverted${NC}"
}

# ═══════════════════════════════════════════════════════════════
# SCENARIO 2: Full Rebalance - Aave to Compound
# ═══════════════════════════════════════════════════════════════
scenario_2() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}SCENARIO 2: Full Rebalance - Aave → Compound${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    
    local snap=$(create_snapshot)
    
    # Fund and deposit to Aave first
    fund_address $SAFE 500000000
    
    echo -e "\n Step 1: Depositing 500 USDC to Aave..."
    cast rpc anvil_impersonateAccount $SAFE --rpc-url $RPC > /dev/null
    cast send $USDC "approve(address,uint256)" $AAVE_POOL 500000000 \
        --from $SAFE --rpc-url $RPC --unlocked > /dev/null 2>&1
    cast send $AAVE_POOL "supply(address,uint256,address,uint16)" $USDC 500000000 $SAFE 0 \
        --from $SAFE --rpc-url $RPC --unlocked > /dev/null 2>&1
    
    echo -e "${GREEN}SUCCESS: Deposited to Aave${NC}"
    
    # Check yields - should recommend moving to Compound
    echo -e "\n Checking yields (should recommend Compound)..."
    npm run check-yields --silent 2>/dev/null | grep -E "(Current position|Should move|Better protocol)"
    
    # Rebalance: Withdraw from Aave, deposit to Compound
    echo -e "\n Step 2: Withdrawing from Aave..."
    cast send $AAVE_POOL "withdraw(address,uint256,address)" $USDC 499999999 $SAFE \
        --from $SAFE --rpc-url $RPC --unlocked > /dev/null 2>&1
    echo -e "${GREEN}SUCCESS: Withdrawn from Aave${NC}"
    
    echo -e "\n Step 3: Depositing to Compound..."
    local balance=$(get_usdc_balance $SAFE)
    cast send $USDC "approve(address,uint256)" $COMPOUND $balance \
        --from $SAFE --rpc-url $RPC --unlocked > /dev/null 2>&1
    cast send $COMPOUND "supply(address,uint256)" $USDC $balance \
        --from $SAFE --rpc-url $RPC --unlocked > /dev/null 2>&1
    cast rpc anvil_stopImpersonatingAccount $SAFE --rpc-url $RPC > /dev/null
    
    echo -e "${GREEN}SUCCESS: Deposited to Compound${NC}"
    echo -e "   New Compound balance: $(get_compound_balance $SAFE)"
    
    # Verify new position
    echo -e "\n Final position check..."
    npm run check-yields --silent 2>/dev/null | grep -E "(Current position|Should move)"
    
    revert_snapshot $snap
    echo -e "${GREEN}SUCCESS: Scenario 2 Complete - State reverted${NC}"
}

# ═══════════════════════════════════════════════════════════════
# SCENARIO 3: Compound to Aave (Reverse Direction)
# ═══════════════════════════════════════════════════════════════
scenario_3() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}SCENARIO 3: Reverse Rebalance - Compound → Aave${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    
    local snap=$(create_snapshot)
    
    # Fund and deposit to Compound first
    fund_address $SAFE 500000000
    
    echo -e "\n Step 1: Depositing 500 USDC to Compound..."
    cast rpc anvil_impersonateAccount $SAFE --rpc-url $RPC > /dev/null
    cast send $USDC "approve(address,uint256)" $COMPOUND 500000000 \
        --from $SAFE --rpc-url $RPC --unlocked > /dev/null 2>&1
    cast send $COMPOUND "supply(address,uint256)" $USDC 500000000 \
        --from $SAFE --rpc-url $RPC --unlocked > /dev/null 2>&1
    
    echo -e "${GREEN}SUCCESS: Deposited to Compound${NC}"
    echo -e "   Compound balance: $(get_compound_balance $SAFE)"
    
    # Simulate rebalance to Aave (even if Aave APY is lower, testing the mechanism)
    echo -e "\n Step 2: Withdrawing from Compound..."
    cast send $COMPOUND "withdraw(address,uint256)" $USDC 499999999 \
        --from $SAFE --rpc-url $RPC --unlocked > /dev/null 2>&1
    echo -e "${GREEN}SUCCESS: Withdrawn from Compound${NC}"
    
    echo -e "\n Step 3: Depositing to Aave..."
    local balance=$(get_usdc_balance $SAFE)
    cast send $USDC "approve(address,uint256)" $AAVE_POOL $balance \
        --from $SAFE --rpc-url $RPC --unlocked > /dev/null 2>&1
    cast send $AAVE_POOL "supply(address,uint256,address,uint16)" $USDC $balance $SAFE 0 \
        --from $SAFE --rpc-url $RPC --unlocked > /dev/null 2>&1
    cast rpc anvil_stopImpersonatingAccount $SAFE --rpc-url $RPC > /dev/null
    
    echo -e "${GREEN}SUCCESS: Deposited to Aave${NC}"
    
    # Verify
    echo -e "\n Final position check..."
    npm run check-yields --silent 2>/dev/null | grep -E "(Current position|Should move)"
    
    revert_snapshot $snap
    echo -e "${GREEN}SUCCESS: Scenario 3 Complete - State reverted${NC}"
}

# ═══════════════════════════════════════════════════════════════
# SCENARIO 4: Small Amount (Edge Case)
# ═══════════════════════════════════════════════════════════════
scenario_4() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}SCENARIO 4: Small Amount Test (1 USDC)${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    
    local snap=$(create_snapshot)
    
    fund_address $SAFE 1000000  # 1 USDC
    
    echo -e "\n Testing with small amount: 1 USDC"
    
    cast rpc anvil_impersonateAccount $SAFE --rpc-url $RPC > /dev/null
    cast send $USDC "approve(address,uint256)" $COMPOUND 1000000 \
        --from $SAFE --rpc-url $RPC --unlocked > /dev/null 2>&1
    
    if cast send $COMPOUND "supply(address,uint256)" $USDC 1000000 \
        --from $SAFE --rpc-url $RPC --unlocked > /dev/null 2>&1; then
        echo -e "${GREEN}SUCCESS: Small amount deposit successful${NC}"
        echo -e "   Compound balance: $(get_compound_balance $SAFE)"
    else
        echo -e "${RED}ERROR: Small amount deposit failed${NC}"
    fi
    
    cast rpc anvil_stopImpersonatingAccount $SAFE --rpc-url $RPC > /dev/null
    
    revert_snapshot $snap
    echo -e "${GREEN}SUCCESS: Scenario 4 Complete - State reverted${NC}"
}

# ═══════════════════════════════════════════════════════════════
# SCENARIO 5: Large Amount (Whale Test)
# ═══════════════════════════════════════════════════════════════
scenario_5() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}SCENARIO 5: Large Amount Test (100,000 USDC)${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    
    local snap=$(create_snapshot)
    
    fund_address $SAFE 100000000000  # 100,000 USDC
    
    echo -e "\n Testing with large amount: 100,000 USDC"
    echo -e "   Initial balance: $(get_usdc_balance $SAFE)"
    
    cast rpc anvil_impersonateAccount $SAFE --rpc-url $RPC > /dev/null
    cast send $USDC "approve(address,uint256)" $COMPOUND 100000000000 \
        --from $SAFE --rpc-url $RPC --unlocked > /dev/null 2>&1
    
    if cast send $COMPOUND "supply(address,uint256)" $USDC 100000000000 \
        --from $SAFE --rpc-url $RPC --unlocked > /dev/null 2>&1; then
        echo -e "${GREEN}SUCCESS: Large amount deposit successful${NC}"
        echo -e "   Compound balance: $(get_compound_balance $SAFE)"
    else
        echo -e "${RED}ERROR: Large amount deposit failed (may exceed liquidity)${NC}"
    fi
    
    cast rpc anvil_stopImpersonatingAccount $SAFE --rpc-url $RPC > /dev/null
    
    revert_snapshot $snap
    echo -e "${GREEN}SUCCESS: Scenario 5 Complete - State reverted${NC}"
}

# ═══════════════════════════════════════════════════════════════
# SCENARIO 6: Yield Difference Below Threshold
# ═══════════════════════════════════════════════════════════════
scenario_6() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}SCENARIO 6: Check Threshold Logic${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    
    echo -e "\n Current yield difference and threshold:"
    npm run check-yields --silent 2>/dev/null | grep -E "(Difference|Should move|MIN_YIELD)"
    
    echo -e "\n The optimizer only recommends moving if:"
    echo -e "   1. Difference > MIN_YIELD_DIFFERENCE (default: 50 basis points = 0.5%)"
    echo -e "   2. Funds are in the lower-yielding protocol"
    echo -e "   3. There are funds to move"
    
    echo -e "${GREEN}SUCCESS: Scenario 6 Complete${NC}"
}

# ═══════════════════════════════════════════════════════════════
# SCENARIO 7: Split Position (Funds in Both Protocols)
# ═══════════════════════════════════════════════════════════════
scenario_7() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}SCENARIO 7: Split Position - Funds in Both Protocols${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    
    local snap=$(create_snapshot)
    
    fund_address $SAFE 1000000000  # 1000 USDC
    
    cast rpc anvil_impersonateAccount $SAFE --rpc-url $RPC > /dev/null
    
    # Deposit 500 to Aave
    echo -e "\n Depositing 500 USDC to Aave..."
    cast send $USDC "approve(address,uint256)" $AAVE_POOL 500000000 \
        --from $SAFE --rpc-url $RPC --unlocked > /dev/null 2>&1
    cast send $AAVE_POOL "supply(address,uint256,address,uint16)" $USDC 500000000 $SAFE 0 \
        --from $SAFE --rpc-url $RPC --unlocked > /dev/null 2>&1
    
    # Deposit 500 to Compound
    echo -e " Depositing 500 USDC to Compound..."
    cast send $USDC "approve(address,uint256)" $COMPOUND 500000000 \
        --from $SAFE --rpc-url $RPC --unlocked > /dev/null 2>&1
    cast send $COMPOUND "supply(address,uint256)" $USDC 500000000 \
        --from $SAFE --rpc-url $RPC --unlocked > /dev/null 2>&1
    
    cast rpc anvil_stopImpersonatingAccount $SAFE --rpc-url $RPC > /dev/null
    
    echo -e "${GREEN}SUCCESS: Funds split between protocols${NC}"
    echo -e "   Compound balance: $(get_compound_balance $SAFE)"
    
    npm run check-balance --silent 2>/dev/null | grep -E "(In Aave|In Compound|SAFE WALLET)" | head -6
    
    revert_snapshot $snap
    echo -e "${GREEN}SUCCESS: Scenario 7 Complete - State reverted${NC}"
}

# ═══════════════════════════════════════════════════════════════
# SCENARIO 8: Gas Cost Analysis
# ═══════════════════════════════════════════════════════════════
scenario_8() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}SCENARIO 8: Gas Cost Analysis${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    
    local snap=$(create_snapshot)
    
    fund_address $SAFE 500000000
    
    cast rpc anvil_impersonateAccount $SAFE --rpc-url $RPC > /dev/null
    
    # Measure approval gas
    echo -e "\n⛽ Measuring gas costs..."
    
    local approve_result=$(cast send $USDC "approve(address,uint256)" $COMPOUND 500000000 \
        --from $SAFE --rpc-url $RPC --unlocked --json 2>/dev/null)
    local approve_gas=$(echo $approve_result | jq -r '.gasUsed' 2>/dev/null)
    echo -e "   Approve USDC: $approve_gas gas"
    
    local supply_result=$(cast send $COMPOUND "supply(address,uint256)" $USDC 500000000 \
        --from $SAFE --rpc-url $RPC --unlocked --json 2>/dev/null)
    local supply_gas=$(echo $supply_result | jq -r '.gasUsed' 2>/dev/null)
    echo -e "   Supply to Compound: $supply_gas gas"
    
    local withdraw_result=$(cast send $COMPOUND "withdraw(address,uint256)" $USDC 499999999 \
        --from $SAFE --rpc-url $RPC --unlocked --json 2>/dev/null)
    local withdraw_gas=$(echo $withdraw_result | jq -r '.gasUsed' 2>/dev/null)
    echo -e "   Withdraw from Compound: $withdraw_gas gas"
    
    cast rpc anvil_stopImpersonatingAccount $SAFE --rpc-url $RPC > /dev/null
    
    echo -e "\n Typical rebalance costs (Aave→Compound):"
    echo -e "   Withdraw from Aave: ~180,000 gas"
    echo -e "   Approve for Compound: ~55,000 gas"
    echo -e "   Supply to Compound: ~110,000 gas"
    echo -e "   Total: ~345,000 gas"
    
    revert_snapshot $snap
    echo -e "${GREEN}SUCCESS: Scenario 8 Complete - State reverted${NC}"
}

# ═══════════════════════════════════════════════════════════════
# MAIN EXECUTION
# ═══════════════════════════════════════════════════════════════
main() {
    check_anvil
    
    echo -e "\n${YELLOW}Select scenario to run:${NC}"
    echo "  1) Fresh Start - Deposit to Higher Yielding Protocol"
    echo "  2) Full Rebalance - Aave → Compound"
    echo "  3) Reverse Rebalance - Compound → Aave"
    echo "  4) Small Amount Test (1 USDC)"
    echo "  5) Large Amount Test (100,000 USDC)"
    echo "  6) Check Threshold Logic"
    echo "  7) Split Position - Funds in Both"
    echo "  8) Gas Cost Analysis"
    echo "  a) Run ALL scenarios"
    echo "  q) Quit"
    echo ""
    read -p "Enter choice [1-8, a, or q]: " choice
    
    case $choice in
        1) scenario_1 ;;
        2) scenario_2 ;;
        3) scenario_3 ;;
        4) scenario_4 ;;
        5) scenario_5 ;;
        6) scenario_6 ;;
        7) scenario_7 ;;
        8) scenario_8 ;;
        a|A)
            scenario_1
            scenario_2
            scenario_3
            scenario_4
            scenario_5
            scenario_6
            scenario_7
            scenario_8
            ;;
        q|Q)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid choice"
            exit 1
            ;;
    esac
    
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}Testing Complete!${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
}

# Run if called directly, or source for individual scenarios
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

