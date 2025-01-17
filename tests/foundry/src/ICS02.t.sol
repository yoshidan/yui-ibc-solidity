// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.12;

import "forge-std/Test.sol";
import "../../../contracts/core/02-client/IBCClient.sol";
import "../../../contracts/core/03-connection/IBCConnectionSelfStateNoValidation.sol";
import "../../../contracts/core/04-channel/IBCChannelHandshake.sol";
import "../../../contracts/core/04-channel/IBCChannelPacketSendRecv.sol";
import "../../../contracts/core/04-channel/IBCChannelPacketTimeout.sol";
import "../../../contracts/core/24-host/IBCCommitment.sol";
import "../../../contracts/proto/MockClient.sol";
import "../../../contracts/proto/Connection.sol";
import "../../../contracts/proto/Channel.sol";
import "../../../contracts/apps/mock/IBCMockApp.sol";
import "./TestableIBCHandler.t.sol";
import "./helpers/ModifiedMockClient.sol";

abstract contract TestIBCBase is Test {
    bytes internal constant DEFAULT_COMMITMENT_PREFIX = bytes("ibc");
    string internal constant MOCK_CLIENT_TYPE = "mock-client";

    function defaultIBCHandler() internal returns (TestableIBCHandler) {
        return new TestableIBCHandler(
            new IBCClient(),
            new IBCConnectionSelfStateNoValidation(),
            new IBCChannelHandshake(),
            new IBCChannelPacketSendRecv(),
            new IBCChannelPacketTimeout()
        );
    }

    // solhint-disable func-name-mixedcase
    function H(uint64 revisionNumber, uint64 revisionHeight) internal pure returns (Height.Data memory) {
        return Height.Data({revision_number: revisionNumber, revision_height: revisionHeight});
    }
}

abstract contract TestMockClientHelper is TestIBCBase {
    using IBCHeight for Height.Data;

    function ibcHandlerMockClient() internal returns (TestableIBCHandler, ModifiedMockClient) {
        TestableIBCHandler handler = defaultIBCHandler();
        ModifiedMockClient mockClient = new ModifiedMockClient(address(handler));
        handler.registerClient(MOCK_CLIENT_TYPE, mockClient);
        return (handler, mockClient);
    }

    function createMockClient(TestableIBCHandler handler, uint64 revisionHeight) internal returns (string memory) {
        return createMockClient(handler, revisionHeight, 1);
    }

    function createMockClient(TestableIBCHandler handler, uint64 revisionHeight, uint64 times)
        internal
        returns (string memory)
    {
        string memory clientId;
        for (uint64 i = 0; i < times; i++) {
            clientId = handler.createClient(msgCreateMockClient(revisionHeight));
        }
        return clientId;
    }

    function mockClientId(uint64 sequence) internal pure returns (string memory) {
        return string(abi.encodePacked(MOCK_CLIENT_TYPE, "-", Strings.toString(sequence)));
    }

    function mockClientState(uint64 revisionNumber, uint64 revisionHeight) internal pure returns (bytes memory) {
        return wrapAnyMockClientState(
            IbcLightclientsMockV1ClientState.Data({latest_height: H(revisionNumber, revisionHeight)})
        );
    }

    function mockConsensusState(uint64 timestamp) internal pure returns (bytes memory) {
        return wrapAnyMockConsensusState(IbcLightclientsMockV1ConsensusState.Data({timestamp: timestamp}));
    }

    function msgCreateMockClient(uint64 revisionHeight) internal view returns (IIBCClient.MsgCreateClient memory) {
        return msgCreateMockClient(0, revisionHeight);
    }

    function msgCreateMockClient(uint64 revisionNumber, uint64 revisionHeight)
        internal
        view
        returns (IIBCClient.MsgCreateClient memory)
    {
        return IIBCClient.MsgCreateClient({
            clientType: MOCK_CLIENT_TYPE,
            clientStateBytes: mockClientState(revisionNumber, revisionHeight),
            consensusStateBytes: mockConsensusState(uint64(block.timestamp * 1e9))
        });
    }

    function msgUpdateMockClient(string memory clientId, uint64 nextRevisionHeight)
        internal
        view
        returns (IIBCClient.MsgUpdateClient memory)
    {
        return IIBCClient.MsgUpdateClient({
            clientId: clientId,
            clientMessage: wrapAnyMockHeader(
                IbcLightclientsMockV1Header.Data({
                    height: H(0, nextRevisionHeight),
                    timestamp: uint64(block.timestamp * 1e9)
                })
                )
        });
    }

    function genMockProof(Height.Data memory proofHeight, bytes memory prefix, bytes memory path, bytes memory value)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            sha256(abi.encodePacked(proofHeight.toUint128(), sha256(prefix), sha256(path), sha256(value)))
        );
    }

    function genMockClientStateProof(
        Height.Data memory proofHeight,
        string memory clientId,
        uint64 revisionNumber,
        uint64 revisionHeight
    ) internal pure returns (bytes memory) {
        return genMockClientStateProof(proofHeight, DEFAULT_COMMITMENT_PREFIX, clientId, revisionNumber, revisionHeight);
    }

    function genMockConsensusStateProof(
        Height.Data memory proofHeight,
        string memory clientId,
        uint64 revisionNumber,
        uint64 revisionHeight,
        uint64 timestamp
    ) internal pure returns (bytes memory) {
        return genMockConsensusStateProof(
            proofHeight, DEFAULT_COMMITMENT_PREFIX, clientId, revisionNumber, revisionHeight, timestamp
        );
    }

    function genMockClientStateProof(
        Height.Data memory proofHeight,
        bytes memory prefix,
        string memory clientId,
        uint64 revisionNumber,
        uint64 revisionHeight
    ) internal pure returns (bytes memory) {
        return genMockProof(
            proofHeight,
            prefix,
            IBCCommitment.clientStatePath(clientId),
            mockClientState(revisionNumber, revisionHeight)
        );
    }

    function genMockConsensusStateProof(
        Height.Data memory proofHeight,
        bytes memory prefix,
        string memory clientId,
        uint64 revisionNumber,
        uint64 revisionHeight,
        uint64 timestamp
    ) internal pure returns (bytes memory) {
        return genMockProof(
            proofHeight,
            prefix,
            IBCCommitment.consensusStatePath(clientId, revisionNumber, revisionHeight),
            mockConsensusState(timestamp)
        );
    }

    function genMockConnectionStateProof(
        Height.Data memory proofHeight,
        string memory connectionId,
        ConnectionEnd.Data memory connection
    ) internal pure returns (bytes memory) {
        return genMockConnectionStateProof(proofHeight, DEFAULT_COMMITMENT_PREFIX, connectionId, connection);
    }

    function genMockConnectionStateProof(
        Height.Data memory proofHeight,
        bytes memory prefix,
        string memory connectionId,
        ConnectionEnd.Data memory connection
    ) internal pure returns (bytes memory) {
        return genMockProof(
            proofHeight, prefix, IBCCommitment.connectionPath(connectionId), ConnectionEnd.encode(connection)
        );
    }

    function genMockChannelStateProof(
        Height.Data memory proofHeight,
        string memory portId,
        string memory channelId,
        Channel.Data memory channel
    ) internal pure returns (bytes memory) {
        return genMockProof(
            proofHeight,
            DEFAULT_COMMITMENT_PREFIX,
            IBCCommitment.channelPath(portId, channelId),
            Channel.encode(channel)
        );
    }

    function wrapAnyMockHeader(IbcLightclientsMockV1Header.Data memory header) internal pure returns (bytes memory) {
        Any.Data memory anyHeader;
        anyHeader.type_url = "/ibc.lightclients.mock.v1.Header";
        anyHeader.value = IbcLightclientsMockV1Header.encode(header);
        return Any.encode(anyHeader);
    }

    function wrapAnyMockClientState(IbcLightclientsMockV1ClientState.Data memory clientState)
        internal
        pure
        returns (bytes memory)
    {
        Any.Data memory anyClientState;
        anyClientState.type_url = "/ibc.lightclients.mock.v1.ClientState";
        anyClientState.value = IbcLightclientsMockV1ClientState.encode(clientState);
        return Any.encode(anyClientState);
    }

    function wrapAnyMockConsensusState(IbcLightclientsMockV1ConsensusState.Data memory consensusState)
        internal
        pure
        returns (bytes memory)
    {
        Any.Data memory anyConsensusState;
        anyConsensusState.type_url = "/ibc.lightclients.mock.v1.ConsensusState";
        anyConsensusState.value = IbcLightclientsMockV1ConsensusState.encode(consensusState);
        return Any.encode(anyConsensusState);
    }

    function getTimestamp(ILightClient client, string memory clientId, int64 diff) internal view returns (uint64) {
        (, uint64 timestamp) = getClientLatestInfo(client, clientId);
        return uint64(int64(timestamp) + diff);
    }

    function getHeight(ILightClient client, string memory clientId, int64 diff)
        internal
        view
        returns (Height.Data memory)
    {
        (Height.Data memory latestHeight,) = getClientLatestInfo(client, clientId);
        return Height.Data({
            revision_number: latestHeight.revision_number,
            revision_height: uint64(int64(latestHeight.revision_height) + diff)
        });
    }

    function getClientLatestInfo(ILightClient client, string memory clientId)
        internal
        view
        returns (Height.Data memory, uint64)
    {
        (Height.Data memory latestHeight, bool ok) = client.getLatestHeight(clientId);
        assert(ok);
        uint64 timestamp;
        (timestamp, ok) = client.getTimestampAtHeight(clientId, latestHeight);
        assert(ok);
        return (latestHeight, timestamp);
    }
}

contract TestICS02 is TestIBCBase, TestMockClientHelper {
    function testRegisterClient() public {
        TestableIBCHandler handler = defaultIBCHandler();
        MockClient mockClient = new MockClient(address(handler));
        handler.registerClient(MOCK_CLIENT_TYPE, mockClient);
        handler.registerClient("test", mockClient);
    }

    function testRegisterClientDuplicatedClientType() public {
        TestableIBCHandler handler = defaultIBCHandler();
        MockClient mockClient = new MockClient(address(handler));
        handler.registerClient(MOCK_CLIENT_TYPE, mockClient);
        vm.expectRevert("clientType already exists");
        handler.registerClient(MOCK_CLIENT_TYPE, mockClient);
    }

    function testRegisterClientInvalidClientType() public {
        TestableIBCHandler handler = defaultIBCHandler();
        vm.expectRevert("invalid client address");
        handler.registerClient(MOCK_CLIENT_TYPE, ILightClient(address(0)));

        MockClient mockClient = new MockClient(address(handler));
        vm.expectRevert("invalid clientType");
        handler.registerClient("", mockClient);

        vm.expectRevert("invalid clientType");
        handler.registerClient("-mock", mockClient);

        vm.expectRevert("invalid clientType");
        handler.registerClient("mock-", mockClient);
    }

    function testCreateClient() public {
        (TestableIBCHandler handler, MockClient mockClient) = ibcHandlerMockClient();
        {
            string memory clientId = handler.createClient(msgCreateMockClient(1));
            assertEq(clientId, mockClientId(0));
            assertEq(handler.getClientType(clientId), MOCK_CLIENT_TYPE);
            assertEq(handler.getClient(clientId), address(mockClient));
            assertFalse(handler.getCommitment(IBCCommitment.clientStateCommitmentKey(clientId)) == bytes32(0));
            assertFalse(handler.getCommitment(IBCCommitment.consensusStateCommitmentKey(clientId, 0, 1)) == bytes32(0));
        }
        {
            string memory clientId = handler.createClient(msgCreateMockClient(100));
            assertEq(clientId, mockClientId(1));
            assertEq(handler.getClientType(clientId), MOCK_CLIENT_TYPE);
            assertEq(handler.getClient(clientId), address(mockClient));
            assertFalse(handler.getCommitment(IBCCommitment.clientStateCommitmentKey(clientId)) == bytes32(0));
            assertFalse(
                handler.getCommitment(IBCCommitment.consensusStateCommitmentKey(clientId, 0, 100)) == bytes32(0)
            );
        }
    }

    function testInvalidCreateClient() public {
        (TestableIBCHandler handler,) = ibcHandlerMockClient();
        {
            IIBCClient.MsgCreateClient memory msg_ = msgCreateMockClient(1);
            msg_.clientType = "";
            vm.expectRevert("unregistered client type");
            handler.createClient(msg_);
        }
        {
            IIBCClient.MsgCreateClient memory msg_ = msgCreateMockClient(1);
            msg_.clientType = "06-solomachine";
            vm.expectRevert("unregistered client type");
            handler.createClient(msg_);
        }
        {
            IIBCClient.MsgCreateClient memory msg_ = msgCreateMockClient(1);
            msg_.clientStateBytes = abi.encodePacked(msg_.clientStateBytes, hex"00");
            vm.expectRevert();
            handler.createClient(msg_);
        }
        {
            IIBCClient.MsgCreateClient memory msg_ = msgCreateMockClient(1);
            msg_.consensusStateBytes = abi.encodePacked(msg_.consensusStateBytes, hex"00");
            vm.expectRevert();
            handler.createClient(msg_);
        }
    }

    function testUpdateClient() public {
        bytes32 prevClientStateCommitment;
        (TestableIBCHandler handler,) = ibcHandlerMockClient();
        string memory clientId = handler.createClient(msgCreateMockClient(1));
        prevClientStateCommitment = handler.getCommitment(IBCCommitment.clientStateCommitmentKey(clientId));

        {
            handler.updateClient(msgUpdateMockClient(clientId, 2));
            bytes32 commitment = handler.getCommitment(IBCCommitment.clientStateCommitmentKey(clientId));
            assertTrue(
                commitment != prevClientStateCommitment && commitment != bytes32(0), "commitment should be updated"
            );
            prevClientStateCommitment = commitment;
        }
        {
            handler.updateClient(msgUpdateMockClient(clientId, 3));
            bytes32 commitment = handler.getCommitment(IBCCommitment.clientStateCommitmentKey(clientId));
            assertTrue(
                commitment != prevClientStateCommitment && commitment != bytes32(0), "commitment should be updated"
            );
            prevClientStateCommitment = commitment;
        }
    }

    function testInvalidUpdateClient() public {
        (TestableIBCHandler handler,) = ibcHandlerMockClient();
        string memory clientId = handler.createClient(msgCreateMockClient(1));
        assertEq(clientId, mockClientId(0));
        {
            IIBCClient.MsgUpdateClient memory msg_ = msgUpdateMockClient(clientId, 2);
            msg_.clientId = "";
            vm.expectRevert();
            handler.updateClient(msg_);
        }
        {
            IIBCClient.MsgUpdateClient memory msg_ = msgUpdateMockClient(clientId, 2);
            msg_.clientId = mockClientId(1);
            vm.expectRevert();
            handler.updateClient(msg_);
        }
        {
            IIBCClient.MsgUpdateClient memory msg_ = msgUpdateMockClient(clientId, 2);
            msg_.clientMessage = abi.encodePacked(msg_.clientMessage, hex"00");
            vm.expectRevert();
            handler.updateClient(msg_);
        }
    }
}
