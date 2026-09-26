# AgentVault — Working Notes

Read this before doing anything in this repo.

## What this is

A proving ground and reputation layer for onchain trading agents on Robinhood
Chain. A Genesis Agent NFT is the ownership handle on an isolated smart
account. The holder picks a risk mandate and activates a strategy; the strategy
trades **simulated capital** against **real market data**. Every proposal,
approval, rejection, and result is recorded onchain permanently.

Not an AI-managed fund. No real user capital. No custody. No advice on
securities.

## Build and test

Foundry dependencies are tracked as git submodules, so the clone needs them:

```bash
git clone --recurse-submodules https://github.com/markantpacheco/agentvault.git
cd agentvault/packages/contracts
forge build
forge test -vv
```

Already cloned without `--recurse-submodules`:

```bash
git submodule update --init --recursive
```

Expected: all tests pass, 0 failures.

Dependency versions are pinned by submodule commit. Do not run
`forge update` without re-running the full suite — `forge-std` v1.16.2 is
what the fuzz tests are known to compile against.

OpenZeppelin is pinned at **v5.1.0**, and the pin is load-bearing: v5.2.0 and
later use the `mcopy` opcode, which does not exist under `evm_version =
"paris"`. Upgrading OpenZeppelin therefore means changing the EVM target, which
is gated on verifying what Robinhood Chain actually supports (`ASSUMPTIONS.md`
U1). Do not do one without the other.

## Non-negotiable rules

1. **Simulation only.** No real user capital, ever, until independent audit
   and legal review are both complete.
2. **Never fabricate** a contract address, RPC URL, chain ID, token address,
   oracle address, or protocol capability. If it isn't verified, create a
   typed interface, a mock, a config placeholder, and an entry in
   `docs/INTEGRATIONS.md`.
3. **Never commit** `.env`, private keys, or seed phrases. Check `git status`
   before every commit.
4. **Archetype is not risk.** Collectible identity (Guardian/Navigator/
   Tactician/Maverick) and financial risk mandate (Preservation/Balanced/
   Tactical/Speculative) live in separate contracts. Rarity never grants
   higher leverage, wider drawdown, priority withdrawal, or better execution.
5. **The AI proposes; deterministic code decides.** The agent emits a typed,
   schema-validated proposal and nothing else. It can never raise its own
   limits, renew its own session key, change the mandate, disable the kill
   switch, call arbitrary contracts, or construct arbitrary calldata.
6. **No guaranteed-return language** anywhere — code, comments, docs, or UI.
   Nothing implies the system cannot lose money.
7. **Label every limit** as PROTOTYPE, TESTNET, PROPOSED PRODUCTION, or FINAL
   PRODUCTION. Current values are all PROTOTYPE and are not audited or proven.
8. **Speculative mandate has no live-execution code path.** Enforced by test.

## Architecture principles

- One isolated account per NFT. No shared balances between accounts.
- Noncustodial: the current holder always controls withdrawal.
- Agent permissions are scoped, time-limited, and revocable in one transaction.
- The kill switch requires no protocol-team approval and never blocks
  withdrawal.
- On NFT transfer: archetype unchanged, lifetime history preserved, prior owner
  period archived, all permissions revoked, automation paused, new owner starts
  in conservative Starter Mode.

## Code conventions

- Solidity pinned to 0.8.24. Do not change without discussion.
- `evm_version = "paris"` — conservative, chosen because Robinhood Chain's
  support for newer targets is UNVERIFIED. See `docs/ASSUMPTIONS.md`.
- OpenZeppelin for standard implementations (ERC-721, access control).
- Custom errors, not revert strings.
- Enum zero values mean "unset" and are never valid — uninitialized storage
  reads as zero. Token IDs start at 1 for the same reason.
- Every test carries a comment: WHAT is tested, WHY it matters, what FAILURE
  MEANS.

## Known gotchas

- **`vm.expectRevert` on an `internal` library function fails.** Internal
  functions inline into the caller, so the revert happens at the same call
  depth as the cheatcode and Foundry refuses to match it
  ("call didn't revert at a lower depth than cheatcode call depth"). Add an
  `external` wrapper on the test contract and call it via `this.`. Custom
  error data propagates through the boundary intact. If more than a few
  wrappers are needed, move them to a dedicated harness contract.
- **macOS: forge crashes with SIGABRT on launch.** Usually a missing
  `libusb-1.0.0.dylib`. Fix with `brew install libusb`.
- **`forge install` stages the submodule at the wrong commit.** It records the
  dependency's default-branch tip in the index and *then* checks out the
  pinned tag, so index and worktree disagree. `git submodule status` shows a
  leading `+`. Committing in that state makes a fresh
  `--recurse-submodules` clone check out the wrong revision. Fix with
  `git add <submodule path>` and re-check before committing.
- **OpenZeppelin v5.2.0+ will not compile under `evm_version = "paris"`.**
  It uses `mcopy`, a Cancun opcode, reached through `Strings.sol` →
  `Bytes.sol`. v5.1.0 is the newest paris-compatible release.

## Testing

No milestone is complete without tests. Minimum coverage for anything new:
access control, the failure path, and the relevant invariant from
`docs/THREAT-MODEL.md`.

## Docs

`docs/STATE.md` — current state, read first
`docs/ROADMAP.md` — 12 milestones and launch gates
`docs/DECISIONS.md` — why things are the way they are
`docs/ASSUMPTIONS.md` — verified vs unverified vs blocking
`docs/INTEGRATIONS.md` — external dependencies and verification gates
`docs/THREAT-MODEL.md` — threats and testable invariants
`docs/PRODUCT.md` — what this is and is not
`docs/LEGAL-QUESTIONS.md` — questions for counsel, not answers
`docs/specs/` — per-contract specifications, written before implementation

## Current state

Milestones 1–3 complete: toolchain, repo, `Archetype.sol`, `GenesisAgent.sol`
(ERC-721 with a permanent archetype assigned at mint), 21 passing tests, docs
published, pushed to a private GitHub remote. Nothing deployed to any chain.

`GenesisAgent` has no owner, no admin, and no role-gated function — there is
no privileged actor who could alter an assigned archetype. `tokenURI` is
deliberately absent until metadata hosting has an `INTEGRATIONS.md` entry.

Next: Milestone 4, the account registry — one isolated account per NFT. The
ERC-6551 registry is still `MOCK` (`INTEGRATIONS.md` I3).
