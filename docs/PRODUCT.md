# AgentVault — Product Definition

**Status:** Product Alpha specification. Nothing here is built or deployed.
**Last updated:** 2026-08-19

---

## Problem

Anyone can claim a trading strategy works. The only evidence in circulation is
screenshots, which are free to fabricate and trivially cherry-picked. On a
chain where AI agents are being wired into trading infrastructure, there is no
credible way to answer: *which agent or strategy is actually any good?*

## Product

A sandbox where strategies run against real market data with simulated
capital, inside real onchain permission and risk infrastructure, producing a
performance record that cannot be faked, edited, or selectively presented.

## What makes the record credible

- **Complete.** Every proposal is recorded, including rejections and losses.
  There is no code path that discards an unflattering result.
- **Realistic.** Fills are simulated against actual pool reserves with real
  price impact and fees. Naive mid-price fills would make every strategy look
  brilliant and destroy the product's only value.
- **Segmented.** Separate leaderboards by asset tier and risk mandate. A
  Speculative strategy on a two-day-old token and a Preservation strategy on
  WETH are not comparable.
- **Honest metrics.** Median and max drawdown shown beside total return; full
  outcome distribution available, not just the top line.
- **Portable.** The record attaches to the NFT and survives transfer.

## Core objects

| Object | What it is | Who controls it |
|---|---|---|
| Genesis Agent NFT | Account identity and ownership handle | Holder |
| Archetype | Permanent collectible identity (Guardian / Navigator / Tactician / Maverick) | Immutable, set at mint |
| Risk mandate | Financial risk setting (Preservation / Balanced / Tactical / Speculative) | Holder, changeable |
| Smart account | Isolated per-NFT account with permissions | Holder |
| Session key | Time-limited, scoped agent permission | Holder grants and revokes |
| Risk engine | Deterministic validator, final authority | Protocol code |
| Performance registry | Permanent record | Append-only |

**Archetype never controls financial risk.** This is enforced by keeping them
in separate contracts and by explicit tests.

## Asset tiers

| Tier | Assets | Notes |
|---|---|---|
| Core | ETH, WETH, major stables, established ecosystem tokens | Default. Easier to simulate accurately. Build first. |
| Volatile | Memecoins, new listings | Where actual chain activity is. Separate leaderboard, heavier safety screening, total-loss position sizing. |

### Volatile tier requires two things Core does not

1. **Depth-based validation instead of oracle validation.** No price feed
   exists for a token launched an hour ago. Price comes from AMM reserves;
   freshness/deviation checks are replaced by depth and price-impact checks.
2. **Token safety screening** before any position: mint authority, blacklist
   or freeze capability, transfer tax, LP lock status, holder concentration,
   pool age. A strategy that picks correctly and buys a honeypot still loses
   everything.

## What this product is not

- Not a fund, vault, or managed account
- Not custodial
- Not advice on securities
- Not a live trading system
- Not a guarantee of anything

## Business model (sequenced)

1. Ship free. No mint, no payment.
2. Run publicly ~60 days. Accumulate real users and a real record.
3. Mint, sized to actual user count, with counsel reviewing sale copy.
4. Subscriptions for advanced strategies, analytics, backtesting credits.
5. Strategy marketplace with revenue share — only after the core is stable.

## Framing note

In grant applications and public copy, describe this as *agent risk and
permission infrastructure with a verifiable performance record, tested against
the chain's most volatile assets*. That is accurate. "Memecoin trading
simulator" describes the same product in a way that reads as a gambling toy
and will not get funded.
