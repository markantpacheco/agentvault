// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Archetype, ArchetypeLib} from "./Archetype.sol";

/// @title GenesisAgent
/// @notice The ERC-721 that acts as the ownership handle for an AgentVault
///         account. Holding token `n` is what makes you the holder of account
///         `n`, its risk mandate, its permissions, and its performance record.
///
/// @dev SCOPE: This contract is the token and its permanent archetype, and
///      nothing else. The isolated account is Milestone 4, the risk mandate is
///      Milestone 5, and session keys are Milestone 6. See
///      docs/specs/GenesisAgent.md.
///
///      SAFETY-CRITICAL DESIGN NOTE:
///      The archetype is collectible identity. It MUST NOT control, imply, or
///      modify any financial risk limit. There is deliberately no function
///      here that reads an archetype and returns a numeric limit of any kind.
///      Financial risk lives in the holder-selected mandate, in a separate
///      contract.
///
///      This contract has NO owner, NO admin, and NO role-gated function.
///      That is intentional: a privileged role that does not exist cannot be
///      compromised, and this milestone needs no privileged operation.
contract GenesisAgent is ERC721 {
    /// @notice Thrown when an address that has already minted tries again.
    /// @param account The rejected caller.
    error AlreadyMinted(address account);

    /// @notice Thrown when a query names a token that has never been minted.
    /// @dev Reverting is deliberate. Returning `Archetype.Unassigned` would be
    ///      indistinguishable from a real unset slot and could propagate into
    ///      metadata unnoticed.
    /// @param tokenId The token that does not exist.
    error NonexistentToken(uint256 tokenId);

    /// @notice Emitted exactly once per token, at mint, and never again.
    /// @dev The absence of any second event for a token is the on-chain
    ///      evidence that its archetype is permanent. No code path emits this
    ///      outside `mint`.
    event ArchetypeAssigned(uint256 indexed tokenId, address indexed to, Archetype archetype);

    /// @dev Permanent archetype per token. Written once, in `mint`, and by no
    ///      other code path in this contract.
    mapping(uint256 => Archetype) private _archetypeOf;

    /// @dev Whether an address has EVER minted. Never cleared. Gating on
    ///      current balance instead would let a holder transfer their token
    ///      away and mint again, without limit.
    mapping(address => bool) private _hasMinted;

    /// @dev Next id to assign. Starts at 1 so that an uninitialised token id
    ///      can never be mistaken for a real one — the same reasoning that
    ///      makes `Archetype.Unassigned` the zero value.
    uint256 private _nextTokenId = 1;

    constructor() ERC721("AgentVault Genesis Agent", "AGENT") {}

    /// @notice Mint one Genesis Agent with a permanent archetype.
    /// @dev PROTOTYPE mint policy, not audited and not proven: free, no supply
    ///      cap, one per address ever, anyone may call. Sybil minting is
    ///      possible and accepted — with simulated capital and no payment
    ///      there is nothing to gain. See docs/specs/GenesisAgent.md.
    /// @param archetype The archetype to assign permanently. Validated at the
    ///        boundary, so `Unassigned` can never reach storage.
    /// @return tokenId The id of the newly minted token.
    function mint(Archetype archetype) external returns (uint256 tokenId) {
        // TODO(integration): the archetype is currently named by the caller.
        // If this is ever replaced by randomised or rarity-weighted
        // assignment, the mechanism MUST NOT derive from block data —
        // block.timestamp, blockhash, block.prevrandao, or any hash of them.
        // A contract caller can read the resulting archetype within the same
        // transaction and revert when it is unfavourable, retrying until a
        // rare archetype comes out and farming rarity for the cost of gas
        // alone. Against a contract caller, block-data randomness is not a
        // weak constraint; it is no constraint. The production mechanism will
        // be verifiable randomness, commit-reveal, or a pre-committed shuffled
        // assignment, decided in Phase 8.
        ArchetypeLib.requireValid(archetype);

        if (_hasMinted[msg.sender]) {
            revert AlreadyMinted(msg.sender);
        }

        // Every state change and the event are completed BEFORE `_safeMint`,
        // which makes an external call into the receiver. Checks, effects,
        // then interactions.
        _hasMinted[msg.sender] = true;
        tokenId = _nextTokenId++;
        _archetypeOf[tokenId] = archetype;
        emit ArchetypeAssigned(tokenId, msg.sender, archetype);

        _safeMint(msg.sender, tokenId);
    }

    /// @notice The permanent archetype of a minted token.
    /// @dev Reverts for a token that does not exist rather than returning the
    ///      zero value. See `NonexistentToken`.
    function archetypeOf(uint256 tokenId) external view returns (Archetype) {
        _requireMinted(tokenId);
        return _archetypeOf[tokenId];
    }

    /// @notice Human-readable archetype name, queryable without any off-chain
    ///         service.
    /// @dev `tokenURI` is deliberately not implemented in this milestone:
    ///      metadata hosting is an unverified external dependency and
    ///      inventing a URI would violate the project's no-fabrication rule.
    function archetypeNameOf(uint256 tokenId) external view returns (string memory) {
        _requireMinted(tokenId);
        return ArchetypeLib.name(_archetypeOf[tokenId]);
    }

    /// @notice Whether an address has ever minted.
    function hasMinted(address account) external view returns (bool) {
        return _hasMinted[account];
    }

    /// @notice Total tokens minted so far. Ids run 1..totalMinted().
    function totalMinted() external view returns (uint256) {
        return _nextTokenId - 1;
    }

    /// @dev Reverts unless `tokenId` has been minted.
    function _requireMinted(uint256 tokenId) private view {
        if (_ownerOf(tokenId) == address(0)) {
            revert NonexistentToken(tokenId);
        }
    }

    // -----------------------------------------------------------------------
    // Transfer behaviour deferred to later milestones
    //
    // This milestone implements plain ERC-721 transfer plus the guarantee that
    // the archetype survives it unchanged — which holds automatically, because
    // no code path writes `_archetypeOf` after mint.
    //
    // The wider transfer behaviour the roadmap requires — revoke owner and
    // agent permissions, pause automation, force Starter Mode, archive the
    // prior owner period — depends on contracts that do not exist yet. Those
    // hook into an `_update` override here in Milestone 6, when there are
    // permissions to revoke. Noted so the omission stays visible.
    // -----------------------------------------------------------------------
}
