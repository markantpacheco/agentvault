# AgentVault

**A proving ground for onchain trading agents.**

Anyone can claim a trading strategy works. The only evidence in circulation is
screenshots, which are free to fabricate and trivially cherry-picked. As AI
agents get wired into onchain trading infrastructure, there is no credible way
to answer the obvious question: *which agent or strategy is actually any good?*

AgentVault is the layer that answers it.

Strategies run against real market data with **simulated capital**, inside
**real onchain permission and risk infrastructure**, producing a performance
record that cannot be faked, edited, or selectively presented.

---

## Status

**Early development. Local only.** Nothing is deployed to any public network.
Not audited. No real assets, no custody, no live trading.

Milestone 1 of 12 complete. See [`docs/ROADMAP.md`](docs/ROADMAP.md).

---

## What makes the record credible

- **Complete.** Every proposal is recorded — including rejections and losses.
  There is no code path that discards an unflattering result.
- **Realistic.** Fills are simulated against actual pool reserves with real
  price impact and fees. Mid-price fills would make every strategy look
  brilliant and destroy the product's only value.
- **Segmented.** Separate leaderboards by asset tier and risk mandate. A
  speculative strategy on a two-day-old token and a conservative strategy on
  WETH are not comparable.
- **Portable.** The record attaches to an NFT and survives transfer.

## Architecture in one line

**The AI proposes. Deterministic code decides. Always.**

```
market data → AI proposal (typed, schema-validated)
            → deterministic sizing
            → risk engine: approve / reject
            → simulated fill against real pool reserves
            → permanent onchain record
```

The agent emits a structured proposal and nothing else. It cannot construct
arbitrary calldata, raise its own limits, renew its own session key, change the
risk mandate, or disable the kill switch. Every one of those is an invariant
with a test.

## Core objects

| Object | What it is | Who controls it |
|---|---|---|
| Genesis Agent NFT | Account identity and ownership handle | Holder |
| Archetype | Permanent collectible identity — Guardian, Navigator, Tactician, Maverick | Immutable at mint |
| Risk mandate | Financial risk setting — Preservation, Balanced, Tactical, Speculative | Holder, changeable |
| Smart account | Isolated per-NFT account | Holder |
| Session key | Time-limited, scoped agent permission | Holder grants and revokes |
| Risk engine | Deterministic validator, final authority | Protocol code |
| Performance registry | Append-only record | No privileged write path |

**Archetype never controls financial risk.** Collectible identity and financial
risk are separate contracts with explicit tests enforcing the separation. A
rare NFT gets better art and more software features — never a higher leverage
limit, a wider drawdown allowance, or preferential execution.

---

## Repository layout

```
docs/                      specifications and registers
packages/contracts/        Solidity contracts and Foundry tests
scripts/                   setup and maintenance
```

Directories are created as their milestones arrive. Empty scaffolding is
clutter.

## Documentation

| File | Contents |
|---|---|
| [`docs/PRODUCT.md`](docs/PRODUCT.md) | What this is and what it deliberately is not |
| [`docs/DECISIONS.md`](docs/DECISIONS.md) | Every major decision, why, its cost, and what would reverse it |
| [`docs/ASSUMPTIONS.md`](docs/ASSUMPTIONS.md) | Verified vs unverified vs blocking — plus a corrections log |
| [`docs/INTEGRATIONS.md`](docs/INTEGRATIONS.md) | External dependencies and their verification gates |
| [`docs/THREAT-MODEL.md`](docs/THREAT-MODEL.md) | Threats by attacker objective, plus testable invariants |
| [`docs/ROADMAP.md`](docs/ROADMAP.md) | 12 milestones, launch gates, acceptance criteria |
| [`docs/LEGAL-QUESTIONS.md`](docs/LEGAL-QUESTIONS.md) | Questions for counsel — questions, not answers |
| [`docs/STATE.md`](docs/STATE.md) | Current state at a glance |

---

## Build and test

Requires [Foundry](https://book.getfoundry.sh/getting-started/installation).

```bash
git clone https://github.com/YOUR-USERNAME/agentvault.git
cd agentvault/packages/contracts
forge install foundry-rs/forge-std
forge build
forge test -vv
```

Expected: **7 passed, 0 failed.**

`forge-std` is Foundry's standard test library. It is not committed to this
repo, so `forge install` fetches it on first setup.

---

## Engineering principles

1. No real capital until legal review and an independent audit are complete.
   Simulation only.
2. No fabricated addresses, RPC URLs, chain IDs, or capabilities. Anything
   unverified gets a typed interface, a mock, and an entry in
   `docs/INTEGRATIONS.md`.
3. Collectible identity and financial risk stay in separate contracts.
4. The AI proposes; deterministic code decides.
5. The holder can stop automation immediately, without anyone's approval.
6. No language implying guaranteed returns, safety, or that the system cannot
   lose money.

---

## Disclaimers

This software is experimental and unaudited. Nothing here is investment, legal,
or tax advice. Nothing here is an offer to sell or a solicitation to buy any
security or financial instrument.

Trading involves risk of loss. Nothing in this project guarantees returns,
preserves capital, or prevents losses. Simulated results are not live
performance and are not predictive of it.

## License

MIT — see [`LICENSE`](LICENSE).
