import { ethers } from 'ethers';

/**
 * TriggerX Yield Monitor API Endpoint
 * 
 * This API endpoint monitors yield differences between Aave and Compound
 * Returns the yield difference for TriggerX to use as a condition trigger
 * 
 * Deploy this to Vercel, Railway, or any serverless platform
 */

// Protocol addresses for Arbitrum
const AAVE_DATA_PROVIDER = process.env.AAVE_DATA_PROVIDER_ADDRESS || '0x69FA688f1Dc47d4B5d8029D5a35FB7a548310654';
const COMPOUND_COMET = process.env.COMPOUND_COMET_ADDRESS || '0x9c4ec768c28520B50860ea7a15bd7213a9fF58bf';
const USDC_ADDRESS = process.env.TOKEN_ADDRESS || '0xaf88d065e77c8cC2239327C5EDb3A432268e5831';

// ABIs
const AAVE_DATA_PROVIDER_ABI = [
  'function getReserveData(address asset) view returns (uint256 unbacked, uint256 accruedToTreasuryScaled, uint256 totalAToken, uint256 totalStableDebt, uint256 totalVariableDebt, uint256 liquidityRate, uint256 variableBorrowRate, uint256 stableBorrowRate, uint256 averageStableBorrowRate, uint256 liquidityIndex, uint256 variableBorrowIndex, uint40 lastUpdateTimestamp)'
];

const COMPOUND_COMET_ABI = [
  'function getSupplyRate(uint256 utilization) view returns (uint64)',
  'function getUtilization() view returns (uint256)'
];

interface YieldData {
  value: number;  // Required by TriggerX - yield difference in basis points
  metadata: {
    aaveAPY: number;
    compoundAPY: number;
    difference: number;
    betterProtocol: string;
    timestamp: number;
    network: string;
  };
}

/**
 * Get Aave V3 APY
 */
async function getAaveAPY(provider: ethers.Provider): Promise<number> {
  try {
    const dataProvider = new ethers.Contract(
      AAVE_DATA_PROVIDER,
      AAVE_DATA_PROVIDER_ABI,
      provider
    );
    
    const reserveData = await dataProvider.getReserveData(USDC_ADDRESS);
    const liquidityRate = Array.isArray(reserveData) ? reserveData[5] : reserveData.liquidityRate;
    
    if (!liquidityRate || liquidityRate === 0n) {
      return 0;
    }
    
    // Aave V3 liquidity rate is in RAY (1e27) and already annualized
    const apyBasisPoints = Math.floor(Number(liquidityRate) / 1e27 * 10000);
    return apyBasisPoints;
  } catch (error) {
    console.error('Error fetching Aave APY:', error);
    return 0;
  }
}

/**
 * Get Compound V3 APY
 */
async function getCompoundAPY(provider: ethers.Provider): Promise<number> {
  try {
    const comet = new ethers.Contract(
      COMPOUND_COMET,
      COMPOUND_COMET_ABI,
      provider
    );
    
    const utilization = await comet.getUtilization();
    const supplyRate = await comet.getSupplyRate(utilization);
    
    // Compound V3 returns rate per second, annualize it
    const secondsPerYear = 365.25 * 24 * 60 * 60;
    const ratePerSecond = Number(supplyRate) / 1e18;
    const apy = ratePerSecond * secondsPerYear;
    const apyBasisPoints = Math.floor(apy * 10000);
    
    return apyBasisPoints;
  } catch (error) {
    console.error('Error fetching Compound APY:', error);
    return 0;
  }
}

/**
 * Main API handler
 */
export default async function handler(req: any, res: any) {
  // Set CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  
  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }
  
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }
  
  try {
    // Use provided RPC or default to Arbitrum public RPC
    const rpcUrl = process.env.RPC_URL || 'https://arb1.arbitrum.io/rpc';
    const provider = new ethers.JsonRpcProvider(rpcUrl);
    
    // Fetch APYs in parallel
    const [aaveAPY, compoundAPY] = await Promise.all([
      getAaveAPY(provider),
      getCompoundAPY(provider)
    ]);
    
    // Calculate difference (absolute value in basis points)
    const difference = Math.abs(aaveAPY - compoundAPY);
    const betterProtocol = aaveAPY > compoundAPY ? 'aave' : 'compound';
    
    const response: YieldData = {
      value: difference, // TriggerX will use this value for condition checking
      metadata: {
        aaveAPY,
        compoundAPY,
        difference,
        betterProtocol,
        timestamp: Date.now(),
        network: 'arbitrum'
      }
    };
    
    return res.status(200).json(response);
    
  } catch (error: any) {
    console.error('Error in yield monitor:', error);
    return res.status(500).json({
      error: 'Failed to fetch yield data',
      message: error.message
    });
  }
}

