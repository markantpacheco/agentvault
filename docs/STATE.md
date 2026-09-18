# AgentVault — Project State

**Purpose of this file:** paste it at the start of a new chat instead of
re-explaining the project. Keep it short. Update it at the end of every
work session.

**Last updated:** 2026-08-19
**Current milestone:** 1 complete, 2 not started
**Builder:** solo, novice developer, macOS
**Constraint:** limited token budget — batch requests, keep state in files

---

## What AgentVault is (one paragraph)

A proving ground and reputation layer for onchain trading agents. Users get a
Genesis Agent NFT that acts as the ownership handle on an isolated smart
account. They pick a risk mandate, activate a strategy, and the strategy trades
**simulated capital** against **real market data**. Every proposal, approval,
rejection, and result is recorded onchain against that NFT permanently. The
record is tamper-evident, complete (losses and rejections included), and
transfers with the NFT.

**Not** an AI-managed fund. **No** real user capital. **No** custody.
**No** advice on securities.

See `PRODUCT.md` for detail, `DECISIONS.md` for why.

---

## Status

| Area | State |
|---|---|
| Toolchain | Installed (git, node, pnpm, foundry, VS Code) |
| Repo | `~/agentvault`, git initialised, 1 commit |
| Contracts | `Archetype.sol` + 7 passing Foundry tests |
| GitHub | Not connected yet (Milestone 2) |
| Docs | This set |
| Deployed anywhere | **No.** Local only. Nothing on any public chain. |

---

## Next action

Milestone 2: GitHub setup, Python + Docker install, register files reviewed
and committed.

---

## Standing rules

1. No real capital, ever, until legal review and audit. Simulation only.
2. Never fabricate addresses, RPCs, chain IDs, or capabilities. Unverified =
   interface + mock + entry in `INTEGRATIONS.md`.
3. Never commit `.env`, keys, or seed phrases. Check `git status` before
   every commit.
4. Archetype (collectible) and risk mandate (financial) stay separate in code.
5. The AI proposes. Deterministic code decides. Always.
6. No language implying guaranteed returns, safety, or that the system cannot
   lose money.
7. Local dev and testnet before any mainnet action. Mainnet is gated on the
   checklist in `ROADMAP.md`.

---

## Open questions

- [ ] Confirm testnet chain ID by querying `eth_chainId` (sources disagree:
      46630 vs 46646)
- [ ] Grant application to Robinhood / Arbitrum Open House — not started
- [ ] Securities lawyer for NFT mint review — not engaged
- [ ] Which market data source feeds the simulator — undecided
