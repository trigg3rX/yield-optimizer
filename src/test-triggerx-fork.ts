import { ethers } from 'ethers';
import * as dotenv from 'dotenv';

dotenv.config();

/**
 * Test TriggerX Job Creation on Forked Network
 * 
 * This script creates a TriggerX job that will work on your local fork
 * Perfect for testing before deploying to mainnet
 */

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
 * Generate rebalancing transactions for testing
 */
async function generateTestRebalanceTransactions(
  provider: ethers.Provider,
  safeAddress: string,
  tokenAddress: string
): Promise<{ to: string; value: string; data: string }[]> {
  console.log('Analyzing current position on fork...\n');
  
  const yieldData = await compareYields();
  
  console.log(`Current yields:`);
  console.log(`   Aave: ${(yieldData.aaveAPY / 100).toFixed(2)}%`);
  console.log(`   Compound: ${(yieldData.compoundAPY / 100).toFixed(2)}%`);
  console.log(`   Difference: ${(yieldData.difference / 100).toFixed(2)}%`);
  console.log(`   Current position: ${yieldData.currentProtocol}`);
  console.log(`   Better protocol: ${yieldData.betterProtocol}\n`);
  
  if (!yieldData.shouldMove) {
    console.log('INFO: No rebalancing needed. Creating job that will monitor for changes.\n');
    return [];
  }
  
  const transactions: { to: string; value: string; data: string }[] = [];
  
  // Get balances
  const { getAaveBalance } = await import('./contracts/aave');
  const { getCompoundBalance } = await import('./contracts/compound');
  
  const aaveBalance = await getAaveBalance(provider, tokenAddress, safeAddress);
  const compoundBalance = await getCompoundBalance(provider, safeAddress);
  
  const amountToMove = yieldData.currentProtocol === 'aave' ? aaveBalance : compoundBalance;
  
  if (amountToMove === 0n) {
    console.log('WARNING: No funds to rebalance. Job will monitor for deposits.\n');
    return [];
  }
  
  console.log(`Amount to rebalance: ${ethers.formatUnits(amountToMove, 6)} USDC\n`);
  
  // Step 1: Withdraw from current protocol
  if (yieldData.currentProtocol === 'aave') {
    console.log('Step 1: Withdrawing from Aave...');
    const aaveInterface = new ethers.Interface(AAVE_POOL_ABI);
    transactions.push({
      to: AAVE_POOL_ADDRESS,
      value: '0',
      data: aaveInterface.encodeFunctionData('withdraw', [
        tokenAddress,
        amountToMove.toString(),
        safeAddress
      ])
    });
  } else if (yieldData.currentProtocol === 'compound') {
    console.log('Step 1: Withdrawing from Compound...');
    const compoundInterface = new ethers.Interface(COMPOUND_COMET_ABI);
    transactions.push({
      to: COMPOUND_COMET_ADDRESS,
      value: '0',
      data: compoundInterface.encodeFunctionData('withdraw', [
        tokenAddress,
        amountToMove.toString()
      ])
    });
  }
  
  // Step 2: Approve new protocol
  console.log(`Step 2: Approving ${yieldData.betterProtocol}...`);
  const tokenInterface = new ethers.Interface(ERC20_ABI);
  const approveAddress = yieldData.betterProtocol === 'aave' ? AAVE_POOL_ADDRESS : COMPOUND_COMET_ADDRESS;
  transactions.push({
    to: tokenAddress,
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
        tokenAddress,
        amountToMove.toString(),
        safeAddress,
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
        tokenAddress,
        amountToMove.toString()
      ])
    });
  }
  
  console.log(`\nSUCCESS: Generated ${transactions.length} transactions for rebalancing\n`);
  
  return transactions;
}

/**
 * Create TriggerX job for fork testing
 */
async function createForkTestJob() {
  console.log('Creating TriggerX Job for Fork Testing\n');
  console.log('═══════════════════════════════════════════════════════════\n');
  
  // Validate environment
  if (!process.env.PRIVATE_KEY) {
    throw new Error('PRIVATE_KEY not set in .env');
  }
  if (!process.env.RPC_URL) {
    throw new Error('RPC_URL not set in .env');
  }
  if (!process.env.SAFE_WALLET_ADDRESS) {
    throw new Error('SAFE_WALLET_ADDRESS not set in .env');
  }
  if (!process.env.TOKEN_ADDRESS) {
    throw new Error('TOKEN_ADDRESS not set in .env');
  }
  if (!process.env.TRIGGERX_API_KEY) {
    throw new Error('TRIGGERX_API_KEY not set in .env');
  }
  if (!process.env.MONITOR_URL) {
    throw new Error('MONITOR_URL not set in .env (should be http://localhost:3000/api/monitor for fork)');
  }
  
  const provider = new ethers.JsonRpcProvider(process.env.RPC_URL);
  const signer = new ethers.Wallet(process.env.PRIVATE_KEY, provider);
  
  // Verify we're on fork
  const network = await provider.getNetwork();
  const blockNumber = await provider.getBlockNumber();
  
  console.log('Configuration:');
  console.log(`   Network: ${network.name} (Chain ID: ${network.chainId})`);
  console.log(`   Block Number: ${blockNumber}`);
  console.log(`   RPC URL: ${process.env.RPC_URL}`);
  console.log(`   Safe Address: ${process.env.SAFE_WALLET_ADDRESS}`);
  console.log(`   Token: ${process.env.TOKEN_ADDRESS}`);
  console.log(`   Monitor API: ${process.env.MONITOR_URL}`);
  console.log(`   Min Yield Diff: ${process.env.MIN_YIELD_DIFFERENCE || '50'} bp`);
  console.log(`   Check Interval: ${process.env.CHECK_INTERVAL || '3600'}s\n`);
  
  // Check if we're on localhost (fork)
  const isFork = process.env.RPC_URL?.includes('127.0.0.1') || process.env.RPC_URL?.includes('localhost');
  
  if (isFork) {
    console.log('SUCCESS: Detected fork network - perfect for testing!\n');
  } else {
    console.log('WARNING: Not on fork network!');
    console.log('   For testing, use: RPC_URL=http://127.0.0.1:8545\n');
  }
  
  // Initialize TriggerX client
  const client = new TriggerXClient(process.env.TRIGGERX_API_KEY);
  
  // Generate rebalancing transactions
  const rebalanceTransactions = await generateTestRebalanceTransactions(
    provider,
    process.env.SAFE_WALLET_ADDRESS,
    process.env.TOKEN_ADDRESS
  );
  
  // Create condition-based job
  const jobInput = {
    jobType: JobType.Condition,
    conditionType: 'greater_than',
    upperLimit: parseInt(process.env.MIN_YIELD_DIFFERENCE || '50'),
    argType: ArgType.Static,
    
    jobTitle: 'Yield Optimizer (Fork Test) - Aave ↔ Compound',
    timeFrame: parseInt(process.env.JOB_DURATION || '86400'), // 1 day for testing
    
    // Value source: your local API
    valueSourceType: 'api',
    valueSourceUrl: process.env.MONITOR_URL,
    
    chainId: process.env.CHAIN_ID || '42161',
    
    // Safe wallet mode
    walletMode: 'safe',
    safeAddress: process.env.SAFE_WALLET_ADDRESS,
    safeTransactions: rebalanceTransactions.length > 0 ? rebalanceTransactions : undefined,
    
    autotopupTG: true,
  };
  
  console.log('Submitting job to TriggerX...\n');
  
  try {
    const result = await createJob(client, { jobInput, signer });
    
    console.log('═══════════════════════════════════════════════════════════\n');
    console.log('SUCCESS: TriggerX Job Created Successfully!\n');
    console.log(`Job ID: ${result.jobId}`);
    console.log(`View on TriggerX: https://app.triggerx.network/jobs/${result.jobId}\n`);
    console.log('The job will:');
    console.log('   1. Monitor yield differences via your local API');
    console.log(`   2. Trigger when difference > ${(parseInt(process.env.MIN_YIELD_DIFFERENCE || '50') / 100).toFixed(2)}%`);
    console.log('   3. Automatically rebalance funds to higher-yielding protocol');
    console.log('   4. Execute safely through your Safe wallet\n');
    console.log('🧪 Testing Tips:');
    console.log('   - Monitor the job in TriggerX dashboard');
    console.log('   - Check balances: npm run check-balance');
    console.log('   - Check yields: npm run check-yields');
    console.log('   - The job will execute when conditions are met\n');
    console.log('═══════════════════════════════════════════════════════════\n');
    
    return result.jobId;
  } catch (error: any) {
    console.error('ERROR: Error creating job:', error.message);
    if (error.response) {
      console.error('   Response:', JSON.stringify(error.response.data, null, 2));
    }
    throw error;
  }
}

// Run if executed directly
if (require.main === module) {
  createForkTestJob().catch(console.error);
}

export { createForkTestJob };

