import { ethers } from 'ethers';
import { createSafeWallet } from 'sdk-triggerx';
import * as dotenv from 'dotenv';

dotenv.config();

async function main() {
  console.log(' Creating Safe Wallet for Yield Optimizer...\n');

  if (!process.env.PRIVATE_KEY || !process.env.RPC_URL) {
    console.error(' Error: PRIVATE_KEY or RPC_URL not found in .env file');
    process.exit(1);
  }

  try {
    const provider = new ethers.JsonRpcProvider(process.env.RPC_URL);
    const signer = new ethers.Wallet(process.env.PRIVATE_KEY, provider);
    
    // Check if using a forked network
    const isFork = process.env.RPC_URL?.includes('localhost') || process.env.RPC_URL?.includes('127.0.0.1');
    const network = await provider.getNetwork();
    
    console.log(` Network: ${network.name} (Chain ID: ${network.chainId})`);
    console.log(` RPC URL: ${process.env.RPC_URL}`);
    
    if (isFork) {
      console.log('\nNOTE: Using forked network (localhost)');
      console.log('   - Safe wallet will only exist on this local fork');
      console.log('   - Perfect for local testing and development');
      console.log('   - WARNING: This Safe wallet will NOT work with TriggerX');
      console.log('   - TriggerX requires Safe wallets on real networks (mainnet/testnet)\n');
    } else {
      console.log('\nNOTE: Using real network');
      console.log('   - Safe wallet will be deployed on the real blockchain');
      console.log('   - This Safe wallet CAN be used with TriggerX\n');
    }
    
    console.log(` Using address: ${signer.address}`);
    const balance = await provider.getBalance(signer.address);
    console.log(` Wallet balance: ${ethers.formatEther(balance)} ETH`);
    
    if (parseFloat(ethers.formatEther(balance)) < 0.01) {
      console.log(' WARNING: Low ETH balance. You may need more ETH for gas fees.\n');
    } else {
      console.log('');
    }

    console.log(' Creating Safe wallet...');
    console.log(' (This may take a moment...)\n');
    
    const safeAddress = await createSafeWallet(signer);

    console.log(' SUCCESS: Safe wallet created successfully!\n');
    console.log(` Safe Address: ${safeAddress}\n`);
    console.log(' Add this to your .env file:');
    console.log(`   SAFE_WALLET_ADDRESS=${safeAddress}\n`);
    
    if (isFork) {
      console.log(' IMPORTANT NOTES for Fork Testing:');
      console.log('   - This Safe wallet only exists on your local fork');
      console.log('   - You can test locally with this Safe wallet');
      console.log('   - To use TriggerX, create a Safe on a real network (Arbitrum mainnet/testnet)');
      console.log('   - Update your RPC_URL to a real Arbitrum endpoint before creating TriggerX jobs\n');
    } else {
      console.log(' Next steps:');
      console.log('   1. Fund your Safe wallet with ETH (for gas fees)');
      console.log('   2. Fund your Safe wallet with tokens (e.g., USDC)');
      console.log('   3. This Safe wallet can be used with TriggerX\n');
    }

  } catch (error: any) {
    console.error(' Error creating Safe wallet:', error.message);
    process.exit(1);
  }
}

main();
