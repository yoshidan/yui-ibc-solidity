// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.12;

import "../../../../contracts/clients/MockClient.sol";

/**
 * @dev ModifiedMockClient is a modified MockClient implementation for testing purposes.
 */
contract ModifiedMockClient is MockClient {
    using BytesLib for bytes;
    using IBCHeight for Height.Data;

    constructor(address _ibcHandler) MockClient(_ibcHandler) {}

    /**
     * @dev setStatus sets the status of the client corresponding to `clientId`.
     */
    function setStatus(string calldata clientId, ClientStatus status) external virtual {
        statuses[clientId] = status;
    }

    /**
     * @dev verifyMembership is a generic proof verification method which verifies a proof of the existence of a value at a given CommitmentPath at the specified height.
     * The caller is expected to construct the full CommitmentPath from a CommitmentPrefix and a standardized path (as defined in ICS 24).
     */
    function verifyMembership(
        string calldata clientId,
        Height.Data calldata height,
        uint64,
        uint64,
        bytes calldata proof,
        bytes calldata prefix,
        bytes memory path,
        bytes calldata value
    ) external view override returns (bool) {
        require(consensusStates[clientId][height.toUint128()].timestamp != 0, "consensus state not found");
        require(keccak256(IIBCHandler(ibcHandler).getCommitmentPrefix()) == keccak256(prefix), "invalid prefix");
        return sha256(abi.encodePacked(height.toUint128(), sha256(prefix), sha256(path), sha256(value)))
            == proof.toBytes32(0);
    }
}
