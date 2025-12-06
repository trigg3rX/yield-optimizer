# TriggerX Network Requirements

## ⚠️ Important: TriggerX Requires Real Network

**TriggerX is a real service that interacts with actual blockchain networks.** It cannot work with local forks.

## Current Issue

You are using:
- **RPC_URL**: `http://127.0.0.1:8545` (local fork)
- **CHAIN_ID**: `42161` (Arbitrum One mainnet)

The problem:
1. TriggerX SDK checks your wallet balance on the **real Arbitrum mainnet**, not your fork
2. Your wallet has 0 ETH on the real network (you only funded the fork)
3. The SDK tries to purchase TG tokens but fails due to insufficient funds

## Solutions

### Option 1: Use Arbitrum Testnet (Recommended for Testing)

1. **Update your `.env` file:**
   ```bash
   RPC_URL=https://sepolia-rollup.arbitrum.io/rpc
   CHAIN_ID=421614
   ```

2. **Get testnet ETH:**
   - Visit Arbitrum Sepolia faucet: https://faucet.quicknode.com/arbitrum/sepolia
   - Or use: https://faucet.chain.link/arbitrum-sepolia

3. **Create Safe wallet on testnet:**
   ```bash
   npm run create-safe
   ```

4. **Fund your wallet with testnet ETH** (for TG token purchase)

### Option 2: Use Arbitrum Mainnet (Production)

1. **Update your `.env` file:**
   ```bash
   RPC_URL=https://arb1.arbitrum.io/rpc
   # Or use Alchemy/Infura: https://arb-mainnet.g.alchemy.com/v2/YOUR_KEY
   CHAIN_ID=42161
   ```

2. **Fund your wallet with real ETH on Arbitrum mainnet**

3. **Create Safe wallet on mainnet:**
   ```bash
   npm run create-safe
   ```

4. **Ensure you have sufficient ETH** (at least 0.1 ETH recommended for TG tokens)

### Option 3: Disable Autotopup and Manually Top Up TG

If you want to test without funding ETH:

1. **Add to `.env`:**
   ```bash
   AUTOTOPUP_TG=false
   ```

2. **Manually top up TG balance:**
   - Visit: https://app.triggerx.network
   - Go to your account/wallet section
   - Top up TG tokens manually

## Why Local Fork Doesn't Work

- TriggerX servers need to execute transactions on the **real blockchain**
- The SDK uses its own RPC providers to check balances on the real network
- Your local fork balance is not accessible to TriggerX servers
- The API endpoints (like your monitor API) need to be publicly accessible (✅ you have this via ngrok)

## Next Steps

1. **Choose a network** (testnet recommended for testing)
2. **Update RPC_URL and CHAIN_ID** in `.env`
3. **Get ETH on that network** (testnet faucet or mainnet transfer)
4. **Create/verify Safe wallet** on that network
5. **Run job creation again**

## Testing Locally

If you want to test the logic locally without TriggerX:
- Use the test scripts: `npm run test:fork`
- Test scenarios: `./scripts/test-scenarios.sh`
- These work with your local fork

But for **actual TriggerX job creation**, you need the real network.

