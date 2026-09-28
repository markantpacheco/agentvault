# AgentVault — Security Analysis

Two kinds of finding live here: what a static analyser reported, and what human
review found that no analyser would. Both are triaged in full — **no finding is
dropped silently.** "Accepted, and here is why it is safe in this context" is a
verdict; an unlisted finding is not.

Threats and testable invariants live in `THREAT-MODEL.md`. External dependencies
and their verification gates live in `INTEGRATIONS.md`. This document is for
things actually found, and what was concluded about each.

**Last updated:** 2026-09-28
**Status:** PROTOTYPE. Not audited. Static analysis and self-review are not an
audit, and nothing here should be read as one.

---

## 1. Tool, versions, and the exact command

| Item | Value |
|---|---|
| Tool | [Slither](https://github.com/crytic/slither) (Trail of Bits) |
| Slither version | **0.11.6** |
| crytic-compile | 0.4.2 |
| Python | 3.13.2, in an isolated virtualenv |
| solc | **0.8.24** (from `foundry.toml`, via Foundry's build-info) |
| EVM target | `paris` |
| Optimizer | off |
| Date run | 2026-09-28 |

Command, run from `packages/contracts`:

```bash
slither . --filter-paths "lib/" --exclude-dependencies
```

Result line: `. analyzed (26 contracts with 102 detectors), 5 result(s) found`

### Reproducing this

Slither is free and open source (AGPL-3.0). It was installed into a throwaway
virtualenv so nothing reaches the system Python:

```bash
python3 -m venv ~/.venvs/slither
~/.venvs/slither/bin/pip install --only-binary=:all: slither-analyzer==0.11.6
```

`--only-binary=:all:` matters on Python 3.13: without it, pip tries to build a
transitive dependency from source and fails for want of a Rust toolchain.
Forcing wheels avoids compiling anything.

Remove it completely with `rm -rf ~/.venvs/slither`. Nothing else was installed
and no system package was touched.

### Scope, and what was deliberately excluded

**`lib/` is excluded.** This report is about code this project wrote, not about
OpenZeppelin or forge-std. Both are widely used and separately audited, and
findings in them are not ours to triage — reporting them would pad the count
without informing anyone.

The exclusion is material and worth stating plainly:

| Scope | Findings |
|---|---|
| Everything, no filters | 25 |
| Our own code only (`lib/` excluded) | **5** |
| Therefore inside dependencies | 20 |

`--exclude-dependencies` was also passed; it changes nothing beyond
`--filter-paths lib/` (both runs return 5), and is recorded only because it was
in the command.

**`test/` and `script/` were not analysed.** Slither's Foundry integration
invokes `forge build --skip ./test/** ./script/**`, so the analysis covers
`src/` — the code that is actually deployed. Deploy-script guards are covered by
unit tests instead (`test/DeployTestnet.t.sol`,
`test/DeployRiskEngine.t.sol`). Noted so the gap is visible rather than implied.

---

## 2. Summary

**5 findings in our own code. 0 required a fix. None is a bug.**

| Impact | Count | Fixed | Accepted | False positive |
|---|---|---|---|---|
| High | 0 | 0 | 0 | 0 |
| Medium | 0 | 0 | 0 | 0 |
| Low | 3 | 0 | 1 | 2 |
| Informational | 1 | 0 | 1 | 0 |
| Optimization | 1 | 0 | 1 | 0 |
| **Total** | **5** | **0** | **3** | **2** |

No finding was suppressed with an inline `slither-disable` comment. Suppression
would make the report look cleaner while removing the reader's ability to
disagree with the triage.

---

## 3. Findings from static analysis

### SL-1 — `timestamp`: RiskEngine freshness check uses `block.timestamp`

- **Detector:** `timestamp` · **Impact:** Low · **Confidence:** Medium
- **Location:** `src/RiskEngine.sol:228` (`_evaluate`), comparisons at lines
  **264** and **268**
- **Slither claims:** dangerous comparisons —
  `proposal.dataTimestamp > block.timestamp` and
  `block.timestamp - proposal.dataTimestamp > MAX_DATA_AGE`.

**Verdict: ACCEPTED — intentional, and its real limitation is worse than the one
Slither is describing.**

The detector's concern is that validators have some latitude over
`block.timestamp`, so a comparison against it can be nudged. On an Arbitrum
Orbit L2 that latitude is small, and the consequence here would be shifting a
300-second freshness window by a few seconds. That is not the interesting
problem.

The interesting problem is one Slither cannot see: **`dataTimestamp` is
self-reported by whoever builds the proposal.** A proposer who lies about when
market data was observed passes this check trivially. It detects a stale
pipeline, not a dishonest one. It is a sanity check and not a security control,
which is stated in the contract at the `MAX_DATA_AGE` declaration and repeated
in section 5 below.

A real freshness guarantee needs an oracle. `INTEGRATIONS.md` I5 is still `MOCK`
with an unverified feed, so that guarantee does not exist yet, and the code says
so rather than implying otherwise.

Not fixed: removing the check would be worse, and there is no better check
available until an oracle is integrated.

---

### SL-2 — `timestamp`: `AccountRegistry._effectiveAccount`

- **Detector:** `timestamp` · **Impact:** Low · **Confidence:** Medium
- **Location:** `src/AccountRegistry.sol:370` (`_effectiveAccount`), comparison
  at line **372**
- **Slither claims:** dangerous comparison —
  `account.lastKnownOwner != agentNft.ownerOf(tokenId)`.

**Verdict: FALSE POSITIVE.**

That comparison is between two **addresses**. No timestamp participates in it.

The likely mechanism is taint propagation: `Account` contains
`uint64 createdAt` (`src/AccountRegistry.sol:46`), assigned from
`block.timestamp` at line **128**. Reading the struct therefore marks it
timestamp-derived, and any comparison involving a field read from it inherits
the taint — even a field, like `lastKnownOwner`, that has nothing to do with
time.

Nothing to fix. The finding is an artefact of struct-level taint granularity,
not a property of the code.

---

### SL-3 — `timestamp`: `AccountRegistry.isTransferPending`

- **Detector:** `timestamp` · **Impact:** Low · **Confidence:** Medium
- **Location:** `src/AccountRegistry.sol:275` (`isTransferPending`), comparison
  at line **277**
- **Slither claims:** dangerous comparison —
  `_accounts[tokenId].lastKnownOwner != agentNft.ownerOf(tokenId)`.

**Verdict: FALSE POSITIVE — identical to SL-2.**

Same address comparison, same struct-taint mechanism, same conclusion. Listed
separately because Slither reports it separately and because collapsing two
findings into one would understate the count.

---

### SL-4 — `missing-inheritance`: `AccountRegistry` does not declare `IAccountRegistry`

- **Detector:** `missing-inheritance` · **Impact:** Informational ·
  **Confidence:** High
- **Location:** `src/AccountRegistry.sol:29` (contract), against
  `src/interfaces/IAccountRegistry.sol:38`
- **Slither claims:** `AccountRegistry` should inherit from `IAccountRegistry`.

**Verdict: ACCEPTED, and it is a fair observation — but fixing it now would
create a worse problem than it solves.**

Slither is right about the substance. `AccountRegistry` implements every
function `IAccountRegistry` declares, but does not say so, so **the compiler
does not enforce the correspondence.** That matters more here than usual:
`IAccountRegistry.Account` must stay field-for-field identical to
`AccountRegistry.Account` or ABI decoding silently misreads the struct, and a
comment in the interface says exactly that. Compiler enforcement would be
strictly better than a comment.

Two reasons it is not being changed today:

1. **`AccountRegistry` is deployed and source-verified** at
   `0x0D0080582D317D2878A31b01D97614a3E918dC65`. Editing the source would leave
   the verified source on the explorer no longer corresponding to the repository
   at HEAD — a worse and more confusing defect than the one being fixed, and
   one that misleads anyone checking the deployment against the code.
2. **Conformance is demonstrated, if not compiler-enforced.** `RiskEngine`
   holds an `IAccountRegistry` and calls it successfully against the deployed
   registry on chain: `registry()` resolves, and `validate()` returns correct
   verdicts using `accountExists`, `isAutomationPaused`, `mandateOf`,
   `mandateParamsOf` and `getAccount`. The interface matches in practice.

**Carried forward:** add `is IAccountRegistry` the next time `AccountRegistry`
is redeployed for an unrelated reason. Recorded here so it is a scheduled
change rather than a forgotten one.

---

### SL-5 — `immutable-states`: `RiskEngine.approvedAssetCount` could be `immutable`

- **Detector:** `immutable-states` · **Impact:** Optimization ·
  **Confidence:** High
- **Location:** `src/RiskEngine.sol:137`
- **Slither claims:** the variable is only assigned in the constructor and could
  be declared `immutable`.

**Verdict: ACCEPTED. Correct, and a genuine improvement — deferred for the same
deployment-correspondence reason as SL-4.**

`approvedAssetCount` is written once, in the constructor, and no function
assigns it afterwards. `immutable` would save gas on every read and have the
compiler guarantee what is currently only true by inspection.

Behaviour is already correct: there is no setter, so the value cannot change.
This is a robustness and gas improvement, not a bug.

`RiskEngine` is deployed and source-verified at
`0x36df9096162b9f18d13574Fba930C9e2Ce6cc4a4`. Changing the source now would
desync it from the verified deployment, so it waits for the next redeployment —
of which there has already been one (v1 → v2, to extend the allowlist), so
another is likely.

**Carried forward** alongside SL-4.

---

## 4. Findings from human review

Static analysis finds patterns in code. These were found by reasoning about the
system and its environment, and no analyser would have surfaced them.

### S1 — Token-impostor surface on a permissionless chain (2026-09-28)

**Severity:** high if acted on. **Status:** avoided. Recorded so the method is
repeatable.

#### What was found

Looking for Paxos USDG on Robinhood Chain testnet (46630), a search of the block
explorer's token list for `USDG` returned **more than fifty ERC-20 contracts**,
many named to look canonical.

Five are named literally **"Paxos USDG"**. Every one was confirmed on chain for
this report — `symbol()`, `name()` and non-empty bytecode read directly with
`cast call` — rather than copied from notes:

| Address | `symbol()` | `name()` | Verdict |
|---|---|---|---|
| `0x293b337712D4312776a3a2D292F44410E7873bAd` | `USDG` | `Paxos USDG` | impostor |
| `0x0d0710E6aA1c9F2d5e04C3e2fd31cBA14131030c` | `USDG` | `Paxos USDG` | impostor |
| `0x022F49dbD588908b5A1805886c2107F0315223B4` | `USDG` | `Paxos USDG` | impostor |
| `0xC899788Ec20fC95D9d1A30a2eeD09DD7Aa351B45` | `USDG` | `Paxos USDG` | impostor |
| `0xeB5Ef28F36da77D3Fd64EB71C270afE293b40788` | `USDG` | `Paxos USDG` | impostor |

All five hold code and all five respond as ERC-20s. They are real contracts
telling a false story, not broken ones.

Alongside them sit dozens more: "Global Dollar", "Paxos Global Dollar",
"Mock USDG", "Test USDG", "Test Global Dollar".

**The genuine Paxos contract is `0x7E955252E15c84f5768B83c41a71F9eba181802F`,
and it is named plainly `Global Dollar`** — less official-looking than five of
the fakes.

#### How the real address was established

In this order, and the order is the finding:

1. **First-party documentation.** Paxos publishes testnet deployments at
   `docs.paxos.com/guides/stablecoin/usdg/testnet`, which lists "Robinhood
   Testnet" with one address. **This step decided the answer.**
2. **Chain confirmed.** `cast chain-id` returned 46630 before anything read from
   that RPC was trusted.
3. **Contract read directly.** `symbol()` = `USDG`, `name()` = `Global Dollar`,
   `decimals()` = 6, non-empty bytecode.
4. **Plausibility cross-checked.** Blockscout reports the contract verified, an
   EIP-1967 proxy, and **3,878 holders** — a usage profile a contract deployed
   to farm mistakes does not have.

Steps 2–4 confirm. **Step 1 decided.** Had the explorer search come first, its
ranking would have offered five better-named wrong answers before the right one.

#### Impact if it had gone the other way

`RiskEngine`'s asset allowlist is **fixed at construction with no setter**
(`DECISIONS.md` D13). An impostor allowlisted at deployment is allowlisted
**permanently** for that engine; the only remedy is deploying a replacement.

A *verified* contract carrying a fake asset would be worse than an unverified
one, because verification lends it credibility — a judge or user clicking
through would find readable source and a legitimate-looking name.

The selection pressure runs the wrong way: the most plausible-looking name is
the one a hurried developer picks, so ranking by apparent legitimacy actively
selects for the attacker's best work.

#### Mitigations now in place

- **First-party sourcing is the rule**, not the cross-check. An explorer token
  list is user-generated content; it ranks by indexing, not authenticity.
- **Every allowlist entry is a named constant in the deploy script**
  (`script/DeployRiskEngine.s.sol`), each commented with its symbol, its
  decimals, and the `INTEGRATIONS.md` entry recording how it was verified.
- **No allowlist environment variable.** It was deliberately removed. An env var
  can differ between a dry run and a broadcast, which is exactly the window an
  impostor address would need; a constant makes any change visible in a diff and
  subject to review.
- **A code check at deploy time.** Every address the engine will point at
  permanently — each allowlist entry and the registry — must hold non-empty
  bytecode or deployment reverts with `NoCodeAtAddress`. This catches a typo,
  though it cannot catch a well-formed impostor; only step 1 does that.
- **Verified on chain after deployment.** `isApprovedAsset` returns false for
  `0x293b3377…`, confirming no impostor reached the live allowlist.

#### Rule reinforced

`ASSUMPTIONS.md` U2 already said: *"Query chain; check bytecode. **Never** take
an EntryPoint address from a blog."* This is that rule meeting a real case, and
it generalises past EntryPoint to every external address this system will ever
reference.

#### Applies next to

Every remaining `MOCK` integration that will eventually need a real address:
I2 (ERC-4337 EntryPoint), I3 (ERC-6551 registry), I5 (price oracle),
I6/I7 (AMM venue and pool state), I9 (WETH). Each is an opportunity to allowlist
or call an impostor. First-party source first, every time.

---

## 5. What static analysis does not cover here

Slither reports on code structure. Several of this system's most important
properties are outside what any such tool can evaluate, and a clean report
should not be read as covering them.

**Economic and incentive logic.** Whether the PROTOTYPE mandate parameters are
*sensible* — 1000 bps for Preservation, 5000 for Speculative — is a judgement
about risk, not about code. Slither confirms the arithmetic is well-formed; it
has no opinion on whether the numbers are appropriate, and they are not audited
or proven (`Mandate.sol`, all values labelled PROTOTYPE).

**The self-reported `dataTimestamp`.** Covered under SL-1. The freshness check
constrains an honest but stale pipeline and does nothing against a dishonest
proposer. This is the clearest case of a tool reporting Low on something whose
real limitation is architectural.

**Anything resting on an unverified integration.** Every `MOCK` entry in
`INTEGRATIONS.md` is an assumption the analyser cannot test: I2 (EntryPoint),
I3 (ERC-6551), I5 (oracle), I6/I7 (AMM venue and pool state), I8 (token safety
screener), I9 (WETH), I11 (market data). Code that correctly calls a mock says
nothing about what happens against the real thing.

**Two mandate parameters that are specified but not enforced.**
`maxOpenPositions` and `maxDailyDrawdownBps` are in `MandateParams` and in the
PROTOTYPE table, and `RiskEngine` does **not** enforce either — both need state
that does not exist yet (`DECISIONS.md` D12). No account should be described as
drawdown-limited. Slither cannot flag an absent check.

**Cross-contract and economic invariants.** Account isolation, "a deposit never
increases recorded profit", "rarity has no effect on any risk limit" — these are
properties of the system, tested by the Foundry suite including fuzz tests, not
by static analysis.

**Denomination correctness.** `sizeUnits` is a normalised 18-decimal simulated
unit while Paxos USDG is 6-decimal (`DECISIONS.md` D14). `RiskEngine` never
reads `decimals()`, so this is consistent today, but any future execution
adapter must convert at its boundary. Getting it wrong in the USDG direction
understates a position by 10^12 and **fails open**. No analyser will catch that,
because both sides are `uint256`.

**Finally: this is not an audit.** It is one static analyser plus deliberate
self-review on an unaudited PROTOTYPE, with simulated capital and no real
assets. `ROADMAP.md` gates real capital on an independent audit with no
unresolved critical or high findings, and that gate is nowhere near satisfied.
