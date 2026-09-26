// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {GenesisAgent} from "../src/GenesisAgent.sol";
import {AccountRegistry} from "../src/AccountRegistry.sol";
import {IAccountRegistry} from "../src/interfaces/IAccountRegistry.sol";
import {Archetype} from "../src/Archetype.sol";
import {Mandate, MandateParams} from "../src/Mandate.sol";
import {RiskEngine, TradeProposal, Side, RejectReason} from "../src/RiskEngine.sol";

/// @title ArchetypeRiskIsolationTest
/// @notice Integration test for the single rule the whole architecture is
///         arranged around: **rarity has no effect on any risk limit.**
///
/// @dev Uses the REAL `GenesisAgent`, `AccountRegistry` and `RiskEngine`, not
///      mocks. The mock registry in `RiskEngine.t.sol` has no archetype at all,
///      so it cannot prove anything about archetypes — the proof needs the real
///      NFT that actually carries one.
///
///      Four holders mint four DIFFERENT archetypes, select the SAME mandate,
///      and submit the SAME proposal. Every validation result must be identical.
contract ArchetypeRiskIsolationTest is Test {
    GenesisAgent internal nft;
    AccountRegistry internal registry;
    RiskEngine internal engine;

    /// @dev Test fixture, not a real token address.
    address internal constant ASSET = address(0x1000000000000000000000000000000000000001);

    address[4] internal holders = [
        makeAddr("guardianHolder"),
        makeAddr("navigatorHolder"),
        makeAddr("tacticianHolder"),
        makeAddr("maverickHolder")
    ];
    Archetype[4] internal archetypes =
        [Archetype.Guardian, Archetype.Navigator, Archetype.Tactician, Archetype.Maverick];

    uint256[4] internal tokenIds;

    function setUp() public {
        vm.warp(1_000_000);

        nft = new GenesisAgent(10_000);
        registry = new AccountRegistry(IERC721(address(nft)));
        address[] memory assets = new address[](1);
        assets[0] = ASSET;
        engine = new RiskEngine(IAccountRegistry(address(registry)), assets);

        // Four holders, four archetypes, everything else identical.
        for (uint256 i = 0; i < 4; i++) {
            address holder = holders[i];
            vm.prank(holder);
            uint256 tokenId = nft.mint(archetypes[i]);
            tokenIds[i] = tokenId;

            vm.prank(holder);
            registry.createAccount(tokenId);
            vm.prank(holder);
            registry.setMandate(tokenId, Mandate.Balanced);
            vm.prank(holder);
            registry.setAutomationPaused(tokenId, false);
        }
    }

    function _proposal(uint256 sizeUnits, uint16 slippageBps)
        internal
        view
        returns (TradeProposal memory)
    {
        return TradeProposal({
            asset: ASSET,
            side: Side.Buy,
            sizeUnits: sizeUnits,
            slippageBps: slippageBps,
            dataTimestamp: block.timestamp
        });
    }

    /// WHAT: The four accounts really do carry four different archetypes, and
    ///       identical everything else.
    /// WHY: Without this, the isolation tests below could pass vacuously — four
    ///      accounts that were accidentally identical would prove nothing.
    /// FAILURE MEANS: The rarity tests are not actually comparing different
    ///      archetypes.
    function test_SetupGivesFourDistinctArchetypesAndIdenticalEverythingElse() public view {
        for (uint256 i = 0; i < 4; i++) {
            assertEq(
                uint8(nft.archetypeOf(tokenIds[i])), uint8(archetypes[i]), "archetype not as minted"
            );
            AccountRegistry.Account memory a = registry.getAccount(tokenIds[i]);
            assertEq(a.balance, registry.SEED_BALANCE(), "balances differ");
            assertEq(uint8(a.mandate), uint8(Mandate.Balanced), "mandates differ");
            assertFalse(registry.isAutomationPaused(tokenIds[i]), "pause states differ");
        }
        // And the four archetypes really are distinct from one another.
        for (uint256 i = 0; i < 4; i++) {
            for (uint256 j = i + 1; j < 4; j++) {
                assertTrue(
                    nft.archetypeOf(tokenIds[i]) != nft.archetypeOf(tokenIds[j]),
                    "two archetypes were the same"
                );
            }
        }
    }

    /// WHAT: Four different archetypes, same mandate, same proposal — identical
    ///       validation results.
    /// WHY: This is the product's central separation. A Maverick holder who
    ///      wants to be cautious must be able to be, and a Guardian holder who
    ///      wants to be aggressive must be able to be. Collectible rarity must
    ///      never buy a wider limit.
    /// FAILURE MEANS: Rarity influences financial risk, which is the one thing
    ///      the archetype/mandate split exists to prevent.
    function test_RarityHasNoEffectOnValidation() public view {
        TradeProposal memory p = _proposal(1500e18, 75); // comfortably inside Balanced

        (bool firstApproved, RejectReason firstReason) = engine.validate(tokenIds[0], p);
        assertTrue(firstApproved, "baseline should be approved");

        for (uint256 i = 1; i < 4; i++) {
            (bool approved, RejectReason reason) = engine.validate(tokenIds[i], p);
            assertEq(approved, firstApproved, "approval differed across archetypes");
            assertEq(uint8(reason), uint8(firstReason), "reason differed across archetypes");
        }
    }

    /// WHAT: At the exact position cap, all four archetypes agree.
    /// WHY: A boundary is where a per-archetype fudge would hide. If one
    ///      archetype got even one extra unit, it would show here and nowhere
    ///      else.
    /// FAILURE MEANS: Some archetype has a quietly different cap.
    function test_RarityHasNoEffectAtThePositionBoundary() public view {
        uint256 cap = (registry.SEED_BALANCE() * 2000) / 10_000; // Balanced: 2000 bps

        TradeProposal memory atCap = _proposal(cap, 100);
        TradeProposal memory overCap = _proposal(cap + 1, 100);

        for (uint256 i = 0; i < 4; i++) {
            (bool approvedAt, RejectReason reasonAt) = engine.validate(tokenIds[i], atCap);
            assertTrue(approvedAt, "at cap should be approved for every archetype");
            assertEq(uint8(reasonAt), uint8(RejectReason.None), "reason at cap");

            (bool approvedOver, RejectReason reasonOver) = engine.validate(tokenIds[i], overCap);
            assertFalse(approvedOver, "cap+1 should be rejected for every archetype");
            assertEq(
                uint8(reasonOver),
                uint8(RejectReason.MaxPositionExceeded),
                "reason at cap+1 differed across archetypes"
            );
        }
    }

    /// WHAT: The mandate, not the archetype, is what changes the limits.
    /// WHY: Confirms the previous tests are not passing because limits are
    ///      static. Limits DO move — they move with the holder's mandate, which
    ///      is the intended and only lever.
    /// FAILURE MEANS: Either limits never change (making the isolation tests
    ///      vacuous) or they change for the wrong reason.
    function test_MandateChangesLimitsWhileArchetypeDoesNot() public {
        // 3000 units exceeds Balanced's 2000 cap for every archetype.
        TradeProposal memory p = _proposal(3000e18, 100);
        for (uint256 i = 0; i < 4; i++) {
            (bool approved, RejectReason reason) = engine.validate(tokenIds[i], p);
            assertFalse(approved, "should exceed Balanced's cap");
            assertEq(uint8(reason), uint8(RejectReason.MaxPositionExceeded), "reason");
        }

        // Each holder raises their own mandate to Tactical (3500 bps). Same
        // proposal now approves — for all four, regardless of archetype.
        for (uint256 i = 0; i < 4; i++) {
            vm.prank(holders[i]);
            registry.setMandate(tokenIds[i], Mandate.Tactical);
        }
        for (uint256 i = 0; i < 4; i++) {
            (bool approved, RejectReason reason) = engine.validate(tokenIds[i], p);
            assertTrue(approved, "Tactical should permit 3000 units");
            assertEq(uint8(reason), uint8(RejectReason.None), "reason");
        }
    }

    /// WHAT: Across randomised proposals, all four archetypes always agree.
    /// WHY: Fuzzing closes the gap a fixed set of cases leaves: any proposal
    ///      shape at all must be judged identically for every archetype.
    /// FAILURE MEANS: Some input exists where rarity changes the verdict.
    function testFuzz_RarityNeverChangesTheVerdict(
        uint256 sizeUnits,
        uint16 slippageBps,
        uint8 rawSide,
        uint256 dataTimestamp
    ) public view {
        TradeProposal memory p = TradeProposal({
            asset: ASSET,
            side: Side(bound(uint256(rawSide), 0, 2)),
            sizeUnits: sizeUnits,
            slippageBps: slippageBps,
            dataTimestamp: dataTimestamp
        });

        (bool firstApproved, RejectReason firstReason) = engine.validate(tokenIds[0], p);
        for (uint256 i = 1; i < 4; i++) {
            (bool approved, RejectReason reason) = engine.validate(tokenIds[i], p);
            assertEq(approved, firstApproved, "approval differed across archetypes");
            assertEq(uint8(reason), uint8(firstReason), "reason differed across archetypes");
        }
    }
}
