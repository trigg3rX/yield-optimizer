# 🚀 TriggerX Yield Optimizer

> Automated yield optimization between Aave V3 and Compound V3 on Arbitrum using TriggerX

Automatically rebalances your USDC between Aave and Compound to maximize yield with zero manual intervention.

## ✨ Features

- 🤖 **Fully Automated** - Set it and forget it
- 🔒 **Non-Custodial** - You control your funds via Safe wallet
- ⚡ **Gas Efficient** - Only rebalances when profitable
- 🎯 **Condition-Based** - Triggers only when yield difference exceeds threshold
- 🔄 **Battle-Tested** - Comprehensive test suite on forked mainnet

## 📊 How It Works

1. **Monitor**: TriggerX continuously checks yield differences via your deployed API
2. **Analyze**: When difference exceeds threshold (e.g., 0.5%), job triggers
3. **Execute**: Automatically withdraws from lower APY and deposits to higher APY
4. **Repeat**: Process runs continuously, always optimizing your yields

## 🎯 Quick Start

### 1. Install

```bash
git clone https://github.com/yourusername/yield-optimizer
cd yield-optimizer
npm install
```

### 2. Configure

Create `.env` file:

```bash
# Arbitrum Mainnet
RPC_URL=https://arb1.arbitrum.io/rpc
CHAIN_ID=42161

# Your wallet (must be Safe owner)
PRIVATE_KEY=your_private_key_here
SAFE_WALLET_ADDRESS=your_safe_address_here

# USDC on Arbitrum
TOKEN_ADDRESS=0xaf88d065e77c8cC2239327C5EDb3A432268e5831

# Settings
MIN_YIELD_DIFFERENCE=50  # 0.5%
CHECK_INTERVAL=3600      # 1 hour
JOB_DURATION=2592000     # 30 days

# TriggerX
TRIGGERX_API_KEY=your_api_key_here
MONITOR_URL=https://your-app.vercel.app/api/monitor
```

### 3. Deploy API

Deploy the yield monitor API to Vercel:

```bash
npm install -g vercel
vercel --prod
```

Update `MONITOR_URL` in `.env` with your deployment URL.

### 4. Test (Recommended)

Test on a forked network first:

```bash
# Terminal 1: Start fork
anvil --fork-url https://arb1.arbitrum.io/rpc --chain-id 42161

# Terminal 2: Test
npm run test:scenarios
```

### 5. Create TriggerX Job

```bash
npm start
```

Done! Your yield optimizer is now running automatically. 🎉

## 📁 Project Structure

```
yield-optimizer/
├── api/
│   └── monitor.ts          # Deployable yield monitor API
├── src/
│   ├── contracts/
│   │   ├── aave.ts         # Aave V3 integration
│   │   ├── compound.ts     # Compound V3 integration
│   │   └── arbitrum-config.ts # Arbitrum addresses
│   ├── triggerx-yield-optimizer.ts # Main TriggerX integration
│   ├── yieldMonitor.ts     # Yield comparison logic
│   ├── checkBalance.ts     # Balance checker
│   └── createSafeWallet.ts # Safe creation helper
├── scripts/
│   ├── test-fork.sh        # Fork testing automation
│   ├── test-scenarios.sh   # Comprehensive test suite
│   └── impersonate-whale.sh # Get test tokens
├── .env                    # Configuration (create from env.example)
├── package.json
└── README.md              # This file
```

## 🧪 Testing

### Quick Tests

```bash
# Check current yields
npm run check-yields

# Check balances across protocols
npm run check-balance
```

### Comprehensive Testing

```bash
# Run all test scenarios
npm run test:scenarios
```

Test scenarios include:
1. Fresh start deposit
2. Full rebalance (Aave → Compound)
3. Reverse rebalance
4. Edge cases (small/large amounts)
5. Threshold logic
6. Split positions
7. Gas cost analysis

## 💰 Economics

### Example with 10,000 USDC

**Scenario**: Compound yields 2.8%, Aave yields 2.3%

- Extra yield: 0.5% × $10,000 = **$50/year**
- Rebalancing: ~4 times/year
- Gas cost: ~$0.14/year (Arbitrum is cheap!)
- **Net benefit**: ~$49.86/year

The larger your position, the more you save!

## 🔧 Configuration

### MIN_YIELD_DIFFERENCE

Minimum APY difference to trigger rebalancing (in basis points).

- `50` (0.5%): Balanced - **Recommended**
- `100` (1.0%): Conservative - fewer rebalances
- `25` (0.25%): Aggressive - more frequent

### CHECK_INTERVAL

How often TriggerX checks your API (in seconds).

- `3600` (1 hour): Standard - **Recommended**
- `7200` (2 hours): Less frequent
- `1800` (30 min): More responsive

## 📚 Documentation

- **[TRIGGERX_SETUP.md](TRIGGERX_SETUP.md)** - Complete setup guide
- **[QUICK_FORK_GUIDE.md](QUICK_FORK_GUIDE.md)** - Fork testing guide
- **[env.fork.example](env.fork.example)** - Fork configuration example

## 🎓 How It's Built

### Technologies

- **TriggerX** - Automation platform
- **Safe** - Multi-sig wallet for secure execution
- **Ethers.js** - Ethereum interactions
- **TypeScript** - Type-safe development
- **Foundry** - Testing on forked mainnet

### Protocols

- **Aave V3** - Lending protocol
- **Compound V3** - Lending protocol
- **Arbitrum** - L2 for low gas costs

## 🔐 Security

- ✅ **Non-custodial** - Your keys, your coins
- ✅ **Safe wallet** - Multi-sig security
- ✅ **Battle-tested protocols** - Aave & Compound are audited
- ✅ **Atomic transactions** - All or nothing execution
- ✅ **Tested thoroughly** - Comprehensive test suite

## 📈 Monitoring

View your job at: `https://app.triggerx.network/jobs/YOUR_JOB_ID`

Track:
- Execution history
- Gas costs
- Total value optimized
- Success rate

## 🚨 Troubleshooting

### API not accessible

```bash
curl https://your-app.vercel.app/api/monitor
```

Should return JSON with yield data.

### Job not triggering

1. Check API is returning correct data
2. Verify yield difference > MIN_YIELD_DIFFERENCE
3. Ensure Safe has ETH for gas
4. Confirm job hasn't expired

### Need help?

Check [TRIGGERX_SETUP.md](TRIGGERX_SETUP.md) for detailed troubleshooting.

## 📦 Scripts Reference

| Command | Description |
|---------|-------------|
| `npm start` | Create TriggerX job |
| `npm run check-yields` | Check current APYs |
| `npm run check-balance` | Check balances |
| `npm run test:fork` | Run fork tests |
| `npm run test:scenarios` | Run all test scenarios |
| `npm run create-safe` | Create new Safe wallet |

## 🌟 Features Roadmap

- [ ] Support for more tokens (DAI, USDT, ETH)
- [ ] Multi-chain support (Polygon, Optimism)
- [ ] More protocols (Curve, Yearn)
- [ ] Web dashboard
- [ ] Email/Discord notifications
- [ ] Advanced strategies (leveraged yield)

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

MIT License - see LICENSE file for details

## 🙏 Acknowledgments

- [TriggerX](https://triggerx.network) - Automation platform
- [Aave](https://aave.com) - Lending protocol
- [Compound](https://compound.finance) - Lending protocol
- [Safe](https://safe.global) - Smart wallet

---

**Built with ❤️ for DeFi yield optimization**

Ready to optimize your yields? [Get started now!](#-quick-start)
