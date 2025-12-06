import { ethers } from 'ethers';
import * as dotenv from 'dotenv';

dotenv.config();

/**
 * Compound V3 contract addresses and ABIs
 * Configurable via environment variables for different networks
 */

// Compound V3 USDC Comet address - defaults to Sepolia, can be overridden for Arbitrum
export const COMPOUND_COMET_ADDRESS = process.env.COMPOUND_COMET_ADDRESS || '0xAec1F48e02Cfb822Be958B68C7957156EB3F0b6e';

// Minimal ABI for Compound V3 Comet
export const COMPOUND_COMET_ABI = [
  'function supply(address asset, uint256 amount)',
  'function withdraw(address asset, uint256 amount)',
  'function balanceOf(address account) view returns (uint256)',
  'function getSupplyRate(uint256 utilization) view returns (uint64)',
  'function getUtilization() view returns (uint256)',
  'function totalSupply() view returns (uint256)',
  'function totalBorrow() view returns (uint256)',
  'function baseToken() view returns (address)',
  'function userBasic(address) view returns (int104 principal, uint64 baseTrackingIndex, uint64 baseTrackingAccrued, uint256 assetsIn, uint256 _reserved)'
];

// ERC20 ABI for token operations
export const ERC20_ABI = [
  'function approve(address spender, uint256 amount) returns (bool)',
  'function allowance(address owner, address spender) view returns (uint256)',
  'function balanceOf(address account) view returns (uint256)'
];

/**
 * Get current APY for Compound V3
 * @param provider Ethers provider
 * @returns APY in basis points (e.g., 500 = 5%)
 */
export async function getCompoundAPY(provider: ethers.Provider): Promise<number> {
  try {
    // First verify the contract exists
    const code = await provider.getCode(COMPOUND_COMET_ADDRESS);
    if (code === '0x') {
      console.warn(`WARNING: Compound contract not deployed at ${COMPOUND_COMET_ADDRESS}`);
      return 0;
    }

    const comet = new ethers.Contract(
      COMPOUND_COMET_ADDRESS,
      COMPOUND_COMET_ABI,
      provider
    );

    // Get current utilization
    let utilization: bigint;
    try {
      utilization = await comet.getUtilization();
    } catch (error: any) {
      console.warn(`WARNING: Could not get Compound utilization: ${error.message}`);
      return 0;
    }
    
    // Get supply rate for current utilization
    const supplyRate = await comet.getSupplyRate(utilization);

    // Convert supply rate to APY in basis points
    // Compound V3 returns rate per second, need to annualize
    // APY = (1 + ratePerSecond) ^ secondsPerYear - 1
    // Simplified approximation: APY ≈ ratePerSecond * secondsPerYear
    const secondsPerYear = 365.25 * 24 * 60 * 60;
    const ratePerSecond = Number(supplyRate) / 1e18;
    const apy = ratePerSecond * secondsPerYear;
    const apyBasisPoints = Math.floor(apy * 10000);

    return apyBasisPoints;
  } catch (error: any) {
    console.warn(`WARNING: Error fetching Compound APY: ${error.message || error}`);
    return 0;
  }
}

/**
 * Get user's supplied balance on Compound
 * @param provider Ethers provider
 * @param userAddress User's address
 * @returns Balance in base token's smallest unit
 */
export async function getCompoundBalance(
  provider: ethers.Provider,
  userAddress: string
): Promise<bigint> {
  try {
    const comet = new ethers.Contract(
      COMPOUND_COMET_ADDRESS,
      COMPOUND_COMET_ABI,
      provider
    );

    const balance = await comet.balanceOf(userAddress);
    return balance;
  } catch (error) {
    console.error('Error fetching Compound balance:', error);
    return 0n;
  }
}

/**
 * Encode supply transaction for Compound V3
 * @param tokenAddress Token to supply (for USDC Comet, this is USDC address)
 * @param amount Amount to supply
 * @returns Encoded transaction data
 */
export function encodeCompoundSupply(
  tokenAddress: string,
  amount: string
): string {
  const cometInterface = new ethers.Interface(COMPOUND_COMET_ABI);
  return cometInterface.encodeFunctionData('supply', [tokenAddress, amount]);
}

/**
 * Encode withdraw transaction for Compound V3
 * @param tokenAddress Token to withdraw
 * @param amount Amount to withdraw
 * @returns Encoded transaction data
 */
export function encodeCompoundWithdraw(
  tokenAddress: string,
  amount: string
): string {
  const cometInterface = new ethers.Interface(COMPOUND_COMET_ABI);
  return cometInterface.encodeFunctionData('withdraw', [tokenAddress, amount]);
}

/**
 * Encode ERC20 approve transaction
 * @param spender Address to approve
 * @param amount Amount to approve
 * @returns Encoded transaction data
 */
export function encodeApproval(spender: string, amount: string): string {
  const erc20Interface = new ethers.Interface(ERC20_ABI);
  return erc20Interface.encodeFunctionData('approve', [spender, amount]);
}
