# AgentVault — Project State

**Purpose of this file:** paste it at the start of a new chat instead of
re-explaining the project. Keep it short. Update it at the end of every
work session.

**Last updated:** 2026-09-26
**Current milestone:** 1-4 complete, 5 and 7 partial, testnet deployment done (pulled forward from 12)
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
| Contracts | `Archetype.sol`, `GenesisAgent.sol`, `AccountRegistry.sol`, `Mandate.sol`, `RiskEngine.sol` + 126 passing tests |
| Dependencies | `forge-std` v1.16.2, OpenZeppelin v5.1.0 — submodules, pinned |
| GitHub | Connected. Remote is **private**. |
| Docs | This set, plus specs for `GenesisAgent`, `AccountRegistry`, `Mandate`, `Deployment`, `RiskEngine` |
| Deployed anywhere | **Robinhood Chain testnet (46630) only.** Both contracts verified on Blockscout. **Nothing on mainnet.** |
| `GenesisAgent` | `0x0EBdDD089f8203DD5cD1Bd1f148F75757285CF96` |
| `AccountRegistry` | `0x0D0080582D317D2878A31b01D97614a3E918dC65` |
| `RiskEngine` | `0x158A97c9b56043b5F3b841B3435D249326F43777` (allowlist: AVTA, AVTB) |
| `TestAsset` AVTA | `0x87CEd5dc138F825B3F42924A8Bb6E15ae5EC9A7d` |
| `TestAsset` AVTB | `0x9D97ebc6A395aaf981B26d952A4e22604eAFEc75` |
| Deployer | `0xeA68020Fa1EeE645E019C870cdE1f99e69135629` (throwaway, keystore only) |
| Live smoke test | All 8 steps passed on chain 2026-09-26. Record in `deployments/robinhood-testnet.json`. |

---

## Next action

Milestone 6: the permission module — session keys with scope, expiry,
revocation, and transfer invalidation. That is also where the deferred
`TODO(milestone-6)` trade-settlement authorisation lands.

Deployment is done and ahead of schedule: it was pulled forward from Milestone
12 deliberately, because every remaining unknown lived in deployment rather
than in Solidity. Those unknowns are now closed — chain ID measured, RPC
proven, faucet used, Blockscout verification working.

Still outstanding from Milestone 5: cooling-off on raising risk and the
strategy registry (`DECISIONS.md` D11).

Accounts stay structs until ERC-6551 clears its verification gate
(`INTEGRATIONS.md` I3). Trade settlement is deferred to Milestone 6: nothing
can change an account balance today except the holder's own deposits and
withdrawals, because there is no authorised caller and no admin role to
create one.

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

- [x] Testnet chain ID confirmed 2026-09-26: `cast chain-id` returned
      **46630**, matching the official docs. The third-party 46646 was wrong.
      `ASSUMPTIONS.md` U1 closed and folded into V3.
- [ ] Grant application to Robinhood / Arbitrum Open House — not started
- [ ] Securities lawyer for NFT mint review — not engaged
- [ ] Which market data source feeds the simulator — undecided
- [x] `GenesisAgent` mint policy signed off 2026-09-25 (`DECISIONS.md` D10):
      permissionless, one per address ever, free, supply capped at 10,000.
      All PROTOTYPE. Production gating deferred to Phase 8.
- [ ] Whether `ERC721Enumerable` is needed, or whether indexing off the
      `ArchetypeAssigned` event is sufficient
- [ ] Metadata hosting for `tokenURI` — no `INTEGRATIONS.md` entry yet, so
      `tokenURI` is deliberately unimplemented
- [ ] `docs/sec-comment-letter-DRAFT.md` was publicly readable 18-25 Sep 2026
      while the repo was public. Repo is private now; the file remains in
      git history. Decide whether to purge it.
