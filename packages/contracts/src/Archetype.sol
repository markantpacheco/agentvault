// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title Archetype
/// @notice The permanent collectible identity assigned to a Genesis Agent NFT
///         at mint. An archetype influences artwork, included strategies, and
///         product perks.
///
/// @dev SAFETY-CRITICAL DESIGN NOTE:
///      An archetype MUST NOT control, imply, or modify any financial risk
///      limit. Financial risk is governed exclusively by the holder-selected
///      risk mandate, which lives in a separate registry and can be changed by
///      the holder. Keeping these in separate files is intentional: it makes
///      accidental coupling visible in code review.
///
///      `Unassigned` is value 0 so that an uninitialized storage slot can
///      never be mistaken for a real archetype. In Solidity, unset storage
///      reads as zero, so the zero value must always mean "not set".
enum Archetype {
    Unassigned, // 0 — never a valid assigned archetype
    Guardian, // 1 — defensive, patient, capital-conscious
    Navigator, // 2 — analytical, adaptive, data-driven
    Tactician, // 3 — active, disciplined, execution-focused
    Maverick // 4 — experimental, volatility-focused
}

/// @title ArchetypeLib
/// @notice Validation and display helpers for the Archetype enum.
/// @dev A library of `internal pure` functions. These compile directly into
///      the calling contract, so there is no external call and no extra
///      deployment. `pure` means the function reads no state and can never
///      modify anything.
library ArchetypeLib {
    /// @notice Thrown when an archetype value is not one of the four valid
    ///         archetypes. Custom errors cost less gas than revert strings and
    ///         let callers detect the specific failure.
    /// @param provided The rejected numeric value.
    error InvalidArchetype(uint8 provided);

    /// @notice Number of assignable archetypes. Guardian through Maverick.
    uint8 internal constant ARCHETYPE_COUNT = 4;

    /// @notice Returns true only for the four real archetypes.
    /// @dev Explicitly excludes `Unassigned`. Values above 4 cannot reach this
    ///      function as an `Archetype` because Solidity 0.8 reverts on invalid
    ///      enum conversions, but the upper bound is checked anyway so that the
    ///      guarantee holds even if the enum is extended in future.
    function isValid(Archetype archetype) internal pure returns (bool) {
        uint8 raw = uint8(archetype);
        return raw >= uint8(Archetype.Guardian) && raw <= ARCHETYPE_COUNT;
    }

    /// @notice Reverts unless the archetype is one of the four valid values.
    /// @dev Use this at every entry point that accepts an archetype from an
    ///      external caller. Validating at the boundary keeps invalid state
    ///      from ever being written.
    function requireValid(Archetype archetype) internal pure {
        if (!isValid(archetype)) {
            revert InvalidArchetype(uint8(archetype));
        }
    }

    /// @notice Human-readable name, for metadata and events.
    /// @dev Reverts on invalid input rather than returning an empty string,
    ///      because a silent empty value could propagate into NFT metadata
    ///      unnoticed.
    function name(Archetype archetype) internal pure returns (string memory) {
        if (archetype == Archetype.Guardian) return "Guardian";
        if (archetype == Archetype.Navigator) return "Navigator";
        if (archetype == Archetype.Tactician) return "Tactician";
        if (archetype == Archetype.Maverick) return "Maverick";
        revert InvalidArchetype(uint8(archetype));
    }
}
