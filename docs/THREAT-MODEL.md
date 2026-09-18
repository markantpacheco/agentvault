# AgentVault — Threat Model

Organised by what an attacker wants, because that is how attackers think.

**Scope note:** with simulated capital there are no user funds to steal, which
removes most of the financial attack surface. The threats below are written for
the architecture as designed, so that the safety properties are correct from
the start rather than retrofitted. The two categories that are live *today*
are **record integrity** and **developer workstation**.

**Last reviewed:** 2026-08-19

---

## T1 — Attacker wants to corrupt the performance record

**Live today. This is the product's core value, so it is the core target.**

| Threat | Mitigation |
|---|---|
| Selectively omit losing trades | Append-only registry; every proposal recorded at submission, before outcome is known |
| Replay a winning result | Proposal includes a data snapshot hash and expiry; duplicate submission rejected |
| Naive fills inflate results | Fills priced against real pool reserves with impact and fees (D7) |
| Compare incomparable strategies | Leaderboards segmented by asset tier and mandate |
| Cherry-pick the reporting window | Full outcome distribution published, not just top-line return |
| Rewrite history after the fact | No update or delete path on recorded results; enforced by test |

**Failure means the product is worthless.** Fake data wearing the appearance
of proof is worse than screenshots.

---

## T2 — Attacker wants user funds

Not live while capital is simulated. Design holds regardless.

| Threat | Mitigation |
|---|---|
| Compromise AI service, propose a drain | AI emits typed proposal only; sizing computed separately; risk engine rejects out-of-policy; session key cannot transfer to arbitrary addresses |
| Prompt injection via market data or token metadata | External text is untrusted **data**, never instruction; output schema-validated; malformed output rejected outright, not best-effort parsed |
| Steal a session key | Short expiry, narrow scope, no withdrawal rights, instant revocation, key never in repo |
| Oracle manipulation | Freshness and deviation bounds; auto-pause on failure |
| Sandwich attacks | Enforced slippage caps, minimum liquidity, size limits |
| Honeypot token | Token safety screener before any Volatile-tier position (I8) |

---

## T3 — Attacker wants to break account isolation

| Threat | Mitigation |
|---|---|
| NFT #7 spends NFT #9's balance | One account per NFT; no shared balance storage; explicit invariant test |
| Reentrancy during execution | Checks-effects-interactions; reentrancy guards; no untrusted callback mid-state-update |
| Storage collision between modules | Namespaced storage; layout documented and tested |

---

## T4 — Attacker acquires or steals an NFT

| Threat | Mitigation |
|---|---|
| Inherit previous owner's active automation | Transfer revokes all permissions, pauses automation, forces Starter Mode. Named acceptance criterion with its own test. |
| Front-run a pending sale | Prepare-for-Sale unwinds and revokes before listing |
| Claim the previous owner's track record as their own | Performance segmented by owner period; owner transitions recorded |

---

## T5 — Malicious or compromised insider

| Threat | Mitigation |
|---|---|
| Team keys move user assets | Pause role can halt activity but is structurally incapable of moving, redirecting, or trading user assets. Written as an invariant and tested. |
| Silent upgrade adds a backdoor | No upgradeability by default. If added: timelock, published diffs, documented path to renounce. |
| Admin edits the leaderboard | No privileged write path to the performance registry |

---

## T6 — Failure without an attacker

| Threat | Mitigation |
|---|---|
| Venue / RPC outage | Circuit breakers; degrade to paused, never to unvalidated execution |
| Stuck or duplicate transaction | Idempotent jobs, nonce management, retry limits, dead-letter queue |
| Sequencer downtime | Withdrawal path must work even when every automated component is down |
| Silent data staleness | Freshness checks fail closed, not open |

---

## T7 — Developer workstation

**Live today. Most likely category to actually bite a solo builder.**

| Threat | Mitigation |
|---|---|
| Secret committed to GitHub | `.gitignore` before first commit; `.env.example` with no real values; `git status` checked every time |
| Private key pasted into a chat or file | Hard rule: never. No exceptions, no "just testnet". |
| Malicious npm or Foundry dependency | Minimal dependencies; prefer audited OpenZeppelin; review anything new |
| Laptop compromise | No mainnet key on the dev machine; hardware wallet before any real deployment |

---

## Invariants to test

These are the properties that must hold under fuzzing, not just in the
happy path.

1. An agent can never increase its own permissions
2. An agent can never move assets to a non-allowlisted address
3. Sum of per-account balances never changes due to an operation on another account
4. Archetype is never writable after mint
5. A recorded performance entry is never modified or deleted
6. Kill switch never blocks withdrawal
7. Risk mandate can always be lowered immediately
8. Rarity has no effect on any risk limit
9. Speculative mandate has no live-execution code path
10. Deposits never increase recorded profit
