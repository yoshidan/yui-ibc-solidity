// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.12;

import "../../../../contracts/core/24-host/IBCCommitment.sol";

contract IBCCommitmentTestHelper {
    function clientStatePath(string memory clientId) external pure returns (bytes memory) {
        return IBCCommitment.clientStatePath(clientId);
    }

    function consensusStatePath(string memory clientId, uint64 revisionNumber, uint64 revisionHeight)
        external
        pure
        returns (bytes memory)
    {
        return IBCCommitment.consensusStatePath(clientId, revisionNumber, revisionHeight);
    }

    function connectionPath(string memory connectionId) external pure returns (bytes memory) {
        return IBCCommitment.connectionPath(connectionId);
    }

    function channelPath(string memory portId, string memory channelId) external pure returns (bytes memory) {
        return IBCCommitment.channelPath(portId, channelId);
    }

    function packetCommitmentPath(string memory portId, string memory channelId, uint64 sequence)
        external
        pure
        returns (bytes memory)
    {
        return IBCCommitment.packetCommitmentPath(portId, channelId, sequence);
    }

    function packetAcknowledgementCommitmentPath(string memory portId, string memory channelId, uint64 sequence)
        external
        pure
        returns (bytes memory)
    {
        return IBCCommitment.packetAcknowledgementCommitmentPath(portId, channelId, sequence);
    }

    function packetReceiptCommitmentPath(string memory portId, string memory channelId, uint64 sequence)
        external
        pure
        returns (bytes memory)
    {
        return IBCCommitment.packetReceiptCommitmentPath(portId, channelId, sequence);
    }

    function nextSequenceRecvCommitmentPath(string memory portId, string memory channelId)
        external
        pure
        returns (bytes memory)
    {
        return IBCCommitment.nextSequenceRecvCommitmentPath(portId, channelId);
    }
}
