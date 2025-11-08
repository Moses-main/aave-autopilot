// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IKeeperRegistry {
    function registerAndPredictID(
        string memory name,
        bytes calldata encryptedEmail,
        address upkeepContract,
        uint32 gasLimit,
        address adminAddress,
        bytes calldata checkData,
        address gasToken,
        uint96 amount,
        uint8 source,
        address sender
    ) external returns (uint256 id, uint256 balance);
    
    function getUpkeep(uint256 id) external view returns (
        address target,
        uint32 executeGas,
        bytes memory checkData,
        uint96 balance,
        address lastKeeper,
        address admin,
        uint64 maxValidBlocknumber,
        uint96 amountSpent
    );
}
