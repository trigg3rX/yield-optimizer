import { ethers } from 'ethers';
import * as dotenv from 'dotenv';

dotenv.config();

// Import TriggerX SDK
let TriggerXClient: any;
let createJob: any;
let JobType: any;
let ArgType: any;

try {
  const triggerxSDK = require('sdk-triggerx');
  TriggerXClient = triggerxSDK.TriggerXClient;
  createJob = triggerxSDK.createJob;
  JobType = triggerxSDK.JobType;
  ArgType = triggerxSDK.ArgType;
} catch (error: any) {
  if (error.code === 'MODULE_NOT_FOUND') {
    console.error('\nERROR: TriggerX SDK not installed!\n');
    console.error('Install it with:');
    console.error('  npm install sdk-triggerx\n');
    process.exit(1);
  }
  throw error;
}

import { compareYields } from './yieldMonitor';
import { ERC20_ABI, AAVE_POOL_ADDRESS, AAVE_POOL_ABI } from './contracts/aave';
import { COMPOUND_COMET_ADDRESS, COMPOUND_COMET_ABI } from './contracts/compound';

/**
 * TriggerX Yield Optimizer
 * Automatically rebalances funds between Aave and Compound based on APY differences
 * 
 * This creates a TriggerX job that:
 * 1. Monitors yield differences via your deployed API
 * 2. Executes rebalancing when difference > threshold
 * 3. Uses Safe wallet for secure transaction execution
 */

interface YieldOptimizerConfig {
  safeAddress: string;
  tokenAddress: string;
  minYieldDifference: number; // basis points (e.g., 50 = 0.5%)
  checkInterval: number; // seconds (e.g., 60 = 1 minute)
  jobDuration: number; // seconds (e.g., 300 = 5 minutes)
  monitorApiUrl: string; // Your deployed yield monitor API
}

/**
 * Generate a minimal placeholder transaction for job creation
 * This is used when there are no funds to rebalance initially
 */
function generatePlaceholderTransaction(
  safeAddress: string
): { to: string; value: string; data: string }[] {
  // Create a minimal valid transaction that satisfies the API requirement
  // This is a no-op transaction that calls the Safe wallet's nonce() function
  // which is a view function and won't actually execute anything
  // When the condition triggers and there are funds, the job will need to be updated
  // or use dynamic transactions
  const SAFE_ABI = [
    "function nonce() view returns (uint256)"
  ];
  const iface = new ethers.Interface(SAFE_ABI);
  const data = iface.encodeFunctionData('nonce', []);
  
  return [{
    to: safeAddress, // Call the Safe wallet itself
    value: '0',
    data: data // Call nonce() - a view function that does nothing
  }];
}

/**
 * Generate rebalancing transactions based on current state
 */
async function generateRebalanceTransactions(
  provider: ethers.Provider,
  config: YieldOptimizerConfig
): Promise<{ to: string; value: string; data: string }[]> {
  console.log('Analyzing current position...\n');
  
  const yieldData = await compareYields();
  
  if (!yieldData.shouldMove) {
    console.log('INFO: No rebalancing needed at this time.');
    return [];
  }
  
  console.log(`Current position: ${yieldData.currentProtocol}`);
  console.log(`Better protocol: ${yieldData.betterProtocol}`);
  console.log(`Yield difference: ${(yieldData.difference / 100).toFixed(2)}%\n`);
  
  const transactions: { to: string; value: string; data: string }[] = [];
  
  // Get balances - we'll move ALL funds from the current protocol
  const { getAaveBalance } = await import('./contracts/aave');
  const { getCompoundBalance } = await import('./contracts/compound');
  
  const aaveBalance = await getAaveBalance(provider, config.tokenAddress, config.safeAddress);
  const compoundBalance = await getCompoundBalance(provider, config.safeAddress);
  
  // Get ALL funds from the current protocol (this is what we'll move)
  const amountToMove = yieldData.currentProtocol === 'aave' ? aaveBalance : compoundBalance;
  
  if (amountToMove === 0n) {
    console.log('WARNING: No funds to rebalance');
    return [];
  }
  
  console.log(`Amount to rebalance: ${ethers.formatUnits(amountToMove, 6)} USDC (ALL funds from ${yieldData.currentProtocol})\n`);
  
  // Step 1: Withdraw from current protocol
  if (yieldData.currentProtocol === 'aave') {
    console.log('Step 1: Withdrawing from Aave...');
    const aaveInterface = new ethers.Interface(AAVE_POOL_ABI);
    transactions.push({
      to: AAVE_POOL_ADDRESS,
      value: '0',
      data: aaveInterface.encodeFunctionData('withdraw', [
        config.tokenAddress,
        amountToMove.toString(),
        config.safeAddress
      ])
    });
  } else if (yieldData.currentProtocol === 'compound') {
    console.log('Step 1: Withdrawing from Compound...');
    const compoundInterface = new ethers.Interface(COMPOUND_COMET_ABI);
    transactions.push({
      to: COMPOUND_COMET_ADDRESS,
      value: '0',
      data: compoundInterface.encodeFunctionData('withdraw', [
        config.tokenAddress,
        amountToMove.toString()
      ])
    });
  }
  
  // Step 2: Approve new protocol
  console.log(`Step 2: Approving ${yieldData.betterProtocol}...`);
  const tokenInterface = new ethers.Interface(ERC20_ABI);
  const approveAddress = yieldData.betterProtocol === 'aave' ? AAVE_POOL_ADDRESS : COMPOUND_COMET_ADDRESS;
  transactions.push({
    to: config.tokenAddress,
    value: '0',
    data: tokenInterface.encodeFunctionData('approve', [
      approveAddress,
      amountToMove.toString()
    ])
  });
  
  // Step 3: Deposit to better protocol
  if (yieldData.betterProtocol === 'aave') {
    console.log('Step 3: Depositing to Aave...');
    const aaveInterface = new ethers.Interface(AAVE_POOL_ABI);
    transactions.push({
      to: AAVE_POOL_ADDRESS,
      value: '0',
      data: aaveInterface.encodeFunctionData('supply', [
        config.tokenAddress,
        amountToMove.toString(),
        config.safeAddress,
        '0'
      ])
    });
  } else if (yieldData.betterProtocol === 'compound') {
    console.log('Step 3: Depositing to Compound...');
    const compoundInterface = new ethers.Interface(COMPOUND_COMET_ABI);
    transactions.push({
      to: COMPOUND_COMET_ADDRESS,
      value: '0',
      data: compoundInterface.encodeFunctionData('supply', [
        config.tokenAddress,
        amountToMove.toString()
      ])
    });
  }
  
  console.log(`\nSUCCESS: Generated ${transactions.length} transactions for rebalancing\n`);
  
  return transactions;
}

/**
 * Create a TriggerX job for automated yield optimization
 */
export async function createYieldOptimizerJob(
  config: YieldOptimizerConfig
): Promise<string> {
  console.log('Creating TriggerX Yield Optimizer Job\n');
  console.log('═══════════════════════════════════════════════════════════\n');
  
  // Validate environment
  if (!process.env.PRIVATE_KEY) {
    throw new Error('PRIVATE_KEY not set in .env');
  }
  if (!process.env.RPC_URL) {
    throw new Error('RPC_URL not set in .env');
  }
  
  const provider = new ethers.JsonRpcProvider(process.env.RPC_URL);
  const signer = new ethers.Wallet(process.env.PRIVATE_KEY, provider);
  
  // Check if using localhost fork - TriggerX requires real network
  const isLocalFork = process.env.RPC_URL?.includes('localhost') || process.env.RPC_URL?.includes('127.0.0.1');
  if (isLocalFork) {
    console.log('\nWARNING: You are using a local fork!');
    console.log('   TriggerX is a real service that requires the actual blockchain network.');
    console.log('   For job creation to work, you need:');
    console.log('   1. A real RPC URL (not localhost) pointing to Arbitrum mainnet/testnet');
    console.log('   2. ETH in your wallet on the real network (not just the fork)');
    console.log('   3. Your Safe wallet deployed on the real network\n');
  }
  
  console.log('Configuration:');
  console.log(`   Safe Address: ${config.safeAddress}`);
  console.log(`   Token: ${config.tokenAddress}`);
  console.log(`   Min Yield Diff: ${config.minYieldDifference} bp (${(config.minYieldDifference / 100).toFixed(2)}%)`);
  console.log(`   Check Interval: ${config.checkInterval}s (${Math.floor(config.checkInterval / 3600)}h)`);
  console.log(`   Job Duration: ${config.jobDuration}s (${Math.floor(config.jobDuration / 86400)}d)`);
  console.log(`   Monitor API: ${config.monitorApiUrl}`);
  
  // Warn if monitor API is localhost (TriggerX servers cannot access it)
  if (config.monitorApiUrl.includes('localhost') || config.monitorApiUrl.includes('127.0.0.1')) {
    console.log('\nWARNING: Monitor API URL is localhost!');
    console.log('   TriggerX servers cannot access localhost URLs.');
    console.log('   The job will be created but may fail to monitor yields.');
    console.log('   For production, use a publicly accessible URL (e.g., deployed API, ngrok, etc.)\n');
  }
  
  console.log('');
  
  // Initialize TriggerX client
  const client = new TriggerXClient(process.env.TRIGGERX_API_KEY);
  
  // Generate initial rebalancing transactions (static for now)
  const rebalanceTransactions = await generateRebalanceTransactions(provider, config);
  
  // Determine if we should use static or dynamic transactions
  const hasTransactions = rebalanceTransactions.length > 0;
  const dynamicScriptUrl = process.env.DYNAMIC_TRANSACTIONS_SCRIPT_URL;
  
  if (!hasTransactions && !dynamicScriptUrl) {
    console.log('INFO: No rebalancing needed currently. Job will monitor for changes.');
    console.log('WARNING: Note: For condition-based jobs, consider providing DYNAMIC_TRANSACTIONS_SCRIPT_URL');
    console.log('   to generate transactions dynamically when the condition is met.');
  }
  
  // Create condition-based job that monitors your API
  // Check wallet balance for autotopup decision
  const walletBalance = await provider.getBalance(await signer.getAddress());
  const walletBalanceEth = parseFloat(ethers.formatEther(walletBalance));
  const shouldAutotopup = process.env.AUTOTOPUP_TG !== 'false' && walletBalanceEth >= 0.01;
  
  console.log(`   Wallet ETH Balance: ${walletBalanceEth.toFixed(6)} ETH`);
  if (walletBalanceEth < 0.01) {
    console.log('   WARNING: Low ETH balance - autotopupTG will be disabled');
    console.log('   You need ETH to purchase TG tokens. Recommended: At least 0.1 ETH\n');
  } else {
    console.log('');
  }
  
  const jobInput: any = {
    jobType: JobType.Condition,
    conditionType: 'greater_than',
    upperLimit: config.minYieldDifference, // Trigger when difference > this
    lowerLimit: 0, // Required for condition-based jobs
    argType: hasTransactions && !dynamicScriptUrl ? ArgType.Static : ArgType.Dynamic,
    
    jobTitle: 'Yield Optimizer - Aave ↔ Compound',
    timeFrame: config.jobDuration,
    
    // Value source: your deployed yield monitor API
    // NOTE: This must be publicly accessible (not localhost) for TriggerX servers to access it
    valueSourceType: 'api',
    valueSourceUrl: config.monitorApiUrl, // Must be publicly accessible URL
    
    // Timezone is required (IANA timezone string)
    timezone: process.env.TIMEZONE || 'UTC',
    
    chainId: process.env.CHAIN_ID || '42161',
    
    // Safe wallet mode
    walletMode: 'safe',
    safeAddress: config.safeAddress,
    
    // Enable autotopupTG to automatically purchase TG tokens
    // Note: This requires ETH in your wallet to purchase TG tokens
    // Disable if you don't have ETH or want to manually top up TG balance
    autotopupTG: shouldAutotopup, // Only enable if sufficient ETH
  };
  
  // For static jobs, provide transactions. For dynamic jobs, provide script URL
  if (hasTransactions && !dynamicScriptUrl) {
    // Use static transactions
    jobInput.safeTransactions = rebalanceTransactions;
    jobInput.argType = ArgType.Static;
    console.log(`Using static transactions (${rebalanceTransactions.length} transaction(s))`);
  } else if (dynamicScriptUrl && dynamicScriptUrl.startsWith('http')) {
    // Use dynamic script URL (only if it's a publicly accessible URL, not localhost)
    const isPublicUrl = !dynamicScriptUrl.includes('localhost') && !dynamicScriptUrl.includes('127.0.0.1');
    if (isPublicUrl) {
      jobInput.dynamicArgumentsScriptUrl = dynamicScriptUrl;
      jobInput.argType = ArgType.Dynamic;
      console.log(`Using dynamic transactions script: ${dynamicScriptUrl}`);
    } else {
      console.log('WARNING: Dynamic script URL is localhost - TriggerX servers cannot access it.');
      console.log('   Falling back to placeholder transaction. Use a publicly accessible URL for dynamic mode.');
      // Fall through to placeholder transaction
      const placeholderTx = generatePlaceholderTransaction(config.safeAddress);
      jobInput.safeTransactions = placeholderTx;
      jobInput.argType = ArgType.Static;
      console.log('Using placeholder transaction (job will need to be updated when condition triggers)');
    }
  } else {
    // No transactions and no valid dynamic script URL
    // Create a placeholder transaction so the job can be created
    // Note: This is a no-op transaction. When the condition triggers and there are funds,
    // the job will need to be updated with actual transactions or use dynamic mode
    console.log('WARNING: No initial transactions found.');
    console.log('   Creating job with placeholder transaction.');
    console.log('   When the condition triggers and funds are available, update the job with actual transactions.');
    console.log('   Or set DYNAMIC_TRANSACTIONS_SCRIPT_URL to a publicly accessible URL for dynamic mode.');
    
    const placeholderTx = generatePlaceholderTransaction(config.safeAddress);
    jobInput.safeTransactions = placeholderTx;
    jobInput.argType = ArgType.Static;
    console.log('Using placeholder transaction (no-op)');
  }
  
  console.log('Submitting job to TriggerX...\n');
  
  try {
    const result = await createJob(client, { jobInput, signer });
    
    // Debug: Log full response to understand structure
    console.log('\nFull API Response:');
    console.log(JSON.stringify(result, null, 2));
    console.log('');
    
    // Try different possible response structures
    const jobId = result?.jobId || result?.id || result?.data?.jobId || result?.data?.id || result?.job?.id;
    
    console.log('═══════════════════════════════════════════════════════════\n');
    if (jobId) {
      console.log('SUCCESS: Yield Optimizer Job Created Successfully!\n');
      console.log(`Job ID: ${jobId}`);
      console.log(`View on TriggerX: https://app.triggerx.network/jobs/${jobId}\n`);
    } else {
      console.log('WARNING: Job creation response received, but Job ID not found in expected format\n');
      console.log('Response structure:');
      console.log(JSON.stringify(result, null, 2));
      console.log('\nPlease check your TriggerX dashboard manually: https://app.triggerx.network\n');
    }
    console.log('The job will:');
    console.log('   1. Monitor yield differences via your API');
    console.log(`   2. Trigger when difference > ${(config.minYieldDifference / 100).toFixed(2)}%`);
    console.log('   3. Automatically rebalance funds to higher-yielding protocol');
    console.log('   4. Execute safely through your Safe wallet\n');
    console.log('═══════════════════════════════════════════════════════════\n');
    
    return result.jobId;
  } catch (error: any) {
    console.error('ERROR: Error creating job:', error.message);
    throw error;
  }
}

/**
 * Main function
 */
async function main() {
  console.log('\nTriggerX Yield Optimizer Setup\n');
  
  // Validate required environment variables
  const required = [
    'PRIVATE_KEY',
    'RPC_URL',
    'SAFE_WALLET_ADDRESS',
    'TOKEN_ADDRESS',
    'TRIGGERX_API_KEY',
    'MONITOR_URL'
  ];
  
  const missing = required.filter(key => !process.env[key]);
  if (missing.length > 0) {
    console.error('ERROR: Missing required environment variables:');
    missing.forEach(key => console.error(`   - ${key}`));
    console.error('\nPlease check your .env file.\n');
    process.exit(1);
  }
  
  const config: YieldOptimizerConfig = {
    safeAddress: process.env.SAFE_WALLET_ADDRESS!,
    tokenAddress: process.env.TOKEN_ADDRESS!,
    minYieldDifference: parseInt(process.env.MIN_YIELD_DIFFERENCE || '50'),
    checkInterval: parseInt(process.env.CHECK_INTERVAL || '60'), // 1 hour
    jobDuration: parseInt(process.env.JOB_DURATION || '300'), // 30 days
    monitorApiUrl: process.env.MONITOR_URL!,
  };
  
  await createYieldOptimizerJob(config);
}

// Run if executed directly
if (require.main === module) {
  main().catch(console.error);
}

export { YieldOptimizerConfig, generateRebalanceTransactions };

