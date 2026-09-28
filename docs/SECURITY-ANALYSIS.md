# AgentVault — Security Analysis

Findings that are security-relevant rather than merely operational. Threats and
testable invariants live in `THREAT-MODEL.md`; external dependencies and their
verification live in `INTEGRATIONS.md`. This file is for things actually
encountered and what was learned from them.

**Last updated:** 2026-09-28

---

## S1 — Token-impostor surface on a permissionless chain (2026-09-28)

**Severity:** high if acted on, avoided here.
**Status:** avoided. Recorded so the method is repeatable.

### What was found

Looking for Paxos USDG on Robinhood Chain testnet (46630), a search of the
block explorer's token list for `USDG` returned **more than fifty ERC-20
contracts**, a large number of them named to appear canonical.

Five are named literally **"Paxos USDG"**, and none of them is the real one:

```
0x293b337712D4312776a3a2D292F44410E7873bAd   "Paxos USDG"   IMPOSTOR
0x0d0710E6aA1c9F2d5e04C3e2fd31cBA14131030c   "Paxos USDG"   IMPOSTOR
0x022F49dbD588908b5A1805886c2107F0315223B4   "Paxos USDG"   IMPOSTOR
0xC899788Ec20fC95D9d1A30a2eeD09DD7Aa351B45   "Paxos USDG"   IMPOSTOR
0xeB5Ef28F36da77D3Fd64EB71C270afE293b40788   "Paxos USDG"   IMPOSTOR
```

A sixth, `0x499Fc59f8847f4922850E426fbf9e82d2beaF5e3`, is named
**"Paxos Global Dollar"** — also not the real one. Alongside these sit dozens of
"Global Dollar", "Mock USDG", "Test USDG" and "Test Global Dollar" entries.

**The genuine contract is `0x7E955252E15c84f5768B83c41a71F9eba181802F`, and it
is named simply `Global Dollar`** — less official-looking than five of the
fakes.

### Why this is a security finding, not an inconvenience

Contract deployment on this chain is permissionless (`ASSUMPTIONS.md` V6).
A token's `name()` and `symbol()` are attacker-chosen strings with no authority
behind them whatsoever. Anyone can deploy a contract calling itself
"Paxos USDG" in a few seconds, for a few cents.

The consequence here would have been durable: `RiskEngine`'s asset allowlist
is **fixed at construction with no setter** (`DECISIONS.md` D13). An impostor
allowlisted at deployment is allowlisted permanently for that engine, and the
only remedy is deploying a replacement. A verified, source-published contract
carrying a fake asset would be considerably worse than an unverified one,
because verification lends it credibility.

The selection pressure is obvious: the most plausible-looking name is the one a
hurried developer picks. Ranking by apparent legitimacy actively selects for the
attacker's best work.

### The method that avoided it

In order, and the order is the point:

1. **Start from a first-party source.** Paxos publishes testnet deployments at
   `docs.paxos.com/guides/stablecoin/usdg/testnet`. That page listed
   "Robinhood Testnet" with one address. **This step decided the answer.**
2. **Confirm the chain.** `cast chain-id` against the RPC returned 46630 before
   trusting anything read from it.
3. **Read the contract directly.** `symbol()`, `name()`, `decimals()`,
   `totalSupply()` via `cast call`, plus non-empty bytecode — confirming the
   published address behaves as claimed, rather than assuming it.
4. **Cross-check for plausibility.** Blockscout reported the contract verified,
   an EIP-1967 proxy, and **3,878 holders** — a usage profile an impostor
   deployed to farm mistakes does not have.

Steps 2–4 confirm; **step 1 is what decided**. Had the search preceded the
first-party lookup, the ranking would have offered five better-named wrong
answers first.

### Rule reinforced

`ASSUMPTIONS.md` U2 already said: *"Query chain; check bytecode. **Never** take
an EntryPoint address from a blog."* This is that rule meeting a real case, and
it generalises past EntryPoint to every external address the system will ever
reference.

**An explorer token list is user-generated content.** It ranks by indexing, not
by authenticity. Treat it as a directory to confirm against, never as a source.

### Applies next to

Every remaining MOCK integration that will eventually need a real address:
I2 (ERC-4337 EntryPoint), I3 (ERC-6551 registry), I5 (price oracle),
I6/I7 (AMM venue and pool state), I9 (WETH). Each one is an opportunity to
allowlist or call an impostor. First-party source first, every time.
