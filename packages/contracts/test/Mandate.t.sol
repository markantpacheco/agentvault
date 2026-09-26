// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {Mandate, MandateLib, MandateParams} from "../src/Mandate.sol";

/// @title MandateTest
/// @notice Tests for the risk mandate type, its validation, and its PROTOTYPE
///         parameter table.
/// @dev Invariant ids refer to docs/specs/Mandate.md. Nothing in this file
///      imports or references an archetype, which is the point.
contract MandateTest is Test {
    /// WHAT: All four mandates are valid and the zero value is not.
    /// WHY: If a real mandate were rejected, a holder could not select it. If
    ///      `Unset` were accepted, an account that never chose a risk level
    ///      would silently appear to have chosen the lowest one.
    /// FAILURE MEANS: Validation bounds are wrong. Invariant 1.
    function test_AllFourMandatesAreValidAndUnsetIsNot() public pure {
        assertTrue(MandateLib.isValid(Mandate.Preservation), "Preservation invalid");
        assertTrue(MandateLib.isValid(Mandate.Balanced), "Balanced invalid");
        assertTrue(MandateLib.isValid(Mandate.Tactical), "Tactical invalid");
        assertTrue(MandateLib.isValid(Mandate.Speculative), "Speculative invalid");
        assertFalse(MandateLib.isValid(Mandate.Unset), "Unset accepted");
    }

    /// WHAT: requireValid reverts on `Unset` with the right error and value.
    /// WHY: Boundary validation must fail loudly, not pass through silently.
    /// FAILURE MEANS: `Unset` could be written to storage as a selection.
    /// @dev Routed through the external wrapper: `requireValid` is `internal`
    ///      and inlines here, so a direct call would revert at the same depth
    ///      as the cheatcode and `vm.expectRevert` would not match it.
    function test_RequireValidRevertsOnUnset() public {
        vm.expectRevert(abi.encodeWithSelector(MandateLib.InvalidMandate.selector, uint8(0)));
        this.requireValidExternal(Mandate.Unset);
    }

    /// WHAT: Display names match the specification exactly.
    /// WHY: These strings surface in events and interfaces. A mismatch
    ///      misreports which risk level a holder chose.
    /// FAILURE MEANS: A holder's risk setting is displayed as the wrong one.
    function test_NamesMatchSpecification() public pure {
        assertEq(MandateLib.name(Mandate.Preservation), "Preservation");
        assertEq(MandateLib.name(Mandate.Balanced), "Balanced");
        assertEq(MandateLib.name(Mandate.Tactical), "Tactical");
        assertEq(MandateLib.name(Mandate.Speculative), "Speculative");
    }

    /// WHAT: paramsOf returns exactly the documented PROTOTYPE table.
    /// WHY: These are the numbers the risk engine will validate against in a
    ///      later milestone. If the code and the documented table disagree,
    ///      the documentation stops describing the system.
    /// FAILURE MEANS: Limits enforced differ from limits published.
    function test_ParamsMatchPrototypeTable() public pure {
        MandateParams memory p = MandateLib.paramsOf(Mandate.Preservation);
        assertEq(p.maxPositionBps, 1000, "Preservation maxPositionBps");
        assertEq(p.maxSlippageBps, 50, "Preservation maxSlippageBps");
        assertEq(p.maxDailyDrawdownBps, 300, "Preservation maxDailyDrawdownBps");
        assertEq(p.maxOpenPositions, 5, "Preservation maxOpenPositions");

        p = MandateLib.paramsOf(Mandate.Balanced);
        assertEq(p.maxPositionBps, 2000, "Balanced maxPositionBps");
        assertEq(p.maxSlippageBps, 100, "Balanced maxSlippageBps");
        assertEq(p.maxDailyDrawdownBps, 500, "Balanced maxDailyDrawdownBps");
        assertEq(p.maxOpenPositions, 8, "Balanced maxOpenPositions");

        p = MandateLib.paramsOf(Mandate.Tactical);
        assertEq(p.maxPositionBps, 3500, "Tactical maxPositionBps");
        assertEq(p.maxSlippageBps, 200, "Tactical maxSlippageBps");
        assertEq(p.maxDailyDrawdownBps, 1000, "Tactical maxDailyDrawdownBps");
        assertEq(p.maxOpenPositions, 12, "Tactical maxOpenPositions");

        p = MandateLib.paramsOf(Mandate.Speculative);
        assertEq(p.maxPositionBps, 5000, "Speculative maxPositionBps");
        assertEq(p.maxSlippageBps, 300, "Speculative maxSlippageBps");
        assertEq(p.maxDailyDrawdownBps, 2000, "Speculative maxDailyDrawdownBps");
        assertEq(p.maxOpenPositions, 20, "Speculative maxOpenPositions");
    }

    /// WHAT: paramsOf reverts on `Unset` rather than returning zeros.
    /// WHY: A zeroed struct would read as limits of zero — a real, extremely
    ///      restrictive configuration — rather than as a decision nobody made.
    /// FAILURE MEANS: "No mandate chosen" is indistinguishable from "all
    ///      limits are zero", and callers cannot tell which they got.
    function test_ParamsOfRevertsOnUnset() public {
        vm.expectRevert(abi.encodeWithSelector(MandateLib.InvalidMandate.selector, uint8(0)));
        this.paramsOfExternal(Mandate.Unset);
    }

    /// WHAT: Speculative is not live-eligible.
    /// WHY: CLAUDE.md rule 8 — the Speculative mandate has no live-execution
    ///      code path, enforced by test rather than by remembering. Note that
    ///      NO mandate has a live path today; everything is simulated. This
    ///      flag gates a capability that does not yet exist, so that if one is
    ///      ever built, Speculative cannot reach it by default.
    /// FAILURE MEANS: The one mandate explicitly excluded from live capital is
    ///      no longer excluded. Invariant 2.
    function test_SpeculativeIsNotLiveEligible() public pure {
        assertFalse(
            MandateLib.paramsOf(Mandate.Speculative).liveEligible, "Speculative is live-eligible"
        );
    }

    /// WHAT: The other three mandates are flagged live-eligible.
    /// WHY: Confirms the flag distinguishes mandates rather than being false
    ///      everywhere, which would make the Speculative test vacuous.
    /// FAILURE MEANS: The Speculative assertion proves nothing.
    function test_OtherThreeAreLiveEligible() public pure {
        assertTrue(MandateLib.paramsOf(Mandate.Preservation).liveEligible, "Preservation");
        assertTrue(MandateLib.paramsOf(Mandate.Balanced).liveEligible, "Balanced");
        assertTrue(MandateLib.paramsOf(Mandate.Tactical).liveEligible, "Tactical");
    }

    /// WHAT: riskRank strictly increases across Preservation to Speculative.
    /// WHY: A future cooling-off rule will use this to tell raising risk from
    ///      lowering it. A non-monotonic ordering would let a holder raise
    ///      risk while appearing to lower it.
    /// FAILURE MEANS: Risk ordering is wrong, and any rule built on it is too.
    ///      Invariant 3.
    function test_RiskRankIsStrictlyIncreasing() public pure {
        uint8 preservation = MandateLib.riskRank(Mandate.Preservation);
        uint8 balanced = MandateLib.riskRank(Mandate.Balanced);
        uint8 tactical = MandateLib.riskRank(Mandate.Tactical);
        uint8 speculative = MandateLib.riskRank(Mandate.Speculative);

        assertEq(preservation, 1, "Preservation rank");
        assertLt(preservation, balanced, "Preservation !< Balanced");
        assertLt(balanced, tactical, "Balanced !< Tactical");
        assertLt(tactical, speculative, "Tactical !< Speculative");
        assertEq(speculative, MandateLib.MANDATE_COUNT, "Speculative should be the highest rank");
    }

    /// WHAT: riskRank reverts on `Unset`.
    /// WHY: There is no risk ordering for a decision nobody made, and
    ///      returning 0 would place it below Preservation as if it were the
    ///      safest possible setting.
    /// FAILURE MEANS: An unchosen mandate ranks as safer than every real one.
    function test_RiskRankRevertsOnUnset() public {
        vm.expectRevert(abi.encodeWithSelector(MandateLib.InvalidMandate.selector, uint8(0)));
        this.riskRankExternal(Mandate.Unset);
    }

    /// WHAT: Across many random inputs, exactly the nonzero values are valid.
    /// WHY: Fuzzing checks the rule generally, not only for the cases a human
    ///      wrote down.
    /// FAILURE MEANS: An edge case exists where validation disagrees with the
    ///      intended rule.
    /// @dev `bound` maps any random uint8 into 0..4. A value above 4 would
    ///      revert at the language level on the enum conversion, so the fuzzer
    ///      is constrained to the representable range.
    function testFuzz_OnlyNonzeroValuesAreValid(uint8 raw) public pure {
        uint8 bounded = uint8(bound(uint256(raw), 0, uint256(MandateLib.MANDATE_COUNT)));
        Mandate mandate = Mandate(bounded);
        assertEq(MandateLib.isValid(mandate), bounded != 0, "validity rule broken");
    }

    // -----------------------------------------------------------------------
    // External wrappers
    //
    // `MandateLib` is a library of `internal` functions, which compile into
    // the caller. A revert therefore happens at the same call depth as the
    // `vm.expectRevert` cheatcode, and Foundry refuses to match it. Calling
    // these via `this.` adds the external boundary the cheatcode needs;
    // custom error data propagates through it intact.
    // -----------------------------------------------------------------------

    /// @dev External boundary for MandateLib.requireValid. Tests only.
    function requireValidExternal(Mandate mandate) external pure {
        MandateLib.requireValid(mandate);
    }

    /// @dev External boundary for MandateLib.paramsOf. Tests only.
    function paramsOfExternal(Mandate mandate) external pure returns (MandateParams memory) {
        return MandateLib.paramsOf(mandate);
    }

    /// @dev External boundary for MandateLib.riskRank. Tests only.
    function riskRankExternal(Mandate mandate) external pure returns (uint8) {
        return MandateLib.riskRank(mandate);
    }
}
