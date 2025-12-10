// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/interfaces/ISafe.sol";
import "../src/interfaces/IMultiSendCallOnly.sol";
import "../src/interfaces/IAavePool.sol";
import "../src/interfaces/IERC20.sol";

/**
 * @title SafeModuleAaveSupply
 * @notice Foundry script for Tenderly Virtual Testnet
 *
 * Flow:
 *   1. Impersonate TASK_EXECUTION_ADDRESS (0x3509F38e10eB3cDcE7695743cB7e81446F4d8A33)
 *   2. Enable SAFE_MODULE_ADDRESS on the Safe wallet (if not already enabled)
 *   3. Impersonate SAFE_MODULE_ADDRESS to call execTransactionFromModule
 *   4. Execute MultiSendCallOnly with DELEGATECALL (operation=1)
 *   5. MultiSend bundles: approve USDC + supply to Aave
 *
 * Addresses:
 *   - TASK_EXECUTION_ADDRESS: 0x3509F38e10eB3cDcE7695743cB7e81446F4d8A33
 *   - SAFE_MODULE_ADDRESS: 0x100656372C821539651f5905Ca39b7C95f9AA433
 *   - SAFE_WALLET_ADDRESS: 0xb7dfd7c6102ed050928d3ac87145c2f69d944e04
 *   - MULTISEND_CALL_ONLY: 0x9641d764fc13c8B624c04430C7356C1C7C8102e2
 *   - AAVE_POOL: 0x794a61358D6845594F94dc1DB02A252b5b4814aD
 *   - USDC: 0xaf88d065e77c8cC2239327C5EDb3A432268e5831
 *
 * Usage:
 *   forge script script/SafeModuleAaveSupply.s.sol:SafeModuleAaveSupply \
 *     --rpc-url https://virtual.arbitrum.eu.rpc.tenderly.co/25645339-50c7-4871-8106-ea2e51105f5a \
 *     --broadcast \
 *     -vvvv
 */
contract SafeModuleAaveSupply is Script {
    // ============ Configuration ============

    /// @notice TaskExecutionHub address
    address constant TASK_EXECUTION_ADDRESS =
        0x3509F38e10eB3cDcE7695743cB7e81446F4d8A33;

    /// @notice TriggerX Safe Module
    address constant SAFE_MODULE_ADDRESS =
        0x100656372C821539651f5905Ca39b7C95f9AA433;

    /// @notice Safe Wallet (read from env)
    address SAFE_WALLET_ADDRESS;

    /// @notice MultiSendCallOnly contract
    address constant MULTISEND_CALL_ONLY =
        0x9641d764fc13c8B624c04430C7356C1C7C8102e2;

    /// @notice Aave V3 Pool on Arbitrum
    address constant AAVE_POOL_ADDRESS =
        0x794a61358D6845594F94dc1DB02A252b5b4814aD;

    /// @notice USDC on Arbitrum (native, 6 decimals)
    address constant USDC_ADDRESS = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    /// @notice USDC whale for funding
    address constant USDC_WHALE = 0x489ee077994B6658eAfA855C308275EAd8097C4A;

    /// @notice Amount to supply (100 USDC)
    uint256 constant SUPPLY_AMOUNT = 100 * 1e6;

    /// @notice Operation types
    uint8 constant CALL = 0;
    uint8 constant DELEGATECALL = 1;

    // ============ Main Entry Point ============

    function run() external {
        // Read Safe address from environment variable
        SAFE_WALLET_ADDRESS = vm.envAddress("SAFE_WALLET_ADDRESS");

        console.log(
            "============================================================"
        );
        console.log("   Safe Module Aave Supply");
        console.log(
            "============================================================\n"
        );

        _logConfiguration();
        _setupAccounts();
        _fundSafeWithUsdc();
        _ensureModuleEnabled();

        bytes memory multiSendData = _buildAaveSupplyMultiSend();
        _executeViaModule(multiSendData);

        _logFinalState();

        console.log(
            "\n============================================================"
        );
        console.log("   Script Completed Successfully");
        console.log(
            "============================================================"
        );
    }

    // ============ Setup Functions ============

    function _logConfiguration() internal view {
        console.log("Configuration:");
        console.log("  TASK_EXECUTION_ADDRESS:", TASK_EXECUTION_ADDRESS);
        console.log("  SAFE_MODULE_ADDRESS:", SAFE_MODULE_ADDRESS);
        console.log("  SAFE_WALLET_ADDRESS:", SAFE_WALLET_ADDRESS);
        console.log("  MULTISEND_CALL_ONLY:", MULTISEND_CALL_ONLY);
        console.log("  AAVE_POOL_ADDRESS:", AAVE_POOL_ADDRESS);
        console.log("  USDC_ADDRESS:", USDC_ADDRESS);
        console.log("  SUPPLY_AMOUNT:", SUPPLY_AMOUNT / 1e6, "USDC");
        console.log("");
    }

    function _setupAccounts() internal {
        console.log("Step 1: Funding accounts with ETH...");

        vm.deal(TASK_EXECUTION_ADDRESS, 10 ether);
        vm.deal(SAFE_WALLET_ADDRESS, 10 ether);
        vm.deal(USDC_WHALE, 10 ether);
        vm.deal(SAFE_MODULE_ADDRESS, 10 ether);

        console.log("  All accounts funded with 10 ETH\n");
    }

    function _fundSafeWithUsdc() internal {
        console.log("Step 2: Funding Safe Wallet with USDC...");

        uint256 whaleBalance = IERC20(USDC_ADDRESS).balanceOf(USDC_WHALE);
        console.log("  Whale USDC balance:", whaleBalance / 1e6, "USDC");

        require(whaleBalance >= SUPPLY_AMOUNT, "Whale insufficient balance");

        vm.prank(USDC_WHALE);
        require(
            IERC20(USDC_ADDRESS).transfer(SAFE_WALLET_ADDRESS, SUPPLY_AMOUNT),
            "Transfer failed"
        );

        uint256 safeBalance = IERC20(USDC_ADDRESS).balanceOf(
            SAFE_WALLET_ADDRESS
        );
        console.log("  Safe USDC balance:", safeBalance / 1e6, "USDC\n");
    }

    function _ensureModuleEnabled() internal {
        console.log("Step 3: Ensuring Safe Module is enabled...");

        ISafe safe = ISafe(SAFE_WALLET_ADDRESS);
        bool isEnabled = safe.isModuleEnabled(SAFE_MODULE_ADDRESS);

        console.log("  Module enabled:", isEnabled);

        if (!isEnabled) {
            console.log("  Enabling module...");

            // Prank the Safe to enable the module
            vm.prank(SAFE_WALLET_ADDRESS);
            safe.enableModule(SAFE_MODULE_ADDRESS);

            // Verify
            isEnabled = safe.isModuleEnabled(SAFE_MODULE_ADDRESS);
            require(isEnabled, "Failed to enable module");
            console.log("  Module enabled successfully");
        }
        console.log("");
    }

    // ============ MultiSend Building ============

    /**
     * @notice Builds MultiSend calldata for approve + supply
     * @dev MultiSend encoding format per transaction:
     *      - operation (1 byte): 0 = Call, 1 = DelegateCall
     *      - to (20 bytes): target address
     *      - value (32 bytes): ETH value
     *      - dataLength (32 bytes): length of the data
     *      - data (variable): calldata
     */
    function _buildAaveSupplyMultiSend() internal view returns (bytes memory) {
        console.log("Step 4: Building MultiSend transaction data...");

        // Transaction 1: Approve USDC for Aave
        bytes memory approveData = abi.encodeWithSelector(
            IERC20.approve.selector,
            AAVE_POOL_ADDRESS,
            SUPPLY_AMOUNT
        );

        // Transaction 2: Supply USDC to Aave
        bytes memory supplyData = abi.encodeWithSelector(
            IAavePool.supply.selector,
            USDC_ADDRESS, // asset
            SUPPLY_AMOUNT, // amount
            SAFE_WALLET_ADDRESS, // onBehalfOf (Safe receives aTokens)
            uint16(0) // referralCode
        );

        console.log("  Approve calldata length:", approveData.length);
        console.log("  Supply calldata length:", supplyData.length);

        // Encode for MultiSend
        bytes memory tx1 = abi.encodePacked(
            uint8(CALL),
            USDC_ADDRESS,
            uint256(0),
            uint256(approveData.length),
            approveData
        );

        bytes memory tx2 = abi.encodePacked(
            uint8(CALL),
            AAVE_POOL_ADDRESS,
            uint256(0),
            uint256(supplyData.length),
            supplyData
        );

        bytes memory transactions = abi.encodePacked(tx1, tx2);

        // Wrap in multiSend call
        bytes memory multiSendCalldata = abi.encodeWithSelector(
            IMultiSendCallOnly.multiSend.selector,
            transactions
        );

        console.log(
            "  Total MultiSend calldata length:",
            multiSendCalldata.length
        );
        console.log("");

        return multiSendCalldata;
    }

    // ============ Execution ============

    /**
     * @notice Executes the MultiSend via Safe Module with DELEGATECALL
     * @dev Flow:
     *      1. Impersonate SAFE_MODULE_ADDRESS
     *      2. Call Safe.execTransactionFromModule() with DELEGATECALL
     *      3. Safe DELEGATECALLs into MultiSendCallOnly
     *      4. MultiSend executes approve + supply
     */
    function _executeViaModule(bytes memory multiSendCalldata) internal {
        console.log("Step 5: Executing via Safe Module with DELEGATECALL...");
        console.log(
            "  Flow: Module -> Safe.execTransactionFromModule -> MultiSend (DELEGATECALL)"
        );

        uint256 initialBalance = IERC20(USDC_ADDRESS).balanceOf(
            SAFE_WALLET_ADDRESS
        );
        uint256 initialAllowance = IERC20(USDC_ADDRESS).allowance(
            SAFE_WALLET_ADDRESS,
            AAVE_POOL_ADDRESS
        );

        console.log("  Initial USDC balance:", initialBalance / 1e6, "USDC");
        console.log("  Initial allowance:", initialAllowance / 1e6, "USDC");

        // Impersonate the Safe Module
        vm.prank(SAFE_MODULE_ADDRESS);

        // Execute via Safe's execTransactionFromModule with DELEGATECALL
        bool success = ISafe(SAFE_WALLET_ADDRESS).execTransactionFromModule(
            MULTISEND_CALL_ONLY, // to: MultiSend contract
            0, // value: no ETH
            multiSendCalldata, // data: multiSend encoded
            DELEGATECALL // operation: 1 = DELEGATECALL
        );

        console.log("  Execution result:", success);
        require(success, "Execution failed");

        uint256 finalBalance = IERC20(USDC_ADDRESS).balanceOf(
            SAFE_WALLET_ADDRESS
        );
        uint256 finalAllowance = IERC20(USDC_ADDRESS).allowance(
            SAFE_WALLET_ADDRESS,
            AAVE_POOL_ADDRESS
        );

        console.log("  Final USDC balance:", finalBalance / 1e6, "USDC");
        console.log("  Final allowance:", finalAllowance / 1e6, "USDC");

        if (finalBalance < initialBalance) {
            console.log(
                "  USDC supplied to Aave:",
                (initialBalance - finalBalance) / 1e6,
                "USDC"
            );
        }
        console.log("");
    }

    function _logFinalState() internal view {
        console.log("Final State:");

        uint256 usdcBalance = IERC20(USDC_ADDRESS).balanceOf(
            SAFE_WALLET_ADDRESS
        );
        uint256 allowance = IERC20(USDC_ADDRESS).allowance(
            SAFE_WALLET_ADDRESS,
            AAVE_POOL_ADDRESS
        );
        bool moduleEnabled = ISafe(SAFE_WALLET_ADDRESS).isModuleEnabled(
            SAFE_MODULE_ADDRESS
        );

        console.log("  Safe USDC Balance:", usdcBalance / 1e6, "USDC");
        console.log("  USDC Allowance for Aave:", allowance / 1e6, "USDC");
        console.log("  Module Enabled:", moduleEnabled);

        if (usdcBalance < SUPPLY_AMOUNT) {
            console.log("\n  SUCCESS: USDC was supplied to Aave!");
            console.log(
                "  Amount supplied:",
                (SUPPLY_AMOUNT - usdcBalance) / 1e6,
                "USDC"
            );
        }
    }
}
