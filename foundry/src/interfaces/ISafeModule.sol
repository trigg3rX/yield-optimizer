// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ISafeModule
 * @notice Interface for TriggerX Safe Module contract
 * @dev This module allows executing transactions on behalf of a Safe wallet
 */
interface ISafeModule {
    /// @dev Execute a transaction through the Safe Module
    /// @param safe Address of the Safe wallet
    /// @param to Target address for the transaction
    /// @param value ETH value to send
    /// @param data Calldata for the transaction
    /// @param operation 0 = Call, 1 = DelegateCall
    function executeTransaction(
        address safe,
        address to,
        uint256 value,
        bytes calldata data,
        uint8 operation
    ) external returns (bool success);

    /// @dev Execute a transaction through the Safe Module and return data
    /// @param safe Address of the Safe wallet
    /// @param to Target address for the transaction
    /// @param value ETH value to send
    /// @param data Calldata for the transaction
    /// @param operation 0 = Call, 1 = DelegateCall
    function executeTransactionReturnData(
        address safe,
        address to,
        uint256 value,
        bytes calldata data,
        uint8 operation
    ) external returns (bool success, bytes memory returnData);

    /// @dev Check if the module is authorized to execute transactions on behalf of a Safe
    /// @param safe Address of the Safe wallet
    function isAuthorized(address safe) external view returns (bool);
}
