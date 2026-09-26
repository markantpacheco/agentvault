# AgentVault — Roadmap

**Last updated:** 2026-08-19

Weeks are milestones, not calendar commitments. Work is bounded by available
sessions, not by dates. A milestone is complete when its tests pass, not when
its week ends.

---

## Product Alpha

| # | Milestone | Deliverable | Status |
|---|---|---|---|
| 1 | Environment + repo | Toolchain, monorepo, `Archetype.sol` + 7 tests | ✅ Done |
| 2 | Docs + GitHub | Registers committed, remote connected, Python + Docker | ✅ Done |
| 3 | Genesis Agent NFT | ERC-721, permanent archetype at mint | ✅ Done |
| 4 | Account registry | One isolated account per NFT, isolation tests | ✅ Done |
| 5 | Mandate + strategy registries | Selection, cooling-off, compatibility | ◐ Selection done; cooling-off and strategy registry deferred (D11) |
| 6 | Permission module | Session keys: scope, expiry, revocation, transfer invalidation | |
| 7 | Risk engine | Deterministic checks, position sizing, drawdown | |
| 8 | Fill simulator + screener | AMM impact pricing, token safety checks | |
| 9 | Performance registry | Recording, deposit/profit separation, segmented views | |
| 10 | Agent pipeline | Typed schemas, mock classifier, schema rejection tests | |
| 11 | Frontend | Dashboard, mandate selection, kill switch, leaderboard | |
| 12 | Testnet + hardening | Deploy, fuzz, invariants, public launch | |

---

## After Alpha

| Phase | Gate to enter |
|---|---|
| Public free launch | Milestone 12 complete, all acceptance criteria passing |
| 60-day public run | Launch stable, users onboarding |
| Grant applications | Working code — apply as early as milestone 6 |
| NFT mint | Real users, counsel has reviewed sale + copy, supply sized to actual audience |
| Subscriptions | Users asking for specific paid features |
| Strategy marketplace | Core stable, creator bond and versioning designed |
| Live capital | **Blocked.** See gate below. |

---

## Live-capital gate

Every item required. No partial entry.

- [ ] Independent smart-contract audit, no unresolved critical or high findings
- [ ] 90 days of forward testing with documented maximum drawdown
- [ ] Legal review complete for the specific configuration proposed
- [ ] All external addresses verified onchain and recorded
- [ ] Contract permissions reviewed and documented
- [ ] Upgrade controls documented, or upgradeability absent
- [ ] Emergency controls tested under simulated incident
- [ ] Account-level and protocol-level kill switches validated
- [ ] Oracle failure handling validated
- [ ] Eligibility and jurisdiction controls in place
- [ ] No unrestricted AI-generated transactions anywhere in the codebase

**Speculative mandate never enters live capital in the initial launch**,
regardless of the above.

---

## Prototype acceptance criteria

The local prototype is done when all of these pass as automated tests.

- [x] Minting assigns exactly one archetype; never changeable afterward
- [x] Each NFT maps to exactly one account; no two NFTs share one
- [x] Account A unaffected by any operation on account B
- [x] Only the current owner can set the risk mandate
- [ ] A session key cannot withdraw under any input
- [ ] A session key stops working after expiry
- [ ] Owner revocation takes effect in the same transaction
- [ ] Risk engine rejects: oversized position, excess slippage, incompatible
      strategy, stale oracle, insufficient liquidity
- [ ] Daily drawdown breach pauses new trades
- [ ] Kill switch blocks new trades, never blocks withdrawal
- [ ] Transfer revokes owner and agent permissions and pauses automation
- [x] Transfer does not change the archetype
- [ ] New owner starts in conservative Starter Mode
- [x] A deposit never increases recorded profit
- [ ] Performance queryable by lifetime, owner period, strategy version, mandate
- [x] Speculative mandate has no live-execution code path
- [ ] Rarity has no effect on any risk limit
- [ ] Fills priced with real impact, not mid-price
- [x] `forge test` passes from a clean clone with documented commands

---

## Explicitly out of scope for Alpha

Interfaces only. No implementation.

Perpetuals · FOREX · lending · sponsored treasury capital · utility token ·
cross-chain · real user capital
