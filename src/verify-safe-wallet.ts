import { ethers } from 'ethers';
import * as dotenv from 'dotenv';

dotenv.config();

const SAFE_ABI = [
    "function getOwners() view returns (address[])",
    "function getThreshold() view returns (uint256)",
    "function isModuleEnabled(address module) view returns (bool)"
];

async function checkSafe() {
    const safeAddress = process.env.SAFE_WALLET_ADDRESS;
    const rpcUrl = process.env.RPC_URL;
    const chainId = process.env.CHAIN_ID || '42161';
    
    if (!safeAddress) {
        console.error('ERROR: SAFE_WALLET_ADDRESS not set in .env');
        process.exit(1);
    }
    
    if (!rpcUrl) {
        console.error('ERROR: RPC_URL not set in .env');
        process.exit(1);
    }
    
    console.log(`\nConnecting to RPC: ${rpcUrl}`);
    const provider = new ethers.JsonRpcProvider(rpcUrl);
    
    // Get network info
    try {
        const network = await provider.getNetwork();
        console.log(`Network: ${network.name} (Chain ID: ${network.chainId})`);
        console.log(`   Expected Chain ID: ${chainId}`);
        
        if (network.chainId.toString() !== chainId) {
            console.log(`\nWARNING: Network mismatch!`);
            console.log(`   RPC is on chain ${network.chainId}, but CHAIN_ID is set to ${chainId}`);
            console.log(`\nThis is likely the cause of your error!`);
            console.log(`   Update CHAIN_ID in .env to match the network: ${network.chainId}`);
        }
    } catch (error: any) {
        console.log(`\nWARNING: Could not detect network from RPC: ${error.message}`);
    }
    
    // Check if address is a contract
    console.log(`\nChecking if address is a contract...`);
    const code = await provider.getCode(safeAddress);
    
    if (code === '0x') {
        console.log(`ERROR: Address ${safeAddress} is NOT a contract (it's an EOA)`);
        console.log(`   This address cannot be used as a Safe wallet.`);
        
        // Check if using localhost
        const isLocalhost = rpcUrl.includes('localhost') || rpcUrl.includes('127.0.0.1');
        if (isLocalhost) {
            console.log(`\nNOTE: You're using a local fork (localhost RPC).`);
            console.log(`   The Safe wallet will only exist on your local fork.`);
            console.log(`   For TriggerX to work, you need a Safe wallet on the real Arbitrum network.`);
        }
        
        console.log(`\nSolution: Create a Safe wallet using:`);
        console.log(`   npm run create-safe`);
        console.log(`\n   Important: For TriggerX job creation, ensure:`);
        console.log(`   1. Use a real Arbitrum RPC URL (not localhost)`);
        console.log(`   2. Create the Safe wallet on the real network`);
        console.log(`   3. Fund it with ETH on that network`);
        process.exit(1);
    } else {
        console.log(`SUCCESS: Address is a contract`);
    }
    
    // Try to call getOwners
    console.log(`\nAttempting to call getOwners() on Safe wallet...`);
    try {
        const safe = new ethers.Contract(safeAddress, SAFE_ABI, provider);
        const owners = await safe.getOwners();
        const threshold = await safe.getThreshold();
        
        console.log(`SUCCESS: Safe wallet is valid!`);
        console.log(`   Owners: ${owners.length}`);
        owners.forEach((owner: string, i: number) => {
            console.log(`     ${i + 1}. ${owner}`);
        });
        console.log(`   Threshold: ${threshold}`);
        
        // Check if it's a single-owner Safe
        if (owners.length === 1 && threshold.toString() === '1') {
            console.log(`\nSUCCESS: Safe wallet is properly configured (single owner)`);
        } else {
            console.log(`\nWARNING: Safe wallet must have exactly 1 owner with threshold 1`);
            console.log(`   Current: ${owners.length} owner(s), threshold ${threshold}`);
        }
        
    } catch (error: any) {
        console.log(`\nERROR: Error calling getOwners():`);
        console.log(`   ${error.message}`);
        
        if (error.code === 'BAD_DATA' && error.value === '0x') {
            console.log(`\nThis error means:`);
            console.log(`   1. The address is not a Safe wallet contract`);
            console.log(`   2. The contract doesn't exist on this network`);
            console.log(`   3. There's a network mismatch`);
            console.log(`\nPossible solutions:`);
            console.log(`   1. Verify the Safe wallet was created on the correct network`);
            console.log(`   2. Check if CHAIN_ID matches the network where Safe was created`);
            console.log(`   3. Verify RPC_URL points to the correct network`);
            console.log(`   4. Create a new Safe wallet: npm run create-safe`);
        }
        process.exit(1);
    }
}

checkSafe().catch(console.error);

