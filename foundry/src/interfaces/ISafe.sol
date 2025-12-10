// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ISafe
 * @notice Interface for Safe (Gnosis Safe) wallet contract
 */
interface ISafe {
    /// @dev Allows a Module to execute a Safe transaction without any further confirmations.
    /// @param to Destination address of module transaction.
    /// @param value Ether value of module transaction.
    /// @param data Data payload of module transaction.
    /// @param operation Operation type of module transaction.
    function execTransactionFromModule(
        address to,
        uint256 value,
        bytes calldata data,
        uint8 operation
    ) external returns (bool success);

    /// @dev Allows a Module to execute a Safe transaction without any further confirmations and return data.
    /// @param to Destination address of module transaction.
    /// @param value Ether value of module transaction.
    /// @param data Data payload of module transaction.
    /// @param operation Operation type of module transaction.
    function execTransactionFromModuleReturnData(
        address to,
        uint256 value,
        bytes calldata data,
        uint8 operation
    ) external returns (bool success, bytes memory returnData);

    /// @dev Enables the module `module` for the Safe.
    /// @param module Module to be enabled.
    function enableModule(address module) external;

    /// @dev Disables the module `module` for the Safe.
    /// @param prevModule Previous module in the modules linked list.
    /// @param module Module to be disabled.
    function disableModule(address prevModule, address module) external;

    /// @dev Returns if an module is enabled
    /// @return True if the module is enabled
    function isModuleEnabled(address module) external view returns (bool);

    /// @dev Returns the list of owners
    /// @return Array of owners
    function getOwners() external view returns (address[] memory);

    /// @dev Returns the threshold
    /// @return Threshold for Safe transactions
    function getThreshold() external view returns (uint256);

    /// @dev Checks whether the signature provided is valid for the provided data, hash. Will revert otherwise.
    /// @param dataHash Hash of the data (could be a message hash or transaction hash)
    /// @param signatures Signature data that should be verified.
    function checkSignatures(bytes32 dataHash, bytes memory signatures) external view;

    /// @dev Returns the nonce to be used for Safe transactions
    /// @return Safe transaction nonce
    function nonce() external view returns (uint256);
}
