#!/bin/bash

# Script to impersonate a USDC whale on forked Arbitrum
# This allows you to test with real funds on the fork without needing actual tokens

set -e

USDC_WHALE="0x489ee077994B6658eAfA855C308275EAd8097C4A"  # Large USDC holder on Arbitrum
USDC_TOKEN="0xaf88d065e77c8cC2239327C5EDb3A432268e5831"
YOUR_ADDRESS="${1:-0x844294eBecC14e934d9d72a319E6Fa9DbAf95Bc5}"  # Default to your address
AMOUNT="${2:-1000000000}"  # 1000 USDC (6 decimals)

echo "🐋 Impersonating USDC Whale on Forked Arbitrum"
echo "=============================================="
echo ""
echo "Whale Address: $USDC_WHALE"
echo "Your Address:  $YOUR_ADDRESS"
echo "Amount:        $AMOUNT (raw)"
echo ""

# Fund the whale with ETH for gas (10 ETH = 0x8AC7230489E80000 wei)
echo " Funding whale with ETH for gas..."
cast rpc anvil_setBalance $USDC_WHALE 0x8AC7230489E80000 --rpc-url http://127.0.0.1:8545
echo "SUCCESS: Whale funded with 10 ETH"

# Impersonate the whale account
echo "🔓 Impersonating whale account..."
cast rpc anvil_impersonateAccount $USDC_WHALE --rpc-url http://127.0.0.1:8545
echo "SUCCESS: Impersonating whale account"

# Check whale's USDC balance first
echo " Checking whale's USDC balance..."
WHALE_BALANCE=$(cast call $USDC_TOKEN "balanceOf(address)(uint256)" $USDC_WHALE --rpc-url http://127.0.0.1:8545)
echo "   Whale USDC Balance: $WHALE_BALANCE"

# Transfer USDC from whale to your address
echo "💸 Transferring USDC to your address..."
cast send $USDC_TOKEN \
  "transfer(address,uint256)" \
  $YOUR_ADDRESS \
  $AMOUNT \
  --from $USDC_WHALE \
  --rpc-url http://127.0.0.1:8545 \
  --unlocked

echo "SUCCESS: Transferred USDC to your address"

# Stop impersonating
cast rpc anvil_stopImpersonatingAccount $USDC_WHALE --rpc-url http://127.0.0.1:8545

# Check your new balance
BALANCE=$(cast call $USDC_TOKEN "balanceOf(address)(uint256)" $YOUR_ADDRESS --rpc-url http://127.0.0.1:8545)
echo ""
echo "Your USDC Balance: $BALANCE"
echo ""
echo "🎉 Done! You now have USDC on the forked network"
