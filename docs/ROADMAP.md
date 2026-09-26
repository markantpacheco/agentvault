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
| 7 | Risk engine | Deterministic checks, position sizing, drawdown | ◐ Checks and position sizing done; drawdown deferred (D12) |
| 8 | Fill simulator + screener | AMM impact pricing, token safety checks | |
| 9 | Performance registry | Recording, deposit/profit separation, segmented views | |
| 10 | Agent pipeline | Typed schemas, mock classifier, schema rejection tests | |
| 11 | Frontend | Dashboard, mandate selection, kill switch, leaderboard | |
| 12 | Testnet + hardening | Deploy, fuzz, invariants, public launch | ◐ Deploy done early (2026-09-26); fuzz, invariants, launch outstanding |

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

Every tick above is earned by an automated test. **No criterion is ticked on
the strength of the testnet deployment**, because a single happy-path run
cannot establish the negative half of any of them: the live run showed that the
holder *can* set a mandate, not that a non-holder *cannot*; that one NFT maps
to one account, not that two never collide; that an archetype reads back
correctly, not that it is unchangeable.

What the live deployment of 2026-09-26 did demonstrate, end to end on chain
(`deployments/robinhood-testnet.json`):

- Minting assigns the requested archetype, read back as `Guardian`
- An account is created seeded at `SEED_BALANCE` with PnL exactly zero — the
  seed recorded as principal, not as performance
- The holder can select a mandate, and its PROTOTYPE parameters read back
  correctly
- The kill switch toggles
- A withdrawal reduces `balance`, increases `withdrawnTotal`, and leaves PnL at
  zero — principal out is not a loss

That is a working system, not a proof of the invariants. The invariants are the
tests' job.

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
- [x] Kill switch blocks new trades, never blocks withdrawal
- [ ] Transfer revokes owner and agent permissions and pauses automation
- [x] Transfer does not change the archetype
- [ ] New owner starts in conservative Starter Mode
- [x] A deposit never increases recorded profit
- [ ] Performance queryable by lifetime, owner period, strategy version, mandate
- [x] Speculative mandate has no live-execution code path
- [x] Rarity has no effect on any risk limit
- [ ] Fills priced with real impact, not mid-price
- [x] `forge test` passes from a clean clone with documented commands

---

## Explicitly out of scope for Alpha

Interfaces only. No implementation.

Perpetuals · FOREX · lending · sponsored treasury capital · utility token ·
cross-chain · real user capital
