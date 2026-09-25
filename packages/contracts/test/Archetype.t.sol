// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {Archetype, ArchetypeLib} from "../src/Archetype.sol";

/// @title ArchetypeTest
/// @notice Tests for the archetype type and its validation rules.
/// @dev Foundry runs every function whose name starts with `test`. A test
///      passes if it does not revert. Functions starting with `testFuzz`
///      are run many times with random inputs.
contract ArchetypeTest is Test {
    using ArchetypeLib for Archetype;

    /// WHAT: All four archetypes are accepted as valid.
    /// WHY: If any real archetype were rejected, legitimate NFTs could not be
    ///      minted with that identity.
    /// FAILURE MEANS: The validation bounds are wrong.
    function test_AllFourArchetypesAreValid() public pure {
        assertTrue(ArchetypeLib.isValid(Archetype.Guardian), "Guardian invalid");
        assertTrue(ArchetypeLib.isValid(Archetype.Navigator), "Navigator invalid");
        assertTrue(ArchetypeLib.isValid(Archetype.Tactician), "Tactician invalid");
        assertTrue(ArchetypeLib.isValid(Archetype.Maverick), "Maverick invalid");
    }

    /// WHAT: The zero value is never treated as a real archetype.
    /// WHY: Uninitialized storage in Solidity reads as zero. If zero were
    ///      valid, an NFT that was never properly assigned would silently
    ///      appear to be a Guardian.
    /// FAILURE MEANS: Unassigned NFTs could masquerade as assigned ones.
    function test_UnassignedIsNotValid() public pure {
        assertFalse(ArchetypeLib.isValid(Archetype.Unassigned), "Unassigned accepted");
    }

    /// WHAT: requireValid reverts on the unassigned value, with the right error.
    /// WHY: Boundary validation must fail loudly, not silently pass through.
    /// FAILURE MEANS: Invalid archetypes could be written to storage.
    /// @dev Goes through the external wrapper because `requireValid` is `internal`
    ///      and inlines into this contract, so a direct call would revert at the
    ///      same depth as the cheatcode and `vm.expectRevert` would not match it.
    function test_RequireValidRevertsOnUnassigned() public {
        vm.expectRevert(abi.encodeWithSelector(ArchetypeLib.InvalidArchetype.selector, uint8(0)));
        this.requireValidExternal(Archetype.Unassigned);
    }

    /// WHAT: requireValid accepts every real archetype without reverting.
    /// WHY: Confirms the guard does not block legitimate values.
    /// FAILURE MEANS: Minting would be broken for some archetypes.
    function test_RequireValidAcceptsRealArchetypes() public pure {
        ArchetypeLib.requireValid(Archetype.Guardian);
        ArchetypeLib.requireValid(Archetype.Navigator);
        ArchetypeLib.requireValid(Archetype.Tactician);
        ArchetypeLib.requireValid(Archetype.Maverick);
    }

    /// WHAT: Display names match the product specification exactly.
    /// WHY: These strings surface in NFT metadata and the user interface. A
    ///      mismatch is permanently baked into minted metadata.
    /// FAILURE MEANS: Marketplaces would show the wrong archetype name.
    function test_NamesMatchSpecification() public pure {
        assertEq(ArchetypeLib.name(Archetype.Guardian), "Guardian");
        assertEq(ArchetypeLib.name(Archetype.Navigator), "Navigator");
        assertEq(ArchetypeLib.name(Archetype.Tactician), "Tactician");
        assertEq(ArchetypeLib.name(Archetype.Maverick), "Maverick");
    }

    /// WHAT: name() reverts rather than returning an empty string for zero.
    /// WHY: An empty name written into metadata would be a silent data bug.
    /// FAILURE MEANS: Corrupt metadata could ship unnoticed.
    /// @dev Goes through the external wrapper because `name` is `internal` and
    ///      inlines into this contract, so a direct call would revert at the same
    ///      depth as the cheatcode and `vm.expectRevert` would not match it.
    function test_NameRevertsOnUnassigned() public {
        vm.expectRevert(abi.encodeWithSelector(ArchetypeLib.InvalidArchetype.selector, uint8(0)));
        this.nameExternal(Archetype.Unassigned);
    }

    /// WHAT: Across many random inputs, exactly the nonzero values are valid.
    /// WHY: Fuzzing checks the rule holds generally, not just for the cases a
    ///      human happened to write down.
    /// FAILURE MEANS: An edge case exists where validation disagrees with the
    ///      intended rule.
    /// @dev `bound` maps any random uint8 into 0..4. Casting a value above 4
    ///      to this enum would revert at the language level, so the fuzzer is
    ///      constrained to the representable range.
    function testFuzz_OnlyNonzeroValuesAreValid(uint8 raw) public pure {
        uint8 bounded = uint8(bound(uint256(raw), 0, uint256(ArchetypeLib.ARCHETYPE_COUNT)));
        Archetype archetype = Archetype(bounded);
        assertEq(ArchetypeLib.isValid(archetype), bounded != 0, "validity rule broken");
    }

    // -----------------------------------------------------------------------
    // External wrappers
    //
    // `ArchetypeLib` is a library of `internal` functions, which compile into
    // the caller. A revert therefore happens at the same call depth as the
    // `vm.expectRevert` cheatcode, and Foundry refuses to match it. Calling
    // these wrappers via `this.` adds the external boundary the cheatcode
    // needs; custom error data propagates through it intact.
    // -----------------------------------------------------------------------

    /// @dev External boundary for ArchetypeLib.requireValid. Tests only.
    function requireValidExternal(Archetype archetype) external pure {
        ArchetypeLib.requireValid(archetype);
    }

    /// @dev External boundary for ArchetypeLib.name. Tests only.
    function nameExternal(Archetype archetype) external pure returns (string memory) {
        return ArchetypeLib.name(archetype);
    }
}
