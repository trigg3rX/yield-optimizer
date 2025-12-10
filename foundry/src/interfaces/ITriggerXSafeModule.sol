// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ITriggerXSafeModule
 * @notice Interface for TriggerX Safe Module contract
 * @dev This module allows TaskExecutionHub to execute transactions on behalf of a Safe wallet
 */
interface ITriggerXSafeModule {
    /// @dev Execute a job from the TaskExecutionHub
    /// @param safeAddress The Safe contract address
    /// @param actionTarget Target contract the user wants to call
    /// @param actionValue ETH value for the action
    /// @param actionData Calldata for the actionTarget
    /// @param operation 0 = CALL, 1 = DELEGATECALL
    /// @return success Whether the execution was successful
    function execJobFromHub(
        address safeAddress,
        address actionTarget,
        uint256 actionValue,
        bytes calldata actionData,
        uint8 operation
    ) external returns (bool success);

    /// @dev Returns the TaskExecutionHub address
    function taskExecutionHub() external view returns (address);
}
