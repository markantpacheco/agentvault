// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, Vm} from "forge-std/Test.sol";
import {GenesisAgent} from "../src/GenesisAgent.sol";
import {Archetype, ArchetypeLib} from "../src/Archetype.sol";

/// @title GenesisAgentTest
/// @notice Tests for the Genesis Agent NFT and its permanent archetype.
/// @dev Invariant ids (G1..G7) refer to docs/specs/GenesisAgent.md.
///      Mints are made from EOAs via `vm.prank`, not from this contract:
///      `_safeMint` calls `onERC721Received` on a contract recipient and this
///      test contract does not implement it.
contract GenesisAgentTest is Test {
    GenesisAgent internal genesis;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");

    event ArchetypeAssigned(uint256 indexed tokenId, address indexed to, Archetype archetype);

    function setUp() public {
        genesis = new GenesisAgent();
    }

    /// WHAT: Minting assigns exactly the archetype the caller asked for.
    /// WHY: The archetype is permanent, so a wrong assignment at mint can
    ///      never be corrected.
    /// FAILURE MEANS: Holders are permanently stuck with the wrong identity.
    function test_MintAssignsRequestedArchetype() public {
        vm.prank(alice);
        uint256 tokenId = genesis.mint(Archetype.Navigator);

        assertEq(genesis.ownerOf(tokenId), alice, "wrong owner");
        assertEq(uint8(genesis.archetypeOf(tokenId)), uint8(Archetype.Navigator), "wrong archetype");
        assertEq(genesis.archetypeNameOf(tokenId), "Navigator", "wrong name");
    }

    /// WHAT: Minting with the zero value reverts.
    /// WHY: Uninitialised storage reads as zero. If Unassigned were mintable,
    ///      a never-assigned token could not be told apart from a real one.
    /// FAILURE MEANS: Invalid archetypes reach permanent storage. Violates G3.
    function test_MintRejectsUnassigned() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ArchetypeLib.InvalidArchetype.selector, uint8(0)));
        genesis.mint(Archetype.Unassigned);
    }

    /// WHAT: A raw call carrying an out-of-range enum value fails.
    /// WHY: The typed signature cannot express a value above 4, but calldata
    ///      can. The ABI boundary must reject it, not coerce it.
    /// FAILURE MEANS: An archetype outside the enum could be stored. G3.
    function test_MintRejectsOutOfRangeArchetype() public {
        vm.prank(alice);
        (bool ok,) =
            address(genesis).call(abi.encodeWithSelector(GenesisAgent.mint.selector, uint8(5)));
        assertFalse(ok, "out-of-range archetype accepted");
        assertEq(genesis.totalMinted(), 0, "token minted despite failure");
    }

    /// WHAT: The first token id is 1, not 0.
    /// WHY: Token id 0 is indistinguishable from an unset storage slot.
    /// FAILURE MEANS: An unset mapping entry reads as a valid token. G6.
    function test_FirstTokenIdIsOne() public {
        vm.prank(alice);
        assertEq(genesis.mint(Archetype.Guardian), 1, "first id not 1");
    }

    /// WHAT: Sequential mints get distinct, increasing ids.
    /// WHY: Two tokens sharing an id would collide in every downstream
    ///      registry — account, mandate, performance record.
    /// FAILURE MEANS: Account isolation breaks at the identity layer. G6.
    function test_TokenIdsAreUnique() public {
        vm.prank(alice);
        uint256 first = genesis.mint(Archetype.Guardian);
        vm.prank(bob);
        uint256 second = genesis.mint(Archetype.Maverick);

        assertEq(first, 1, "first id");
        assertEq(second, 2, "second id");
        assertEq(genesis.totalMinted(), 2, "totalMinted wrong");
    }

    /// WHAT: A second mint from the same address reverts.
    /// WHY: The PROTOTYPE mint policy is one per address, ever.
    /// FAILURE MEANS: The per-address limit is not enforced.
    function test_SecondMintFromSameAddressReverts() public {
        vm.prank(alice);
        genesis.mint(Archetype.Guardian);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(GenesisAgent.AlreadyMinted.selector, alice));
        genesis.mint(Archetype.Tactician);
    }

    /// WHAT: Transferring the token away does not restore the right to mint.
    /// WHY: The limit is keyed on "has ever minted", not "currently holds".
    ///      Gating on balance would let one address mint without limit by
    ///      transferring each token away first.
    /// FAILURE MEANS: The per-address limit is trivially bypassable.
    function test_RemintAfterTransferringAwayStillReverts() public {
        vm.prank(alice);
        uint256 tokenId = genesis.mint(Archetype.Guardian);

        vm.prank(alice);
        genesis.safeTransferFrom(alice, bob, tokenId);
        assertEq(genesis.balanceOf(alice), 0, "alice should hold nothing");

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(GenesisAgent.AlreadyMinted.selector, alice));
        genesis.mint(Archetype.Maverick);
    }

    /// WHAT: Querying an unminted token reverts rather than returning zero.
    /// WHY: A silent Unassigned return could flow into NFT metadata unnoticed.
    /// FAILURE MEANS: Corrupt metadata ships without any error being raised.
    function test_ArchetypeOfRevertsForNonexistentToken() public {
        vm.expectRevert(abi.encodeWithSelector(GenesisAgent.NonexistentToken.selector, uint256(99)));
        genesis.archetypeOf(99);

        vm.expectRevert(abi.encodeWithSelector(GenesisAgent.NonexistentToken.selector, uint256(99)));
        genesis.archetypeNameOf(99);
    }

    /// WHAT: The archetype is identical after a transfer.
    /// WHY: A named acceptance criterion — the collectible identity belongs to
    ///      the token, not to whoever happens to hold it.
    /// FAILURE MEANS: Identity is mutable via transfer. Violates G1 and G4.
    function test_ArchetypeUnchangedAfterTransfer() public {
        vm.prank(alice);
        uint256 tokenId = genesis.mint(Archetype.Tactician);

        vm.prank(alice);
        genesis.safeTransferFrom(alice, bob, tokenId);

        assertEq(genesis.ownerOf(tokenId), bob, "transfer did not happen");
        assertEq(
            uint8(genesis.archetypeOf(tokenId)), uint8(Archetype.Tactician), "archetype changed"
        );
    }

    /// WHAT: The archetype survives approvals and repeated transfers.
    /// WHY: Approval and transfer are the only state-changing entry points an
    ///      outsider controls. If none of them can move the archetype, no
    ///      caller-reachable path can.
    /// FAILURE MEANS: Some ERC-721 path mutates the archetype. G1.
    function test_ArchetypeStableAcrossApprovalsAndTransfers() public {
        vm.prank(alice);
        uint256 tokenId = genesis.mint(Archetype.Maverick);

        vm.prank(alice);
        genesis.approve(bob, tokenId);
        vm.prank(bob);
        genesis.safeTransferFrom(alice, bob, tokenId);
        vm.prank(bob);
        genesis.setApprovalForAll(carol, true);
        vm.prank(carol);
        genesis.safeTransferFrom(bob, carol, tokenId);

        assertEq(
            uint8(genesis.archetypeOf(tokenId)), uint8(Archetype.Maverick), "archetype changed"
        );
    }

    /// WHAT: ArchetypeAssigned fires once at mint and never again.
    /// WHY: The absence of a second event is the on-chain evidence indexers
    ///      use to prove the archetype is permanent.
    /// FAILURE MEANS: Permanence cannot be verified from event history. G1.
    function test_ArchetypeAssignedEmittedExactlyOncePerToken() public {
        vm.prank(alice);
        vm.expectEmit(true, true, false, true, address(genesis));
        emit ArchetypeAssigned(1, alice, Archetype.Guardian);
        uint256 tokenId = genesis.mint(Archetype.Guardian);

        // Now exercise every other entry point and count the events emitted.
        vm.recordLogs();
        vm.prank(alice);
        genesis.safeTransferFrom(alice, bob, tokenId);
        vm.prank(bob);
        genesis.approve(carol, tokenId);
        vm.prank(bob);
        genesis.safeTransferFrom(bob, carol, tokenId);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 wanted = keccak256("ArchetypeAssigned(uint256,address,uint8)");
        uint256 seen;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics.length > 0 && logs[i].topics[0] == wanted) {
                seen++;
            }
        }
        assertEq(seen, 0, "ArchetypeAssigned re-emitted after mint");
    }

    /// WHAT: Nothing in this contract turns an archetype into a numeric limit.
    /// WHY: Rarity must never confer a financial advantage. Enforced here by
    ///      the absence of any such function; the risk engine carries the
    ///      positive test in Milestone 7.
    /// FAILURE MEANS: Collectible identity has leaked into financial risk. G5.
    /// @dev Two tokens with the most and least "defensive" archetypes are
    ///      indistinguishable through every view this contract exposes, apart
    ///      from the archetype itself and its name.
    function test_ArchetypeConfersNoNumericDifference() public {
        vm.prank(alice);
        uint256 guardianId = genesis.mint(Archetype.Guardian);
        vm.prank(bob);
        uint256 maverickId = genesis.mint(Archetype.Maverick);

        assertEq(genesis.balanceOf(alice), genesis.balanceOf(bob), "balances differ");
        assertEq(maverickId - guardianId, 1, "ids not sequential");
        assertTrue(genesis.hasMinted(alice) == genesis.hasMinted(bob), "mint status differs");
    }

    /// WHAT: For every valid archetype, what goes in comes back out.
    /// WHY: Fuzzing checks the rule generally, not only for hand-picked cases.
    /// FAILURE MEANS: Some archetype is stored or returned incorrectly. G2.
    function testFuzz_ArchetypeRoundTrips(uint8 raw) public {
        uint8 bounded = uint8(
            bound(uint256(raw), uint256(uint8(Archetype.Guardian)), ArchetypeLib.ARCHETYPE_COUNT)
        );
        Archetype expected = Archetype(bounded);

        address minter = address(uint160(uint256(keccak256(abi.encode(raw)))));
        vm.assume(minter != address(0));
        vm.prank(minter);
        uint256 tokenId = genesis.mint(expected);

        assertEq(uint8(genesis.archetypeOf(tokenId)), bounded, "archetype did not round-trip");
    }

    /// WHAT: The archetype is unchanged after an arbitrary number of transfers.
    /// WHY: Permanence must hold for any transfer history, not just one hop.
    /// FAILURE MEANS: Repeated transfers can erode the archetype. G4.
    function testFuzz_ArchetypeSurvivesManyTransfers(uint8 hops) public {
        uint256 count = bound(uint256(hops), 1, 20);

        vm.prank(alice);
        uint256 tokenId = genesis.mint(Archetype.Navigator);

        address holder = alice;
        for (uint256 i = 0; i < count; i++) {
            address next = address(uint160(0x1000 + i));
            vm.prank(holder);
            genesis.safeTransferFrom(holder, next, tokenId);
            holder = next;
        }

        assertEq(genesis.ownerOf(tokenId), holder, "final owner wrong");
        assertEq(
            uint8(genesis.archetypeOf(tokenId)), uint8(Archetype.Navigator), "archetype changed"
        );
    }
}
