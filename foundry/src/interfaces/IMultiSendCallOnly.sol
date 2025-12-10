// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IMultiSendCallOnly
 * @notice Interface for Safe's MultiSendCallOnly contract
 * @dev Allows bundling multiple transactions into a single call
 *
 * Each transaction in the batch is encoded as:
 * - operation (1 byte): 0 = Call, 1 = DelegateCall
 * - to (20 bytes): target address
 * - value (32 bytes): ETH value
 * - dataLength (32 bytes): length of the data
 * - data (dataLength bytes): calldata
 */
interface IMultiSendCallOnly {
    /// @dev Sends multiple transactions and reverts all if one fails.
    /// @param transactions Encoded transactions. Each transaction is encoded as a packed bytes of
    ///                     operation (1 byte), to (20 bytes), value (32 bytes), data length (32 bytes), data (variable)
    function multiSend(bytes memory transactions) external payable;
}
