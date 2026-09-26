# Specification — Mandate (Milestone 5)

**Status:** specification, not yet implemented
**Target paths:**
- `packages/contracts/src/Mandate.sol` (new)
- `packages/contracts/src/AccountRegistry.sol` (modified)
**Test paths:**
- `packages/contracts/test/Mandate.t.sol` (new)
- `packages/contracts/test/AccountRegistry.t.sol` (extended)

---

## Purpose

The risk mandate is the holder's financial risk setting: the counterpart the
archetype deliberately is not. It supplies the numeric limits the risk engine
validates against in Milestone 6.

## Why a library plus a struct field, not a fifth contract

Mandate **selection** is per-account state, and `AccountRegistry` already owns
per-account state including the transfer-reset path. Mandate **parameters**
are constants, which belong in a pure library.

Splitting it that way means no new stateful contract, no extra cross-contract
call in the risk engine's hot path, and mandate clearing on transfer costs
nothing because `_requireOwnerAndSync` already runs everywhere. It also
mirrors the `Archetype` / `ArchetypeLib` pattern already in the repo, so the
codebase stays internally consistent.

---

## Part 1 — `Mandate.sol`

### Enum

```solidity
enum Mandate {
    Unset,         // 0 — never a valid selection
    Preservation,  // 1
    Balanced,      // 2
    Tactical,      // 3
    Speculative    // 4
}
```

Zero means unset, same convention as `Archetype.Unassigned`, token IDs, and
`ownerPeriod`.

### Parameter struct

```solidity
struct MandateParams {
    uint16 maxPositionBps;      // max single position, bps of account balance
    uint16 maxSlippageBps;      // max acceptable slippage on a fill
    uint16 maxDailyDrawdownBps; // daily loss that pauses new trades
    uint8  maxOpenPositions;
    bool   liveEligible;        // may this mandate ever execute with real capital
}
```

Basis points throughout — 10000 bps = 100%. Integers avoid floating point,
which Solidity does not have.

### PROTOTYPE parameter table

**These values are PROTOTYPE. Not audited, not proven, not final. They are
starting points for a simulation, not risk guidance.** State this in a comment
directly above the table.

| Mandate | maxPositionBps | maxSlippageBps | maxDailyDrawdownBps | maxOpenPositions | liveEligible |
|---|---|---|---|---|---|
| Preservation | 1000 (10%) | 50 (0.5%) | 300 (3%) | 5 | true |
| Balanced | 2000 (20%) | 100 (1%) | 500 (5%) | 8 | true |
| Tactical | 3500 (35%) | 200 (2%) | 1000 (10%) | 12 | true |
| Speculative | 5000 (50%) | 300 (3%) | 2000 (20%) | 20 | **false** |

`Speculative.liveEligible` is `false` and must stay false. Nothing in the
system has a live-execution path today — everything is simulated — so this
flag gates a capability that does not yet exist. It is here so that when one
does, Speculative cannot reach it by default, and so the constraint is
enforced by a test rather than by remembering. Add a comment saying exactly
that, so nobody later reads the flag as a claim that live execution exists.

### Library functions

All `internal pure`, in `library MandateLib`:

```
isValid(Mandate) returns (bool)          // nonzero and <= MANDATE_COUNT
requireValid(Mandate)                     // reverts InvalidMandate(uint8)
name(Mandate) returns (string memory)     // reverts on Unset
paramsOf(Mandate) returns (MandateParams memory)  // reverts on Unset
riskRank(Mandate) returns (uint8)         // 1..4, strictly increasing
```

`riskRank` exists so a future cooling-off rule can distinguish raising risk
from lowering it without re-deriving an ordering. It is unused this milestone.

### Error

```solidity
error InvalidMandate(uint8 provided);
```

### Testing note

`requireValid`, `name`, and `paramsOf` are `internal` and revert, so their
revert tests need external wrappers called via `this.` — the call-depth
gotcha in `CLAUDE.md`.

---

## Part 2 — `AccountRegistry.sol` changes

### Struct

Add one field:

```solidity
Mandate mandate;
```

### Creation

An account is created with `mandate = Mandate.Unset`. The holder chooses
deliberately; nothing selects a risk level on their behalf.

### New function

```solidity
function setMandate(uint256 tokenId, Mandate newMandate) external
```

- `_requireOwnerAndSync` first, as every state-changing function does
- `MandateLib.requireValid(newMandate)` — selecting `Unset` reverts
- Set the field
- Emit `MandateSelected(tokenId, newMandate, ownerPeriod)`

Including `ownerPeriod` in the event means an indexer can attribute a mandate
choice to the holder who made it, which matters once performance history is
segmented by owner period.

### Transfer reset

In `_requireOwnerAndSync`, where a detected transfer already pauses automation
and increments `ownerPeriod`, also set `mandate = Mandate.Unset`.

This is Starter Mode. The new holder inherits a paused account with no risk
setting and must choose one before anything can run. Resetting to `Unset`
rather than to `Preservation` is deliberate — defaulting someone into a risk
level they never picked is the thing this whole separation exists to prevent.

### New views

```solidity
function mandateOf(uint256 tokenId) external view returns (Mandate)
function mandateParamsOf(uint256 tokenId) external view returns (MandateParams memory)
```

Both revert `AccountDoesNotExist` for an account that was never created.
`mandateParamsOf` reverts `InvalidMandate(0)` when the mandate is `Unset` —
there are no parameters for "not chosen," and returning a zeroed struct would
read as limits of zero rather than as an unmade decision.

### New event

```solidity
event MandateSelected(uint256 indexed tokenId, Mandate mandate, uint32 ownerPeriod);
```

---

## Invariants

1. `Mandate.Unset` is never a valid selection
2. `Speculative.liveEligible` is `false`
3. `riskRank` is strictly increasing across Preservation → Speculative
4. Only the current NFT holder can set a mandate
5. Transfer resets the mandate to `Unset`
6. A mandate is never set by any party other than the holder — no default, no
   inference from archetype, no protocol assignment
7. No function in `Mandate.sol` or the mandate paths of `AccountRegistry`
   reads an archetype

Invariant 6 is the one that matters for the product. The whole point of
separating collectible identity from financial risk is that a Maverick holder
who wants to be cautious can be, and a Guardian holder who wants to be
aggressive can be. Any code path that infers one from the other breaks it.

---

## Tests

WHAT / WHY / FAILURE MEANS on every test, as established.

### `Mandate.t.sol`

1. All four mandates are valid; `Unset` is not
2. `requireValid` reverts `InvalidMandate(0)` on `Unset` (external wrapper)
3. Names match the specification exactly
4. `paramsOf` returns the documented table values for each of the four
5. `paramsOf` reverts on `Unset`
6. **`Speculative.liveEligible` is false** — the simulation-only guarantee
7. The other three are `liveEligible`
8. `riskRank` is strictly increasing across all four
9. Fuzz: any value bounded 1..4 round-trips through `isValid` as true, 0 as
   false

### `AccountRegistry.t.sol` additions

10. A new account starts with `mandate == Unset`
11. The holder can set each of the four mandates
12. `setMandate` emits `MandateSelected` with the correct `ownerPeriod`
13. Setting `Unset` reverts `InvalidMandate(0)`
14. A non-holder cannot set a mandate — reverts `NotTokenOwner`
15. A previous holder cannot set a mandate after transfer
16. **Transfer resets the mandate to `Unset`** — Starter Mode
17. After transfer the new holder can select their own mandate, and
    `ownerPeriod` in the event reflects the new period
18. `mandateParamsOf` returns the table values matching the selected mandate
19. `mandateParamsOf` reverts when the mandate is `Unset`
20. `mandateOf` and `mandateParamsOf` revert for a nonexistent account
21. Setting a mandate on account A does not change account B's mandate
22. Changing the mandate does not alter balance, `depositedTotal`,
    `withdrawnTotal`, or PnL

Test 22 guards a subtle coupling: risk settings and financial state are
independent, and changing one must never silently touch the other.

---

## Deferred — do not implement now

**Cooling-off on raising risk.** Lowering a mandate's risk should take effect
immediately; raising it should wait. `riskRank` exists to support that
comparison. Deferred because it appears nowhere in the demo and time-based
tests cost hours this sprint does not have. Record it in `DECISIONS.md` with
that reasoning so it reads as a scheduling choice, not an oversight.

**Strategy registry and mandate–strategy compatibility.** No strategies exist.
A registry of nothing is ceremony. When strategies arrive, compatibility
checking belongs in the risk engine, not here.

**Archetype-suggested mandates.** An archetype may one day *recommend* a
mandate family in the UI. It must never set, constrain, or default one in the
contracts. If this is ever built, it lives in the frontend.

---

## Acceptance criteria

- [ ] `forge build`, no warnings
- [ ] `forge test -vv` — all existing tests still pass, plus the new ones
- [ ] `forge fmt --check` clean
- [ ] `Speculative.liveEligible == false`, asserted by a named test
- [ ] No archetype is read anywhere in a mandate code path
- [ ] No default mandate is ever assigned by the protocol
- [ ] Transfer resets the mandate, asserted by a named test
- [ ] Every PROTOTYPE value is labelled as such in a comment
- [ ] Every test carries WHAT / WHY / FAILURE MEANS
