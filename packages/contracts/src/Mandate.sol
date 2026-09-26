// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title Mandate
/// @notice The holder-selected financial risk setting for an account. This is
///         the counterpart that `Archetype` deliberately is not.
///
/// @dev SAFETY-CRITICAL DESIGN NOTE:
///      A mandate is chosen by the holder and supplies the numeric limits the
///      risk engine validates against. An archetype is permanent collectible
///      identity and supplies nothing. Nothing in this file reads, imports, or
///      infers an archetype, and nothing ever may: a Maverick holder who wants
///      to be cautious must be able to be, and a Guardian holder who wants to
///      be aggressive must be able to be.
///
///      `Unset` is value 0 so an uninitialised storage slot can never be
///      mistaken for a real selection — the same convention as
///      `Archetype.Unassigned`, token ids starting at 1, and `ownerPeriod`.
enum Mandate {
    Unset, // 0 — never a valid selection
    Preservation, // 1
    Balanced, // 2
    Tactical, // 3
    Speculative // 4
}

/// @notice Numeric risk limits for a mandate.
/// @dev Basis points throughout: 10000 bps = 100%. Integers, because Solidity
///      has no floating point and money arithmetic must be exact.
struct MandateParams {
    uint16 maxPositionBps; // max single position, bps of account balance
    uint16 maxSlippageBps; // max acceptable slippage on a fill
    uint16 maxDailyDrawdownBps; // daily loss that pauses new trades
    uint8 maxOpenPositions;
    bool liveEligible; // may this mandate ever execute with real capital
}

/// @title MandateLib
/// @notice Validation, display, and parameter lookup for `Mandate`.
/// @dev A library of `internal pure` functions. They compile into the calling
///      contract, so there is no external call and no extra deployment.
library MandateLib {
    /// @notice Thrown when a mandate value is not one of the four real
    ///         mandates. `Unset` is rejected by this too.
    /// @param provided The rejected numeric value.
    error InvalidMandate(uint8 provided);

    /// @notice Number of selectable mandates. Preservation through Speculative.
    uint8 internal constant MANDATE_COUNT = 4;

    /// @notice Returns true only for the four real mandates.
    /// @dev Explicitly excludes `Unset`. Values above 4 cannot reach here as a
    ///      `Mandate` because Solidity 0.8 reverts on invalid enum
    ///      conversions, but the upper bound is checked anyway so the
    ///      guarantee survives the enum being extended.
    function isValid(Mandate mandate) internal pure returns (bool) {
        uint8 raw = uint8(mandate);
        return raw >= uint8(Mandate.Preservation) && raw <= MANDATE_COUNT;
    }

    /// @notice Reverts unless the mandate is one of the four real mandates.
    /// @dev Use at every entry point accepting a mandate from an external
    ///      caller. Validating at the boundary keeps `Unset` out of storage as
    ///      a selection.
    function requireValid(Mandate mandate) internal pure {
        if (!isValid(mandate)) {
            revert InvalidMandate(uint8(mandate));
        }
    }

    /// @notice Human-readable name, for events and interfaces.
    /// @dev Reverts on `Unset` rather than returning an empty string, because
    ///      a silent empty value could propagate into a display unnoticed.
    function name(Mandate mandate) internal pure returns (string memory) {
        if (mandate == Mandate.Preservation) return "Preservation";
        if (mandate == Mandate.Balanced) return "Balanced";
        if (mandate == Mandate.Tactical) return "Tactical";
        if (mandate == Mandate.Speculative) return "Speculative";
        revert InvalidMandate(uint8(mandate));
    }

    /// @notice Risk limits for a mandate.
    ///
    /// @dev EVERY VALUE BELOW IS **PROTOTYPE**. Not audited, not proven, not
    ///      final. They are starting points for a simulation, not risk
    ///      guidance, and no value here is a claim that any configuration is
    ///      safe or that losses are bounded.
    ///
    ///      | Mandate      | maxPos | maxSlip | maxDD | maxOpen | live  |
    ///      |--------------|--------|---------|-------|---------|-------|
    ///      | Preservation |   1000 |      50 |   300 |       5 | true  |
    ///      | Balanced     |   2000 |     100 |   500 |       8 | true  |
    ///      | Tactical     |   3500 |     200 |  1000 |      12 | true  |
    ///      | Speculative  |   5000 |     300 |  2000 |      20 | false |
    ///
    ///      `Speculative.liveEligible` is FALSE and must stay false. Note
    ///      carefully: nothing in this system has a live-execution path today.
    ///      Everything is simulated. This flag therefore gates a capability
    ///      that DOES NOT YET EXIST, and its presence is not a claim that live
    ///      execution is available or planned to be available. It is here so
    ///      that if such a path is ever built, Speculative cannot reach it by
    ///      default, and so the constraint is enforced by a test rather than
    ///      by somebody remembering.
    ///
    ///      Reverts on `Unset`: there are no parameters for "not chosen", and
    ///      returning a zeroed struct would read as limits of zero rather than
    ///      as a decision nobody has made.
    function paramsOf(Mandate mandate) internal pure returns (MandateParams memory) {
        if (mandate == Mandate.Preservation) {
            return MandateParams({
                maxPositionBps: 1000,
                maxSlippageBps: 50,
                maxDailyDrawdownBps: 300,
                maxOpenPositions: 5,
                liveEligible: true
            });
        }
        if (mandate == Mandate.Balanced) {
            return MandateParams({
                maxPositionBps: 2000,
                maxSlippageBps: 100,
                maxDailyDrawdownBps: 500,
                maxOpenPositions: 8,
                liveEligible: true
            });
        }
        if (mandate == Mandate.Tactical) {
            return MandateParams({
                maxPositionBps: 3500,
                maxSlippageBps: 200,
                maxDailyDrawdownBps: 1000,
                maxOpenPositions: 12,
                liveEligible: true
            });
        }
        if (mandate == Mandate.Speculative) {
            return MandateParams({
                maxPositionBps: 5000,
                maxSlippageBps: 300,
                maxDailyDrawdownBps: 2000,
                maxOpenPositions: 20,
                // Must stay false. See the note above.
                liveEligible: false
            });
        }
        revert InvalidMandate(uint8(mandate));
    }

    /// @notice Ordering of mandates by risk, 1 (lowest) to 4 (highest).
    /// @dev Written as an explicit mapping rather than casting the enum, so
    ///      that reordering the enum cannot silently reorder risk.
    ///
    ///      UNUSED THIS MILESTONE. It exists so a future cooling-off rule can
    ///      tell raising risk from lowering it without re-deriving an
    ///      ordering. See the deferred note in docs/specs/Mandate.md.
    function riskRank(Mandate mandate) internal pure returns (uint8) {
        if (mandate == Mandate.Preservation) return 1;
        if (mandate == Mandate.Balanced) return 2;
        if (mandate == Mandate.Tactical) return 3;
        if (mandate == Mandate.Speculative) return 4;
        revert InvalidMandate(uint8(mandate));
    }
}
