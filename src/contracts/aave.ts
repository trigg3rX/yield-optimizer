import { ethers } from 'ethers';
import * as dotenv from 'dotenv';

dotenv.config();

// Protocol addresses - configurable via environment variables
// Defaults to Sepolia, can be overridden for Arbitrum or other networks
export const AAVE_POOL_ADDRESS = process.env.AAVE_POOL_ADDRESS || '0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951';  
export const AAVE_DATA_PROVIDER_ADDRESS = process.env.AAVE_DATA_PROVIDER_ADDRESS || '0x3e9708d80f7B3e43118013075F7e95CE3AB31F31';

export const AAVE_POOL_ABI = [
  'function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode)',
  'function withdraw(address asset, uint256 amount, address to) returns (uint256)'
];

export const AAVE_DATA_PROVIDER_ABI = [
  'function getReserveData(address asset) view returns (uint256 unbacked, uint256 accruedToTreasuryScaled, uint256 totalAToken, uint256 totalStableDebt, uint256 totalVariableDebt, uint256 liquidityRate, uint256 variableBorrowRate, uint256 stableBorrowRate, uint256 averageStableBorrowRate, uint256 liquidityIndex, uint256 variableBorrowIndex, uint40 lastUpdateTimestamp)',
  'function getUserReserveData(address asset, address user) view returns (uint256 currentATokenBalance, uint256 currentStableDebt, uint256 currentVariableDebt, uint256 principalStableDebt, uint256 scaledVariableDebt, uint256 stableBorrowRate, uint256 liquidityRate, uint40 stableRateLastUpdated, bool usageAsCollateralEnabled)',
  'function getReserveTokensAddresses(address asset) view returns (address aTokenAddress, address stableDebtTokenAddress, address variableDebtTokenAddress)',
  'function getAllReservesTokens() view returns (tuple(string symbol, address tokenAddress)[])'
];

export const ERC20_ABI = [
  'function approve(address spender, uint256 amount) returns (bool)',
  'function allowance(address owner, address spender) view returns (uint256)',
  'function balanceOf(address account) view returns (uint256)',
  'function transfer(address to, uint256 amount) returns (bool)',
  'function symbol() view returns (string)',
  'function decimals() view returns (uint8)'
];

export async function getAaveAPY(provider: ethers.Provider, tokenAddress: string): Promise<number> {
  try {
    const dataProvider = new ethers.Contract(
      AAVE_DATA_PROVIDER_ADDRESS,
      AAVE_DATA_PROVIDER_ABI,
      provider
    );
    
    // First check if the reserve exists
    try {
      const reserveTokens = await dataProvider.getReserveTokensAddresses(tokenAddress);
      const aTokenAddress = Array.isArray(reserveTokens) ? reserveTokens[0] : (reserveTokens as any).aTokenAddress || reserveTokens[0];
      
      if (!aTokenAddress || aTokenAddress === ethers.ZeroAddress) {
        console.warn('WARNING: Aave reserve data unavailable on this network. Defaulting Aave APY to 0.');
        console.warn(`   Token address: ${tokenAddress} is not supported on Aave for this network.`);
        console.warn(`   Please verify: 1) Token address is correct for this network, 2) Token is listed on Aave.`);
        return 0;
      }
    } catch (error: any) {
      if (error.code === 'BAD_DATA' || error.value === '0x' || error.message?.includes('could not decode')) {
        console.warn('WARNING: Aave reserve data unavailable on this network. Defaulting Aave APY to 0.');
        console.warn(`   Token address: ${tokenAddress} is not supported on Aave for this network.`);
        console.warn(`   Possible issues:`);
        console.warn(`   1. Token address is incorrect for this network`);
        console.warn(`   2. Token is not listed on Aave for this network`);
        console.warn(`   3. Data Provider address (${AAVE_DATA_PROVIDER_ADDRESS}) is wrong for this network`);
        return 0;
      }
      // Re-throw if it's a different error
      throw error;
    }
    
    // Get reserve data for APY calculation
    let reserveData;
    try {
      reserveData = await dataProvider.getReserveData(tokenAddress);
    } catch (error: any) {
      if (error.code === 'BAD_DATA' || error.value === '0x' || error.message?.includes('could not decode')) {
        console.warn('WARNING: Aave reserve data unavailable on this network. Defaulting Aave APY to 0.');
        console.warn(`   Failed to get reserve data for token: ${tokenAddress}`);
        console.warn(`   Possible issues:`);
        console.warn(`   1. Token address is incorrect for this network`);
        console.warn(`   2. Token is not listed on Aave for this network`);
        console.warn(`   3. Data Provider address (${AAVE_DATA_PROVIDER_ADDRESS}) is wrong for this network`);
        return 0;
      }
      throw error;
    }
    
    // Handle both array and object response formats
    let liquidityRate: bigint;
    if (Array.isArray(reserveData)) {
      // The liquidityRate is at index 5 based on the ABI return tuple
      liquidityRate = reserveData[5];
    } else {
      // Try named property first, then fall back to index
      const data = reserveData as any;
      liquidityRate = data.liquidityRate || data[5];
    }
    
    // Validate liquidity rate
    if (!liquidityRate || liquidityRate === 0n) {
      console.warn('WARNING: Aave liquidity rate is 0. Defaulting Aave APY to 0.');
      return 0;
    }
    
    // Aave V3 liquidity rate is in RAY format (1e27) and is ALREADY annualized
    // We just need to convert from RAY to percentage, then to basis points
    // APY% = liquidityRate / 1e27 * 100
    // APY basis points = liquidityRate / 1e27 * 10000
    const apyBasisPoints = Math.floor(Number(liquidityRate) / 1e27 * 10000);
    
    return apyBasisPoints;
  } catch (error: any) {
    if (error.code === 'BAD_DATA' || error.value === '0x' || error.message?.includes('could not decode')) {
      console.warn('WARNING: Aave reserve data unavailable on this network. Defaulting Aave APY to 0.');
      console.warn(`   Token address: ${tokenAddress} is not supported on Aave for this network.`);
      return 0;
    }
    console.error('Error fetching Aave APY:', error.message || error);
    console.warn('WARNING: Aave reserve data unavailable on this network. Defaulting Aave APY to 0.');
    console.warn(`   Check network configuration and Aave contract addresses.`);
    return 0;
  }
}

export async function getAaveBalance(
  provider: ethers.Provider,
  tokenAddress: string,
  userAddress: string
): Promise<bigint> {
  try {
    const dataProvider = new ethers.Contract(
      AAVE_DATA_PROVIDER_ADDRESS,
      AAVE_DATA_PROVIDER_ABI,
      provider
    );

    // Try to get aToken address for this reserve
    let reserveTokens;
    try {
      reserveTokens = await dataProvider.getReserveTokensAddresses(tokenAddress);
    } catch (error: any) {
      // If the call fails with BAD_DATA or empty response, token is not supported
      if (error.code === 'BAD_DATA' || error.value === '0x' || error.message?.includes('could not decode')) {
        // Token not supported or reserve doesn't exist - return 0 silently
        // This might indicate wrong token address or network mismatch
        return 0n;
      }
      // Re-throw other errors
      throw error;
    }
    
    // Check if we got valid results
    // getReserveTokensAddresses returns a tuple: [aTokenAddress, stableDebtTokenAddress, variableDebtTokenAddress]
    if (!reserveTokens) {
      return 0n;
    }
    
    // Handle both array and object response formats
    // In ethers v6, tuple returns can be arrays or objects with named properties
    let aTokenAddress: string;
    if (Array.isArray(reserveTokens)) {
      aTokenAddress = reserveTokens[0];
    } else if (reserveTokens && typeof reserveTokens === 'object') {
      // Try named properties first (ethers v6 tuple with names), then fall back to array access
      // The ABI defines: returns (address aTokenAddress, address stableDebtTokenAddress, address variableDebtTokenAddress)
      const result = reserveTokens as any;
      aTokenAddress = result.aTokenAddress || result[0] || (result.length > 0 ? result[0] : null);
    } else {
      return 0n;
    }
    
    // Additional check: if aTokenAddress is still undefined, try to extract from the result
    if (!aTokenAddress && reserveTokens) {
      // Last resort: try to get the first property value
      const keys = Object.keys(reserveTokens);
      if (keys.length > 0) {
        aTokenAddress = (reserveTokens as any)[keys[0]];
      }
    }

    // If no aToken address, reserve doesn't exist
    if (!aTokenAddress || aTokenAddress === ethers.ZeroAddress || aTokenAddress === '0x0000000000000000000000000000000000000000') {
      return 0n;
    }

    // Get balance directly from aToken contract (more reliable than getUserReserveData)
    const aTokenContract = new ethers.Contract(
      aTokenAddress,
      ERC20_ABI,
      provider
    );

    try {
      const balance = await aTokenContract.balanceOf(userAddress);
      return balance || 0n;
    } catch (error: any) {
      // If balanceOf fails, user likely has no position
      if (error.code === 'BAD_DATA' || error.value === '0x' || error.message?.includes('could not decode')) {
        return 0n;
      }
      // Re-throw unexpected errors
      throw error;
    }
  } catch (error: any) {
    // Handle BAD_DATA errors gracefully (expected when user has no position or token not supported)
    if (error.code === 'BAD_DATA' || error.value === '0x' || error.message?.includes('could not decode')) {
      // This is expected when user has no position or token is not supported - return 0 silently
      return 0n;
    }
    // For other errors, return 0 (don't throw to prevent script failure)
    // Don't log expected errors to avoid noise
    return 0n;
  }
}
