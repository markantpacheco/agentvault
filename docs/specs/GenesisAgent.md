# Spec — GenesisAgent.sol

**Status:** Specification. Written before implementation, per the repo
convention. Nothing in this document is deployed.
**Milestone:** 3 of 12
**Last updated:** 2026-09-25

---

## Purpose

`GenesisAgent` is the ERC-721 that acts as the ownership handle for everything
else in the system. Holding token *n* is what makes you the holder of account
*n*, its risk mandate, its permissions, and its performance record.

This milestone builds **only** the token and its permanent archetype. The
isolated account (Milestone 4), the risk mandate (Milestone 5), and session
keys (Milestone 6) attach to it later.

## What this contract is not

- Not the account. Token-bound accounts are Milestone 4, and the ERC-6551
  registry is still `MOCK` (`INTEGRATIONS.md` I3).
- Not a risk setting. The archetype is collectible identity and must never
  influence a financial limit.
- Not a sale. No price, no payment, no allowlist. Minting is free
  (`DECISIONS.md` D6 — the real mint is deferred until there are users and
  counsel has reviewed the sale copy).

---

## Dependencies

| Dependency | Version | How tracked |
|---|---|---|
| `forge-std` | v1.16.2 | git submodule, pinned by commit |
| OpenZeppelin Contracts | see `foundry.lock` | git submodule, pinned by commit |

OpenZeppelin is used for `ERC721` only. Rationale: standard implementations
should not be hand-rolled, and `THREAT-MODEL.md` T7 names "prefer audited
OpenZeppelin" as the mitigation for dependency risk.

**No access-control library, and no privileged role.** This contract has no
owner, no admin, and no role-gated function. Nothing to compromise is the
strongest form of T5 mitigation, and this milestone needs no privileged
operation. A role is added when a milestone actually requires one.

---

## State

| Name | Type | Meaning |
|---|---|---|
| `_archetypeOf` | `mapping(uint256 => Archetype)` | Permanent archetype per token. Written once, at mint. |
| `_hasMinted` | `mapping(address => bool)` | Whether an address has ever minted. Never cleared. |
| `_nextTokenId` | `uint256` | Next id to assign. Initialised to 1. |
| `maxSupply` | `uint256 immutable` | Hard supply cap, set at deploy. Cannot be raised by anyone, ever. |

`_nextTokenId` starts at **1**, never 0, so that an uninitialised token id can
never be mistaken for a real one — the same reasoning that makes
`Archetype.Unassigned` the zero value.

`_hasMinted` is keyed on *ever minted*, not *currently holds*. Gating on
current balance would let a holder transfer their token away and mint again,
without limit.

---

## Interface

### Functions

```solidity
constructor(uint256 maxSupply_);

function mint(Archetype archetype) external returns (uint256 tokenId);
function maxSupply() external view returns (uint256);
function PROTOTYPE_MAX_SUPPLY() external pure returns (uint256);
function archetypeOf(uint256 tokenId) external view returns (Archetype);
function archetypeNameOf(uint256 tokenId) external view returns (string memory);
function hasMinted(address account) external view returns (bool);
function totalMinted() external view returns (uint256);
```

`mint` validates the archetype through `ArchetypeLib.requireValid`, so
`Unassigned` and any out-of-range value are rejected at the boundary before
storage is written.

`archetypeOf` reverts for a token that does not exist rather than returning
`Unassigned`. A silent zero would be indistinguishable from a real unset slot
and could propagate into metadata unnoticed.

### Events

```solidity
event ArchetypeAssigned(uint256 indexed tokenId, address indexed to, Archetype archetype);
```

Emitted once per token, at mint, and never again. Indexers rely on the absence
of any second event for a token as evidence that the archetype is permanent.

### Errors

```solidity
error AlreadyMinted(address account);
error NonexistentToken(uint256 tokenId);
error MaxSupplyReached();
error InvalidMaxSupply();
```

Plus `ArchetypeLib.InvalidArchetype`, raised by `requireValid`. Custom errors,
not revert strings, per the repo convention.

---

## Mint policy — PROTOTYPE

| Parameter | Value | Label |
|---|---|---|
| Price | 0 | PROTOTYPE |
| Supply cap | 10,000 (constructor-set, immutable) | PROTOTYPE |
| Per-address limit | 1 (ever) | PROTOTYPE |
| Who may mint | anyone | PROTOTYPE |

Signed off by the project owner, 2026-09-25. All four are PROTOTYPE values and
are neither audited nor proven. `ROADMAP.md` states supply will be "sized to
actual user count" when the real mint is designed, so 10,000 is a placeholder
for local and testnet work, not a committed production supply. `maxSupply` is
immutable, so the cap cannot be raised after deployment by anyone — including
any privileged role added in a later milestone. A zero cap is rejected at
deploy, since it would produce a permanently unmintable contract.

### The one-per-address limit is not sybil resistance

It is a **courtesy limit** for a faucet-style testnet mint: it spreads the
prototype supply across more than one caller instead of letting a single script
take all of it in one transaction.

It must never be described or relied on as sybil resistance. Addresses are
free — anyone who wants more tokens simply uses more addresses. No part of this
system may assume that one address means one person. The limit keys on *has
ever minted* rather than *currently holds*, which closes the transfer-away-and-
re-mint loop but does nothing about fresh addresses, because nothing can.

See `DECISIONS.md` D10. Production gating is a Phase 8 decision, alongside the
archetype randomness mechanism.

---

## Archetype assignment — current mechanism

The archetype is an explicit parameter to `mint`. The caller names the
archetype they want; the contract validates it and records it permanently.

This is deliberately the simplest mechanism that satisfies every stated
invariant. It is deterministic, has no trusted signer, and introduces no
randomness. Because `D6` defers the real mint, the rarity distribution is
deferred with it rather than guessed at now. In Alpha every minter may choose
the same archetype; that costs nothing while capital is simulated and no
archetype confers any financial advantage.

---

## Invariants

Mapped to `THREAT-MODEL.md` and the prototype acceptance criteria in
`ROADMAP.md`. Each must hold under fuzzing, not only in the happy path.

| # | Invariant | Source |
|---|---|---|
| G1 | Archetype is never writable after mint | Threat model invariant 4 |
| G2 | Minting assigns exactly one archetype | ROADMAP acceptance |
| G3 | `Unassigned` can never be stored as a token's archetype | Enum zero rule |
| G4 | Transfer does not change the archetype | ROADMAP acceptance |
| G5 | Rarity has no effect on any risk limit | Threat model invariant 8 |
| G6 | Token ids are unique and start at 1 | Repo convention |
| G7 | No privileged role can alter an assigned archetype | Threat model T5 |

G5 is partly structural rather than testable inside this contract: there is no
risk limit here to influence. The enforcing test belongs with the risk engine
in Milestone 7. What *is* testable now, and will be: this contract exposes no
function that reads an archetype to produce a numeric limit of any kind.

G7 is satisfied by omission — the contract has no privileged role of any
kind, so there is no actor who could alter an assigned archetype even in
principle.

---

## Transfer semantics

Milestone 3 implements plain ERC-721 transfer and the guarantee that the
archetype survives it unchanged (G4).

The wider transfer behaviour named in `ROADMAP.md` — revoke owner and agent
permissions, pause automation, force Starter Mode, archive the prior owner
period — depends on contracts that do not exist yet. Those hook into the
OpenZeppelin `_update` override in Milestone 6, when there are permissions to
revoke. Documented here so the omission is visible rather than forgotten.

---

## Metadata

`tokenURI` is **not implemented in this milestone.** Metadata hosting is an
external dependency and no URI has been verified, so inventing one would
violate the no-fabrication rule. Before `tokenURI` is added, metadata hosting
gets an `INTEGRATIONS.md` entry with a verification gate, like every other
external dependency.

`archetypeNameOf` exists so that the on-chain archetype name is queryable
without any off-chain service.

---

## Test plan

Every test carries WHAT / WHY / FAILURE MEANS comments, per the repo
convention. Minimum coverage: access control, the failure path, and the
relevant invariant.

| Test | Covers |
|---|---|
| Mint assigns the requested archetype | G2 |
| Mint rejects `Unassigned` | G3 |
| Mint rejects an out-of-range value | G3 |
| First token id is 1 | G6 |
| Token ids are unique across mints | G6 |
| Any address can mint; no privileged minter | Mint policy |
| A second mint from the same address reverts | Mint policy |
| Minting past the supply cap reverts | Supply cap |
| Deploying with a zero cap reverts | Supply cap |
| Deployed cap equals the documented PROTOTYPE value | Supply cap |
| Re-mint after transferring away still reverts | `_hasMinted` semantics |
| `archetypeOf` reverts for a nonexistent token | Silent-zero failure path |
| Archetype is unchanged after transfer | G4, G1 |
| No function exists to set an archetype post-mint | G1, G7 |
| `ArchetypeAssigned` is emitted exactly once per token | G1 evidence |
| Fuzz: archetype in, same archetype out, for any valid input | G1, G2 |
| Fuzz: archetype survives an arbitrary number of transfers | G4 |

Reverting-path tests that call into `ArchetypeLib` need an external wrapper
called via `this.` — `vm.expectRevert` will not match a revert raised at its
own call depth. See the known gotcha in `CLAUDE.md`.

---

## Deferred — do not implement now

**Randomised or rarity-weighted archetype assignment.**

Archetype assignment must **never** derive from block data —
`block.timestamp`, `blockhash`, `block.prevrandao`, or any hash of them.
A caller can read the resulting archetype within the same transaction and
revert if it is unfavourable, so an attacker can retry until a rare archetype
comes out, farming rarity at the cost of gas alone. Block-data randomness is
not merely weak here; it is no constraint at all against a contract caller.

The production mechanism will be verifiable randomness, commit-reveal, or a
pre-committed shuffled assignment. Which one is decided in **Phase 8**, not
now. A matching `TODO(integration)` comment marks the site in
`GenesisAgent.sol`.

**Also deferred:** `tokenURI` and metadata hosting; paid mint; allowlist;
production mint gating; transfer-triggered permission revocation (Milestone 6);
token-bound account creation (Milestone 4).

---

## Open questions

- [ ] Whether `ERC721Enumerable` is needed, or whether indexing off
      `ArchetypeAssigned` is sufficient. Enumerable adds per-transfer gas cost
      for a query the frontend may not need on-chain.
