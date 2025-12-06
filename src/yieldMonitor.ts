import { ethers } from 'ethers';
import * as dotenv from 'dotenv';
import { getAaveAPY, getAaveBalance } from './contracts/aave';
import { getCompoundAPY, getCompoundBalance } from './contracts/compound';

dotenv.config();

interface YieldComparison {
  timestamp: number;
  aaveAPY: number;
  compoundAPY: number;
  difference: number;
  betterProtocol: 'aave' | 'compound' | 'equal';
  shouldMove: boolean;
  currentProtocol: 'aave' | 'compound' | 'none';
}

async function compareYields(): Promise<YieldComparison> {
  if (!process.env.RPC_URL || !process.env.TOKEN_ADDRESS || !process.env.SAFE_WALLET_ADDRESS) {
    throw new Error('Missing required environment variables');
  }

  const provider = new ethers.JsonRpcProvider(process.env.RPC_URL);
  const tokenAddress = process.env.TOKEN_ADDRESS;
  const safeAddress = process.env.SAFE_WALLET_ADDRESS;
  const minYieldDifference = parseInt(process.env.MIN_YIELD_DIFFERENCE || '50');

  console.log(' Fetching yield data...\n');

  // Check Safe wallet position (not EOA)
  const [aaveAPY, compoundAPY, aaveBalance, compoundBalance] = await Promise.all([
    getAaveAPY(provider, tokenAddress),
    getCompoundAPY(provider),
    getAaveBalance(provider, tokenAddress, safeAddress),
    getCompoundBalance(provider, safeAddress)
  ]);

  console.log(` Aave APY: ${(aaveAPY / 100).toFixed(2)}%`);
  console.log(` Compound APY: ${(compoundAPY / 100).toFixed(2)}%`);

  let currentProtocol: 'aave' | 'compound' | 'none' = 'none';
  if (aaveBalance > 0n) {
    currentProtocol = 'aave';
    console.log(` Current position: Aave (${ethers.formatUnits(aaveBalance, 6)} tokens)`);
  } else if (compoundBalance > 0n) {
    currentProtocol = 'compound';
    console.log(` Current position: Compound (${ethers.formatUnits(compoundBalance, 6)} tokens)`);
  } else {
    console.log(` Current position: No funds deposited`);
  }

  const difference = Math.abs(aaveAPY - compoundAPY);
  let betterProtocol: 'aave' | 'compound' | 'equal';

  if (aaveAPY > compoundAPY) betterProtocol = 'aave';
  else if (compoundAPY > aaveAPY) betterProtocol = 'compound';
  else betterProtocol = 'equal';

  const shouldMove = 
    difference >= minYieldDifference && 
    betterProtocol !== 'equal' && 
    currentProtocol !== 'none' &&
    currentProtocol !== betterProtocol;

  console.log(`\n Difference: ${(difference / 100).toFixed(2)}%`);
  console.log(` Better protocol: ${betterProtocol}`);
  console.log(` Should move funds: ${shouldMove ? 'YES' : 'NO'}\n`);

  return {
    timestamp: Date.now(),
    aaveAPY,
    compoundAPY,
    difference,
    betterProtocol,
    shouldMove,
    currentProtocol
  };
}

async function main() {
  console.log(' Yield Optimizer Monitor\n');
  try {
    const result = await compareYields();
    console.log('\nFull Result:');
    console.log(JSON.stringify(result, null, 2));
  } catch (error: any) {
    console.error(' Error:', error.message);
    process.exit(1);
  }
}

export { compareYields, YieldComparison };

if (require.main === module) {
  main();
}
