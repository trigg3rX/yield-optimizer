import { ethers } from 'ethers';
import * as dotenv from 'dotenv';
import { getAaveBalance, ERC20_ABI } from './contracts/aave';
import { getCompoundBalance } from './contracts/compound';

dotenv.config();

/**
 * Script to check EOA and Safe wallet balances across all locations
 * - ETH balance (for gas fees)
 * - Token balance in wallet
 * - Token balance in Aave
 * - Token balance in Compound
 */

interface WalletBalances {
  ethBalance: bigint;
  ethBalanceFormatted: string;
  tokenInWallet: bigint;
  tokenInWalletFormatted: string;
  tokenInAave: bigint;
  tokenInAaveFormatted: string;
  tokenInCompound: bigint;
  tokenInCompoundFormatted: string;
  totalTokenBalance: bigint;
  totalTokenBalanceFormatted: string;
}

interface BalanceReport {
  eoaAddress: string;
  safeAddress: string;
  tokenAddress: string;
  tokenSymbol: string;
  eoaBalances: WalletBalances;
  safeBalances: WalletBalances;
  timestamp: number;
}

/**
 * Get token symbol from contract
 */
async function getTokenSymbol(
  provider: ethers.Provider,
  tokenAddress: string
): Promise<string> {
  try {
    const tokenContract = new ethers.Contract(
      tokenAddress,
      ['function symbol() view returns (string)'],
      provider
    );
    return await tokenContract.symbol();
  } catch (error) {
    return 'TOKEN';
  }
}

/**
 * Get token decimals from contract
 */
async function getTokenDecimals(
  provider: ethers.Provider,
  tokenAddress: string
): Promise<number> {
  try {
    const tokenContract = new ethers.Contract(
      tokenAddress,
      ['function decimals() view returns (uint8)'],
      provider
    );
    return await tokenContract.decimals();
  } catch (error) {
    // Default to 6 decimals (USDC standard)
    return 6;
  }
}

/**
 * Get balances for a specific wallet address
 */
async function getWalletBalances(
  provider: ethers.Provider,
  address: string,
  tokenAddress: string,
  tokenDecimals: number
): Promise<WalletBalances> {
  // Get ETH balance
  const ethBalance = await provider.getBalance(address);

  // Get token balance in wallet
  const tokenContract = new ethers.Contract(tokenAddress, ERC20_ABI, provider);
  const tokenInWallet = await tokenContract.balanceOf(address);

  // Get balance in Aave
  const tokenInAave = await getAaveBalance(provider, tokenAddress, address);

  // Get balance in Compound
  const tokenInCompound = await getCompoundBalance(provider, address);

  // Calculate total
  const totalTokenBalance = tokenInWallet + tokenInAave + tokenInCompound;

  return {
    ethBalance,
    ethBalanceFormatted: ethers.formatEther(ethBalance),
    tokenInWallet,
    tokenInWalletFormatted: ethers.formatUnits(tokenInWallet, tokenDecimals),
    tokenInAave,
    tokenInAaveFormatted: ethers.formatUnits(tokenInAave, tokenDecimals),
    tokenInCompound,
    tokenInCompoundFormatted: ethers.formatUnits(tokenInCompound, tokenDecimals),
    totalTokenBalance,
    totalTokenBalanceFormatted: ethers.formatUnits(totalTokenBalance, tokenDecimals)
  };
}

/**
 * Check all balances for both EOA and Safe wallet
 */
async function checkBalances(): Promise<BalanceReport> {
  // Validate environment
  if (!process.env.RPC_URL) {
    throw new Error('RPC_URL not configured in .env');
  }
  if (!process.env.PRIVATE_KEY) {
    throw new Error('PRIVATE_KEY not configured in .env');
  }
  if (!process.env.SAFE_WALLET_ADDRESS) {
    throw new Error('SAFE_WALLET_ADDRESS not configured in .env');
  }
  if (!process.env.TOKEN_ADDRESS) {
    throw new Error('TOKEN_ADDRESS not configured in .env');
  }

  const provider = new ethers.JsonRpcProvider(process.env.RPC_URL);
  const wallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);
  const eoaAddress = wallet.address;
  const safeAddress = process.env.SAFE_WALLET_ADDRESS;
  const tokenAddress = process.env.TOKEN_ADDRESS;

  console.log('Fetching balances for EOA and Safe wallet...\n');

  // Get token info
  const [tokenSymbol, tokenDecimals] = await Promise.all([
    getTokenSymbol(provider, tokenAddress),
    getTokenDecimals(provider, tokenAddress)
  ]);

  // Get balances for both wallets
  const [eoaBalances, safeBalances] = await Promise.all([
    getWalletBalances(provider, eoaAddress, tokenAddress, tokenDecimals),
    getWalletBalances(provider, safeAddress, tokenAddress, tokenDecimals)
  ]);

  return {
    eoaAddress,
    safeAddress,
    tokenAddress,
    tokenSymbol,
    eoaBalances,
    safeBalances,
    timestamp: Date.now()
  };
}

/**
 * Display balance report with nice formatting
 */
function displayReport(report: BalanceReport) {
  console.log('═══════════════════════════════════════════════════════');
  console.log('        EOA & SAFE WALLET BALANCE REPORT');
  console.log('═══════════════════════════════════════════════════════\n');

  console.log(`EOA Address:  ${report.eoaAddress}`);
  console.log(`Safe Address: ${report.safeAddress}`);
  console.log(`Token: ${report.tokenSymbol} (${report.tokenAddress})`);
  console.log(`Timestamp: ${new Date(report.timestamp).toLocaleString()}\n`);

  // EOA Balances
  console.log('═══════════════════════════════════════════════════════');
  console.log('  EOA (EXTERNALLY OWNED ACCOUNT)');
  console.log('═══════════════════════════════════════════════════════');
  
  const eoaEthValue = parseFloat(report.eoaBalances.ethBalanceFormatted);
  console.log(`  ETH Balance: ${eoaEthValue.toFixed(4)} ETH`);
  
  const eoaWallet = parseFloat(report.eoaBalances.tokenInWalletFormatted);
  const eoaAave = parseFloat(report.eoaBalances.tokenInAaveFormatted);
  const eoaCompound = parseFloat(report.eoaBalances.tokenInCompoundFormatted);
  const eoaTotal = parseFloat(report.eoaBalances.totalTokenBalanceFormatted);
  
  console.log(`  In Wallet:   ${eoaWallet.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 6 })} ${report.tokenSymbol}`);
  console.log(`  In Aave:     ${eoaAave.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 6 })} ${report.tokenSymbol}`);
  console.log(`  In Compound: ${eoaCompound.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 6 })} ${report.tokenSymbol}`);
  console.log(`  ──────────────────────────────────────────────────`);
  console.log(`  TOTAL:       ${eoaTotal.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 6 })} ${report.tokenSymbol}`);
  console.log('');

  // Safe Wallet Balances
  console.log('═══════════════════════════════════════════════════════');
  console.log('  SAFE WALLET');
  console.log('═══════════════════════════════════════════════════════');
  
  const safeEthValue = parseFloat(report.safeBalances.ethBalanceFormatted);
  console.log(`  ETH Balance: ${safeEthValue.toFixed(4)} ETH`);
  
  if (safeEthValue < 0.01) {
    console.log('  WARNING: Low ETH balance for gas fees!');
  } else if (safeEthValue < 0.05) {
    console.log('  INFO: Consider topping up ETH for gas fees');
  } else {
    console.log('  SUCCESS: Sufficient ETH for gas fees');
  }
  console.log('');

  const safeWallet = parseFloat(report.safeBalances.tokenInWalletFormatted);
  const safeAave = parseFloat(report.safeBalances.tokenInAaveFormatted);
  const safeCompound = parseFloat(report.safeBalances.tokenInCompoundFormatted);
  const safeTotal = parseFloat(report.safeBalances.totalTokenBalanceFormatted);

  console.log(`  In Wallet:   ${safeWallet.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 6 })} ${report.tokenSymbol}`);
  console.log(`  In Aave:     ${safeAave.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 6 })} ${report.tokenSymbol}`);
  console.log(`  In Compound: ${safeCompound.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 6 })} ${report.tokenSymbol}`);
  console.log(`  ──────────────────────────────────────────────────`);
  console.log(`  TOTAL:       ${safeTotal.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 6 })} ${report.tokenSymbol}`);
  console.log('');

  // Combined totals
  console.log('═══════════════════════════════════════════════════════');
  console.log('  COMBINED TOTALS (EOA + SAFE)');
  console.log('═══════════════════════════════════════════════════════');
  
  const combinedEth = eoaEthValue + safeEthValue;
  const combinedTotal = eoaTotal + safeTotal;
  
  console.log(`  Total ETH:      ${combinedEth.toFixed(4)} ETH`);
  console.log(`  Total ${report.tokenSymbol}:    ${combinedTotal.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 6 })} ${report.tokenSymbol}`);
  console.log('');

  // Show Safe wallet current position
  if (safeTotal > 0) {
    console.log('  Safe Wallet Position:');
    if (safeAave > 0 && safeCompound > 0) {
      console.log('  WARNING: Funds split between Aave and Compound');
    } else if (safeAave > 0) {
      console.log('  SUCCESS: All deposited funds in Aave');
    } else if (safeCompound > 0) {
      console.log('  SUCCESS: All deposited funds in Compound');
    } else if (safeWallet > 0) {
      console.log('  INFO: Funds in wallet (not deposited)');
      console.log('  INFO: Consider depositing to earn yield');
    }
  }
  console.log('');

  console.log('═══════════════════════════════════════════════════════\n');

  // Recommendations
  console.log('RECOMMENDATIONS:\n');
  
  if (safeEthValue < 0.01) {
    console.log('  1. URGENT: Add ETH to Safe wallet for gas fees');
  }
  
  if (eoaEthValue < 0.05) {
    console.log('  2. WARNING: Consider adding ETH to EOA for transactions');
  }
  
  if (safeWallet > safeTotal * 0.1 && safeTotal > 0) {
    console.log('  3. Consider depositing idle Safe wallet balance to earn yield');
  }
  
  if (safeAave > 0 && safeCompound > 0) {
    console.log('  4. Funds are split - may want to consolidate to one protocol');
  }
  
  if (safeTotal === 0 && eoaTotal === 0) {
    console.log('  1. Fund your wallets to start earning yield');
    console.log('  2. See README.md for funding instructions');
  }
  
  console.log('');
}

/**
 * Export balance data to JSON
 */
function exportToJSON(report: BalanceReport, filename: string = 'balance-report.json') {
  const fs = require('fs');
  const data = {
    ...report,
    eoaBalances: {
      ...report.eoaBalances,
      ethBalance: report.eoaBalances.ethBalance.toString(),
      tokenInWallet: report.eoaBalances.tokenInWallet.toString(),
      tokenInAave: report.eoaBalances.tokenInAave.toString(),
      tokenInCompound: report.eoaBalances.tokenInCompound.toString(),
      totalTokenBalance: report.eoaBalances.totalTokenBalance.toString()
    },
    safeBalances: {
      ...report.safeBalances,
      ethBalance: report.safeBalances.ethBalance.toString(),
      tokenInWallet: report.safeBalances.tokenInWallet.toString(),
      tokenInAave: report.safeBalances.tokenInAave.toString(),
      tokenInCompound: report.safeBalances.tokenInCompound.toString(),
      totalTokenBalance: report.safeBalances.totalTokenBalance.toString()
    }
  };
  
  fs.writeFileSync(filename, JSON.stringify(data, null, 2));
  console.log(`SUCCESS: Balance report exported to: ${filename}\n`);
}

/**
 * Main function
 */
async function main() {
  console.log('EOA & Safe Wallet Balance Checker\n');

  try {
    const report = await checkBalances();
    displayReport(report);

    // Optional: Export to JSON if --export flag is passed
    if (process.argv.includes('--export')) {
      exportToJSON(report);
    }

    // Optional: Show only totals if --summary flag is passed
    if (process.argv.includes('--summary')) {
      console.log('QUICK SUMMARY:');
      const totalEth = parseFloat(report.eoaBalances.ethBalanceFormatted) + parseFloat(report.safeBalances.ethBalanceFormatted);
      const totalTokens = parseFloat(report.eoaBalances.totalTokenBalanceFormatted) + parseFloat(report.safeBalances.totalTokenBalanceFormatted);
      console.log(`   Total ETH: ${totalEth.toFixed(4)} ETH`);
      console.log(`   Total ${report.tokenSymbol}: ${totalTokens.toLocaleString()} ${report.tokenSymbol}`);
      console.log('');
    }

  } catch (error: any) {
    console.error('ERROR: Error checking balances:', error.message);
    console.error('\nTroubleshooting:');
    console.error('   - Check that your .env file is configured correctly');
    console.error('   - Verify PRIVATE_KEY is set');
    console.error('   - Verify SAFE_WALLET_ADDRESS is set');
    console.error('   - Verify TOKEN_ADDRESS is set');
    console.error('   - Ensure RPC_URL is accessible');
    console.error('');
    process.exit(1);
  }
}

// Export for use in other modules
export { checkBalances, BalanceReport };

// Run if executed directly
if (require.main === module) {
  main();
}
