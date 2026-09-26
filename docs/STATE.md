# AgentVault — Project State

**Purpose of this file:** paste it at the start of a new chat instead of
re-explaining the project. Keep it short. Update it at the end of every
work session.

**Last updated:** 2026-09-25
**Current milestone:** 1-3 complete, 4 not started
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
| Toolchain | Installed (git, node, pnpm, foundry 1.8.3, gh, VS Code) |
| Repo | `~/Documents/agentvault`, pushed to `markantpacheco/agentvault` |
| Contracts | `Archetype.sol`, `GenesisAgent.sol` + 21 passing Foundry tests |
| Dependencies | `forge-std` v1.16.2, OpenZeppelin v5.1.0 — submodules, pinned |
| GitHub | Connected. Remote is **private**. |
| Docs | This set, plus `specs/GenesisAgent.md` |
| Deployed anywhere | **No.** Local only. Nothing on any public chain. |

---

## Next action

Milestone 4: account registry — one isolated account per NFT, with isolation
tests. The ERC-6551 registry is still `MOCK` (`INTEGRATIONS.md` I3), so this
milestone builds against a mock and records the verification gate.

Not yet done from earlier milestones: Python + Docker install.

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
- [ ] `GenesisAgent` mint policy not signed off: permissionless, one per
      address ever, no supply cap, free. All PROTOTYPE. Revisit before any
      public deployment.
- [ ] Whether `ERC721Enumerable` is needed, or whether indexing off the
      `ArchetypeAssigned` event is sufficient
- [ ] Metadata hosting for `tokenURI` — no `INTEGRATIONS.md` entry yet, so
      `tokenURI` is deliberately unimplemented
- [ ] `docs/sec-comment-letter-DRAFT.md` was publicly readable 18-25 Sep 2026
      while the repo was public. Repo is private now; the file remains in
      git history. Decide whether to purge it.
