# Buildathon submission — point-in-time record

**This is a dated snapshot of what was submitted to the Arbitrum Open House
Singapore Buildathon on 2026-09-29. It is deliberately NOT maintained.**

Nothing in this file will be updated as the project changes. That is what makes
it safe to commit: a dated record of what was claimed on a particular day cannot
go stale, because it never claims to be current. A living document that drifts
out of date is worse than no document.

**For the current state of the project, read
[`README.md`](../README.md) and [`docs/PRODUCT.md`](PRODUCT.md).** For the
current test count, run `forge test` — do not quote a number from this file.

## Formatting note

The text actually pasted into the submission form had its code block and tables
flattened to prose, because the form rejected that formatting. **The substance
is identical.** This version keeps the original formatting because it renders on
GitHub.

The pitch video script is deliberately excluded — production material, not
project documentation.

## Known divergence from the repository

Recorded rather than corrected, because editing a snapshot to match later facts
defeats its purpose.

**The text below describes the test suite as including "forked-live-state"
tests. It does not.** No committed test forks the chain — a check for
`createSelectFork` across `test/` returns nothing. A forked test against live
state was written during the RiskEngine work to validate the demo arc, but it
was a throwaway probe and was deleted the same day by design.

The accurate description of the 126 tests is: **unit, pure-fuzz, and four
stateful-fuzz invariants**, plus an integration suite that drives the real
contracts together locally. Every other factual claim below — addresses, chain
ID, Slither findings, test counts and their qualifiers, the two unenforced
mandate parameters — was cross-checked against the repository and the live chain
on 2026-09-29 and is accurate.

---

# AgentVault

**The deterministic risk layer an AI agent cannot override.**

## The problem is already here

In July, Robinhood launched its own chain. Among the things that shipped were
Agentic Accounts — a way to wire AI models directly into trading
infrastructure. That is the direction the whole space is moving.

It raises a question with no good answer today: **when an agent can move
money, what stops it?**

Right now, mostly prompt engineering and hope. The model is instructed not to
do anything catastrophic, and everyone proceeds as if instructions were
constraints. They aren't. A model that misreads its context, gets prompt-
injected through market data, or simply produces a malformed output has
nothing structural standing between it and the account.

## What's different here

Most approaches to this problem validate what the agent asks for. AgentVault
changes what the agent is *able to ask*.

The agent's entire vocabulary is one data structure:

```solidity
struct TradeProposal {
    address asset;
    Side    side;
    uint256 sizeUnits;
    uint16  slippageBps;
    uint256 dataTimestamp;
}
```

There is no field for a contract address to call, no field for calldata, no
field for a recipient, no field for a token approval. **An agent that wanted
to drain an account could not encode the attempt** — not because validation
catches it, but because the type has nowhere to put it.

Everything that *can* be expressed then passes through a deterministic
validator. Not a model. Code.

`RiskEngine.validate()` is a pure view function — no storage, no access
control, no admin, no pause. Anyone may call it, because calling it changes
nothing. It checks the holder's kill switch *before* it checks anything about
the trade, then mandate limits, asset allowlist, position cap, slippage, data
freshness — and returns a **named reason** rather than a bare revert. A revert
says something failed. A reason code says which rule stopped it, which is what
makes a rejection legible, recordable, and honest.

Three further design choices, each enforced rather than promised:

**No contract in this system has an owner, an admin, or a role-gated
function.** Not one. The asset allowlist is fixed at deployment with no
setter. There is no privileged key to lose, leak, or subpoena.

**Withdrawal has no pause check on any code path.** The kill switch stops
automation and can never stop a holder reaching their own funds. That
asymmetry is the difference between a safety feature and a hostage situation.

**Collectible rarity cannot touch financial risk.** The risk engine depends on
an interface that cannot see an NFT's archetype at all, so a rare agent
structurally cannot receive a higher limit. Proven by a suite that mints four
archetypes, gives them identical mandates, and asserts identical verdicts.

## Ninety seconds that show it

Running live on testnet against deployed contracts:

```
4. PROPOSE - inside every limit      size 499   >> APPROVED
5. PROPOSE - over the position cap   size 1999  >> REJECTED: MaxPositionExceeded
   >> holder flips the kill switch (one transaction) <<
6. RESUBMIT BEAT 4's PROPOSAL        size 499   >> REJECTED: AutomationPaused
```

Beats 4 and 6 send the identical proposal — same asset, same 499 units, same
25 basis points. Nothing about the trade changed. Only the holder's
instruction did, and the agent has no path to that switch.

## Built and verified

**126 tests** — unit, fuzz, forked-live-state, and four stateful-fuzz
invariants — passing from a clean clone. Zero compiler warnings. `forge fmt`
clean.

**The two claims a reader should most doubt are the two the invariants
target.** "Withdrawal has no pause check on any path" and "a deposit can never
be reported as a gain" are easy to assert and hard to believe. Each is now a
stateful invariant: a handler contract drives minting, deposits, withdrawals,
pauses, NFT transfers and sync in randomised sequences, and after every
reachable state the suite asserts the holder can still withdraw in full, and
that profit and loss equals balance minus net principal. 16,384 calls per run,
zero reverts, with the search space (`runs = 128, depth = 128`) written into
`foundry.toml` so it can be read without being run.

The handler counts successful state mutations rather than attempted calls, and
a separate test asserts those counts are non-trivial — because an invariant
suite whose handler calls all revert passes perfectly while exploring nothing.
`syncAccount` firing on its own is the coverage result that matters: it only
fires when an NFT transfer is genuinely pending, so a non-zero count proves the
stale-transfer window is actually being entered rather than assumed.

**Static analysis** with Slither 0.11.6: five findings in project code, **zero
high and zero medium**. Every one is triaged by name in
`docs/SECURITY-ANALYSIS.md` — three accepted with reasoning, two false
positives explained, none suppressed with an inline disable comment.

**Five contracts deployed and source-verified** on Robinhood Chain testnet
(chain 46630):

| Contract | Address |
|---|---|
| GenesisAgent | `0x0EBdDD089f8203DD5cD1Bd1f148F75757285CF96` |
| AccountRegistry | `0x0D0080582D317D2878A31b01D97614a3E918dC65` |
| RiskEngine | `0x36df9096162b9f18d13574Fba930C9e2Ce6cc4a4` |
| TestAsset AVTA | `0x87CEd5dc138F825B3F42924A8Bb6E15ae5EC9A7d` |
| TestAsset AVTB | `0x9D97ebc6A395aaf981B26d952A4e22604eAFEc75` |

The risk engine's asset allowlist is fixed at deployment with no setter, and it
includes **Paxos USDG** at `0x7E955252E15c84f5768B83c41a71F9eba181802F`. That
address came from Paxos first-party documentation and was then confirmed on
chain — not from explorer search, because explorer search returns fifty-plus
tokens claiming to be USDG on this testnet, five of them named literally "Paxos
USDG". The genuine contract is named plainly `Global Dollar`. An immutable
allowlist populated by search would have baked an impostor in permanently. That
is written up as security finding S1.

An earlier RiskEngine at `0x158A97c9…3777` is marked **superseded** in the
deployment record, with the date and the reason, rather than deleted.

Solidity pinned to 0.8.24, dependencies pinned by submodule, `SafeCast` and
`mulDiv` guarding every arithmetic boundary, custom errors throughout, no
proxies and no upgradeability.

Nothing in this repo was assumed. The chain ID was measured rather than read
from documentation, after two sources disagreed. The Blockscout verifier
endpoint was established by probing its API rather than guessing the
conventional URL. Verification status was confirmed independently — the
Foundry CLI reported one contract as "already verified" while the explorer
still had it unverified.

The suite reports 126 tests. It also reported 126 earlier in the Buildathon,
and *that* number was not real. One test wrote to the process environment,
Foundry runs test contracts in parallel, and a second contract wrote the same
variable — so they raced, and the suite passed intermittently. Five consecutive
runs produced three failures; 126 was simply the run that had been looked at.
Removing the race brought the honest count to 124. Adding the invariant suite
brought it back to 126, by coincidence, from an entirely different set of tests.

That coincidence was reconciled rather than accepted: the eight pre-existing
suites still collect exactly 124, so nothing quietly stopped being collected —
which is the failure that looks identical to a clean pass. The invariant
contract adds two reported entries, because Foundry reports every `invariant_*`
function in a contract as a single entry. `forge test --list` says 129, counting
the four invariants individually. All three numbers are correct and they
measure different things.

That is a small thing, and it is the whole argument. A project whose product is
a tamper-evident performance record does not get to round its own numbers up.

## Who this is for

**Agent developers** who need permission scaffolding they didn't write
themselves. Building it badly is how you lose someone else's money, and
building it well is weeks of work orthogonal to the strategy anyone actually
wants to ship.

**Capital allocators** who need a record of what an agent really did —
including the losses and the trades that were refused. Today the only evidence
a strategy works is a screenshot, and screenshots are free to fabricate. The
record here is append-only, includes rejections, and travels with the NFT when
it's sold.

**The adoption path is the repo.** Clone it and the full demo runs in under a
minute — no wallet, no configuration, no chain connection required. For
infrastructure, that *is* the user experience, and it's a claim most
submissions can't make:

```bash
git clone --recurse-submodules https://github.com/markantpacheco/agentvault.git
cd agentvault/packages/contracts
forge test          # 126 passed
forge script script/Demo.s.sol:Demo -vv
```

## Where this honestly is

Early. No users, no frontend, no real capital — and the repo says so
throughout rather than in a footnote.

Strategies trade **simulated capital** against real market data. Principal and
profit are separate fields from the first line of code, so a deposit can never
be reported as a gain. Every parameter is labelled PROTOTYPE. Two mandate
parameters are specified but not yet enforceable, and they carry TODOs in the
code, an entry in the decision log, and a partial mark on the roadmap rather
than a tick.

Not a fund. No custody. No advice on securities. No claim the system cannot
lose money — it can.

The decision record documents every major choice, its cost, and what would
reverse it. The assumptions register separates verified from unverified from
blocking, and includes a corrections log of assumptions that turned out wrong.
That discipline is the actual product: a performance record is only worth
something if the project keeping it doesn't overstate things.

**Repo:** `github.com/markantpacheco/agentvault`

---

# Appendix — tech stack and progress narrative

Submitted alongside the overview above, in the Buildathon's separate fields.

---

## 1. Tech stack

**Smart contracts**
- Solidity 0.8.24, version-pinned for reproducible bytecode
- `evm_version = "paris"` — the most conservative target, chosen because
  newer opcode support on this chain was unverified
- OpenZeppelin Contracts v5.1.0 (ERC-721, ERC-20, SafeCast, Math)
- No proxies, no upgradeability, no admin roles anywhere in the system

**Development and testing**
- Foundry — `forge` for build and test, `cast` for chain interaction,
  `anvil` for local chains
- forge-std v1.16.2, pinned by git submodule
- 126 tests: unit, fuzz, forked-live-state, and four stateful-fuzz invariants
  driven by a handler contract, with the search space (`runs = 128,
  depth = 128`) committed to `foundry.toml`
- `forge fmt` enforced, zero compiler warnings
- Slither 0.11.6 for static analysis — five findings in project code, zero
  high, zero medium, each triaged by name in `docs/SECURITY-ANALYSIS.md`

**Chain and infrastructure**
- Robinhood Chain testnet, chain ID 46630 (measured, not assumed)
- Arbitrum Orbit / Nitro stack, settling to Ethereum
- Blockscout for source verification, confirmed independently via its API
  rather than trusting the CLI's report
- Encrypted Foundry keystore for deployer keys — no plaintext private key
  in the repo, the environment, or shell history

**Tooling**
- Git / GitHub, with clean-clone verification on every milestone
- Claude Code for implementation against human-written specifications

**Deliberately not built yet**
- No frontend, no backend, no database. The contracts and the risk engine
  were the thing worth proving first.

---

## 2. Progress during the Buildathon

Going in, AgentVault existed as specification: a product definition, a
threat model, an assumptions register separating verified from unverified
facts, and a twelve-milestone roadmap with explicit acceptance criteria. No
implementation.

Everything below was built during the Buildathon.

**Contracts written and tested**
- `Archetype` — permanent collectible identity, four types
- `GenesisAgent` — ERC-721, permissionless capped mint, archetype assigned
  once and never changeable
- `AccountRegistry` — one isolated account per NFT, principal and profit
  tracked separately, lazy transfer detection, holder kill switch
- `Mandate` — four risk mandates with prototype parameters, holder-selected
- `RiskEngine` — pure-view deterministic validator returning named rejection
  reasons

**Deployed and verified on Robinhood Chain testnet**

| Contract | Address |
|---|---|
| GenesisAgent | `0x0EBdDD089f8203DD5cD1Bd1f148F75757285CF96` |
| AccountRegistry | `0x0D0080582D317D2878A31b01D97614a3E918dC65` |
| RiskEngine | `0x36df9096162b9f18d13574Fba930C9e2Ce6cc4a4` |
| TestAsset AVTA | `0x87CEd5dc138F825B3F42924A8Bb6E15ae5EC9A7d` |
| TestAsset AVTB | `0x9D97ebc6A395aaf981B26d952A4e22604eAFEc75` |

All five source-verified. The full demo arc has run on chain, including a
real kill-switch transaction at
`0x4e1037f7647d2d27bc26beb511331efaa253d32faf7511be111315ae2731b890`.

**Paxos USDG allowlisted, at an address established the hard way.** The risk
engine's allowlist is fixed at deployment and includes USDG at
`0x7E955252E15c84f5768B83c41a71F9eba181802F`. Explorer search on this testnet
returns fifty-plus tokens claiming that ticker, five of them named literally
"Paxos USDG" — all five confirmed on chain as real deployed ERC-20s wearing the
name. The genuine contract is named plainly `Global Dollar`. The address was
taken from Paxos first-party documentation and then verified on chain. Because
the allowlist has no setter, sourcing it from search would have been permanent.
Written up as security finding S1.

An earlier RiskEngine is marked superseded in the deployment record with a date
and a reason rather than removed. Extending an immutable allowlist means
redeploying — that is the cost of having no admin key, and it is paid rather
than designed around.

**Verified rather than assumed**
- Chain ID measured directly with `cast chain-id`, closing an open question
  where a third-party source disagreed with the official docs
- Blockscout's verifier endpoint established by probing its API, not by
  assuming the conventional URL
- Verification status confirmed independently — `forge verify-contract`
  reported one contract as "already verified" while the explorer still had
  it unverified

**Properties enforced, not just claimed**
- No contract has an owner, admin, or role-gated function
- Withdrawal has no pause check on any path — the kill switch stops
  automation and can never stop the holder
- Collectible rarity cannot affect risk limits: the risk engine depends on
  an interface that cannot see an archetype, proven by a test suite that
  mints four archetypes and asserts identical verdicts
- Two mandate parameters are specified but not yet enforceable; they carry
  TODOs in code and are recorded as pending in the decision log rather than
  presented as working

**Security analysis published**
- Slither 0.11.6 run against `src/`, with the report committed as
  `docs/SECURITY-ANALYSIS.md`: five findings in project code, zero high, zero
  medium. Each is listed by detector name with a triage verdict — three
  accepted with reasoning, two false positives explained. None suppressed
  with an inline disable comment.
- The unfiltered run reports 25 findings; 20 are inside `lib/`. Both numbers
  are published so the exclusion is visible rather than implied.
- Two findings are real improvements and were deliberately *not* applied: the
  affected contracts are already deployed and source-verified, so editing the
  source would leave the explorer's verified code no longer matching HEAD.
  Both are recorded as carried forward to the next redeployment.
- Security finding S1 came from human review rather than the tool: the USDG
  impostor problem above.

**Stateful invariant tests**

Four invariants, each one a claim the project makes publicly, driven by a
handler contract that randomises sequences of minting, deposits, withdrawals,
pauses, NFT transfers and sync:

- **Withdrawal liveness** — in every reachable state, including paused,
  mid-transfer and unsynced, the current holder can withdraw in full
- **A deposit is never profit** — profit and loss equals balance minus net
  principal, checked against ghost accounting in the handler rather than
  against the contract's own arithmetic
- **Paused implies never approved** — across every reachable state, not just
  the one a unit test constructs
- **Archetype cannot influence risk** — parallel accounts differing only in
  collectible archetype return identical verdicts and identical reasons

16,384 calls per run with `fail_on_revert = true` and zero reverts. Verified
across eight consecutive runs and three explicit fuzz seeds, all recorded.

**The trap in invariant testing, and a Foundry finding**

An invariant suite whose handler calls all revert passes perfectly while
exploring nothing, and `fail_on_revert = true` alone does not catch it — a
handler that returns early satisfies it. So the handler counts *successful
state mutations*, and a separate ordinary test asserts those counts are
non-trivial. `syncAccount` firing on its own is the result that matters: it can
only fire when an NFT transfer is genuinely pending, so a non-zero count proves
the stale-transfer window is actually being entered.

That coverage assertion cannot live in `afterInvariant()`. When any invariant
fails, Foundry shrinks toward the shortest failing sequence, and a coverage
assertion is trivially failable by a one-call sequence — so the shrinker drives
straight at it and reports a nonsense counterexample naming an invariant that
never broke. Found the hard way, fixed by splitting reporting from assertion,
and written into the repo's gotchas file with the full symptom.

**A correction, on the record**

The suite reports 126 tests. Earlier in the Buildathon it also reported 126,
and that number was not real.

One test wrote an environment variable to check a deploy-script guard. Foundry
runs test contracts in parallel, and a second test contract wrote the same
variable — so the two raced, and the suite passed intermittently. Five
consecutive local runs produced three failures. The 126 was simply the run that
had been looked at. Caught by running the suite repeatedly from a clean clone
rather than once, then fixed by removing the race; four guard tests became two
and no assertion was lost.

The honest count after that fix was 124. Adding the invariant suite brought it
back to 126 — by coincidence, from a different set of tests.

That coincidence was reconciled rather than waved through. The eight
pre-existing suites still collect exactly 124, so no test quietly stopped being
collected, which is the failure mode that looks identical to a clean pass. The
invariant contract adds two reported entries because Foundry reports all
`invariant_*` functions in a contract as one; `forge test --list` says 129,
counting them individually. All three numbers are correct and measure different
things, and all three are explained in the repo.

This is recorded rather than quietly corrected because the product is a
performance record that includes losses and refused trades. A project that
rounds its own test count up has no business claiming to keep an honest one.

**Remaining:** demo and pitch videos, brand assets.
