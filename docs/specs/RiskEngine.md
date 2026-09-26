# Specification — RiskEngine.sol

**Status:** specification, not yet implemented
**Target paths:**
- `packages/contracts/src/RiskEngine.sol` (new)
- `packages/contracts/src/interfaces/IAccountRegistry.sol` (new)
- `packages/contracts/script/Demo.s.sol` (new)
**Test path:** `packages/contracts/test/RiskEngine.t.sol`

---

## Purpose

The deterministic authority that approves or rejects every proposed trade.
This is the contract the entire product rests on: **the AI proposes, this
decides.**

It is also the demo. Ninety seconds of someone watching a valid trade get
approved, an oversized one get rejected by name, and then the *same valid
trade* get rejected because the holder flipped a switch the agent cannot
reach.

## Shape — a pure view validator

```solidity
function validate(uint256 tokenId, TradeProposal calldata proposal)
    external view returns (bool approved, RejectReason reason)
```

No storage writes. No access control. No pause. No admin.

Anyone may call it because calling it changes nothing. That is not laziness —
it is the strongest available guarantee. A validator with no state cannot be
corrupted, cannot be paused by anyone, cannot drift, and cannot be gamed by
reordering calls. Whoever is *allowed to act on* an approval is a separate
question that belongs with execution, and execution is not in this milestone.

---

## Dependencies

Depend on an interface, not the concrete registry — the same reasoning that
kept `AccountRegistry` on `IERC721`.

Create `src/interfaces/IAccountRegistry.sol` declaring only what the engine
uses. Reconcile the exact signatures against the committed `AccountRegistry`;
the engine needs, in substance:

- whether an account exists
- the account's current balance
- the effective automation-paused state
- the selected mandate
- the mandate's parameters

**Use the effective-state views, never raw storage.** `isAutomationPaused`
and `mandateOf` already apply the pending-transfer transformation through
`_effectiveAccount`. If the engine reached around those, a sold account could
be validated against its previous holder's risk appetite during the window
before sync. That window is exactly what the fail-safe reads exist for.

Tests use a mock registry so engine tests don't break when the registry
changes.

---

## Types

### TradeProposal

```solidity
enum Side { Unset, Buy, Sell }

struct TradeProposal {
    address asset;
    Side side;
    uint256 sizeUnits;      // position size, simulated units, 18 decimals
    uint16  slippageBps;    // max slippage the proposer will accept
    uint256 dataTimestamp;  // when the market data behind this was observed
}
```

This struct is the entire surface the agent gets. It cannot express a contract
call, calldata, a recipient, or an approval — by construction, not by
validation. An agent that wanted to drain an account could not encode the
attempt in this type. That is the architectural claim the product makes, and
it lives here.

### RejectReason

```solidity
enum RejectReason {
    None,                 // 0 — approved
    AccountDoesNotExist,
    AutomationPaused,
    MandateNotSet,
    InvalidSide,
    ZeroSize,
    StaleMarketData,
    AssetNotApproved,
    MaxPositionExceeded,
    MaxSlippageExceeded
}
```

**Note the deliberate departure from the zero-means-unset convention used
everywhere else in this codebase.** Here zero means approved. That convention
exists because uninitialized storage reads as zero, and this function touches
no storage — it is pure, and the `approved` boolean carries the real signal.
Write that reasoning in a comment so the inconsistency reads as considered
rather than careless.

The consistency risk is the two return values disagreeing. Close it with an
invariant test rather than enum gymnastics:
`approved == (reason == RejectReason.None)`, asserted under fuzzing.

Returning a **reason** rather than reverting is the central design choice.
A revert tells you something failed; a reason code tells you what rule
stopped it. That is what makes the rejection legible in the demo, recordable
in the performance registry later, and honest in the public record — the
whole product premise is that rejections are visible, not swallowed.

---

## Constructor

```solidity
constructor(IAccountRegistry registry_, address[] memory approvedAssets_)
```

- Revert `ZeroAddress()` on a zero registry
- Revert `EmptyAssetList()` on an empty array
- Populate an `mapping(address => bool) private _approvedAsset`
- Revert `ZeroAddress()` if any entry is the zero address
- **Provide no setter.** The allowlist is fixed at deployment.

An asset allowlist that anyone can change requires an admin, and this project
has deliberately shipped four contracts without one. Changing the list means
redeploying, which for a prototype is the correct trade: it keeps the
no-privileged-roles property intact rather than introducing the first
exception here, in the most security-sensitive contract.

Expose `isApprovedAsset(address) external view returns (bool)` and
`approvedAssetCount()` so the fixed list is publicly inspectable.

---

## Validation

Checks run in this order, short-circuiting on the first failure.

| # | Condition | Reason |
|---|---|---|
| 1 | Account does not exist | `AccountDoesNotExist` |
| 2 | Automation paused (effective state) | `AutomationPaused` |
| 3 | Mandate is `Unset` | `MandateNotSet` |
| 4 | `side == Side.Unset` | `InvalidSide` |
| 5 | `sizeUnits == 0` | `ZeroSize` |
| 6 | Market data older than `MAX_DATA_AGE` | `StaleMarketData` |
| 7 | Asset not on the allowlist | `AssetNotApproved` |
| 8 | `sizeUnits` exceeds the mandate's position cap | `MaxPositionExceeded` |
| 9 | `slippageBps` exceeds the mandate's cap | `MaxSlippageExceeded` |
| — | otherwise | `None`, approved |

**The pause check comes second, before anything about the trade itself.** This
ordering is the demo. A proposal that is valid in every respect must still be
rejected the instant the holder has stopped automation — and it must be
rejected *for that reason*, not for some incidental one. Get this order wrong
and the most important ninety seconds of the demo lands weakly.

### Position cap

```
maxPositionUnits = (balance * params.maxPositionBps) / 10000
reject if sizeUnits > maxPositionUnits
```

Basis points, integer arithmetic, no rounding tricks. Multiply before dividing.

### Market data freshness

```solidity
uint256 public constant MAX_DATA_AGE = 300; // seconds — PROTOTYPE
```

Reject when `block.timestamp - proposal.dataTimestamp > MAX_DATA_AGE`, and
also when `dataTimestamp > block.timestamp` (a future timestamp is malformed).

**State the limitation in a comment.** `dataTimestamp` is self-reported by
whoever builds the proposal, so this catches a stale pipeline, not a dishonest
one. It is a sanity check, not a security control. Real oracle freshness
requires an oracle, which `INTEGRATIONS.md` I5 still has as `MOCK` with an
unverified feed. Saying so in the code is the difference between a documented
limitation and an implied guarantee.

---

## Errors

```solidity
error ZeroAddress();
error EmptyAssetList();
```

Only the constructor reverts. `validate` never reverts — it returns a reason.
A view that reverts is a view that cannot be asked "would this be allowed?",
and that question needs answering before submitting anything.

---

## Invariants

1. `validate` never writes storage — it is `view`
2. `approved == (reason == RejectReason.None)`, always
3. Automation paused ⇒ never approved, regardless of every other field
4. Mandate `Unset` ⇒ never approved
5. A pending transfer ⇒ never approved (follows from the effective-state read)
6. An unapproved asset ⇒ never approved
7. `sizeUnits > balance` ⇒ never approved, for every mandate — since the
   largest `maxPositionBps` is 5000, no mandate permits a position exceeding
   half the balance
8. The allowlist is unchangeable after construction
9. No function reads an archetype
10. Identical inputs always yield identical outputs — no dependence on caller,
    block number, or ordering, except `block.timestamp` in the freshness check

Invariant 3 is the product claim. It wants a fuzz test that randomises every
field of the proposal and asserts rejection while paused, not a single case.

---

## Tests

WHAT / WHY / FAILURE MEANS on each, as established.

### Approval

1. A fully valid proposal under Preservation is approved with reason `None`
2. A proposal exactly at the position cap is approved — boundary inclusive
3. A proposal exactly at the slippage cap is approved
4. Each of the four mandates approves a proposal sized correctly for it

### Each rejection reason

5–13. One test per reason, each asserting the specific enum value, not merely
that it was rejected. A test that only checks "not approved" passes when the
engine rejects for the wrong reason — which is the bug most likely to survive
into the demo.

### Ordering

14. A paused account with an oversized, unapproved-asset, stale proposal
    returns `AutomationPaused` — the kill switch outranks everything
15. An account with no mandate and an oversized proposal returns
    `MandateNotSet`, not `MaxPositionExceeded`

### The demo path

16. A proposal is approved; the holder pauses; **the identical proposal** is
    then rejected with `AutomationPaused`; the holder unpauses; it is approved
    again. One test, the whole arc. This is the demo encoded as an assertion.

### Transfer

17. After transfer and before sync, a previously valid proposal is rejected
    `AutomationPaused` — the fail-safe read reaching the engine
18. After the new holder syncs and sets their own mandate, validation uses
    *their* limits, not the seller's

### Boundaries

19. One unit above the position cap is rejected
20. One bp above the slippage cap is rejected
21. `dataTimestamp` exactly `MAX_DATA_AGE` old is accepted; one second older
    is rejected
22. A future `dataTimestamp` is rejected

### Fuzz

23. **Paused ⇒ never approved**, across randomised asset, side, size,
    slippage and timestamp
24. `approved == (reason == None)` across randomised everything
25. Size exceeding balance is never approved, across all four mandates
26. Two identical calls always return identical results

---

## Demo script

`script/Demo.s.sol` — this produces the video, so legibility of output matters
as much as correctness.

Six beats, printing clearly at each:

1. Mint → archetype assigned
2. Create account → seeded balance, PnL zero, paused, no mandate
3. Select Preservation → limits shown (1000 bps position, 50 bps slippage)
4. Unpause, submit a valid proposal → **APPROVED**
5. Submit an oversized proposal → **REJECTED: MaxPositionExceeded**
6. Flip the kill switch, resubmit **the proposal from step 4** →
   **REJECTED: AutomationPaused**

Print the reason as its name, not its number. `REJECTED: MaxPositionExceeded`
reads; `reason: 8` does not.

Step 6 must visibly reuse step 4's exact proposal. The point only lands if the
viewer can see that nothing about the trade changed — only the holder's
instruction did.

Use round numbers against a 10,000-unit balance: a 500-unit position approves
comfortably, a 2,000-unit one exceeds Preservation's 1,000-unit cap. Numbers a
viewer can do in their head beat numbers that require trust.

---

## Deferred — do not implement now

**Max open positions and daily drawdown.** Both are in `MandateParams` and
both are unenforceable today: there is no position tracking and no PnL
history. Enforcing them would mean inventing state to check against. Leave
the parameters in place, add `TODO(positions)` and `TODO(drawdown)` comments
naming what each needs, and record in `DECISIONS.md` that they are specified
but not yet enforced. A parameter that looks enforced and is not is worse than
one openly marked pending.

**Strategy–mandate compatibility.** No strategies exist.

**Real oracle freshness and deviation.** I5 is `MOCK`.

**Execution and settlement.** Approval is not execution. Nothing in this
milestone moves a balance.

---

## Acceptance criteria

- [ ] `forge build`, no warnings
- [ ] All existing tests still pass, plus the new ones
- [ ] `forge fmt --check` clean
- [ ] `validate` is `view` and writes no storage
- [ ] No admin, owner, or pause role in the contract
- [ ] Asset allowlist has no setter
- [ ] Every rejection reason has a test asserting that specific value
- [ ] Paused-never-approves proven by fuzz, not a single case
- [ ] The full demo arc (approve → pause → same proposal rejected → unpause →
      approved) passes as one test
- [ ] Engine reads effective state, never raw registry storage
- [ ] Both deferred mandate parameters carry a TODO naming what they need
- [ ] The `MAX_DATA_AGE` self-reporting limitation is stated in a comment
- [ ] Demo script prints reason names, not enum integers
- [ ] Every test carries WHAT / WHY / FAILURE MEANS
