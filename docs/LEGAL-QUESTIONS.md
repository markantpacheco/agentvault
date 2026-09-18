# AgentVault — Questions for Qualified Counsel

**This file contains questions, not answers.** Nothing here is legal advice.
Nothing in this repository is legal advice. These questions are for a
securities lawyer with digital-asset experience.

**Do not accept answers from:** Discord, Twitter, an LLM, a founder who
"already looked into it", or a project that appears to be doing the same
thing without consequence.

**Last updated:** 2026-08-19

---

## Context to give counsel

- Solo developer, based in the United States (Virginia)
- Product: onchain sandbox where trading strategies run against **simulated
  capital** and real market data
- No custody of user funds; no real capital managed at launch
- Onchain performance record attached to a transferable NFT
- Deployment target: Robinhood Chain (Arbitrum Orbit L2)
- Assets simulated: crypto only. **Not** tokenized equities.
- Possible later: NFT sale, subscriptions, strategy marketplace

---

## Tier 1 — Ask before the NFT sale

These are the questions that gate the highest-cost mistake. A focused review
of the sale and its marketing copy is affordable in a way a full opinion is
not, and it is the highest-value legal spend available.

1. Is a Genesis Agent NFT that grants access to a simulation platform and
   carries an onchain performance record a security under *Howey*?
2. Does displaying performance history alongside a purchasable NFT create an
   investment-contract problem, even when the performance is explicitly
   simulated?
3. What specific statements in marketing copy would move this from arguable to
   clearly problematic?
4. Do state blue-sky laws apply independently of federal analysis, and does
   Virginia impose anything additional?
5. What use-of-proceeds disclosure is advisable?
6. If the NFT is later transferable on a secondary market, does royalty income
   or floor-price marketing change the analysis?

## Tier 2 — Ask before any live capital

7. Does operating software that decides trades in a user's account constitute
   investment adviser activity under the Advisers Act or Virginia state law,
   even when noncustodial?
8. Does the publisher's exclusion plausibly apply to any configuration of this
   product, or does personalisation defeat it?
9. If the user signs every transaction themselves, does that change the
   analysis, and by how much?
10. Does a strategy marketplace make third-party publishers advisers, and does
    it make the platform a venue for unregistered advisers?
11. Does a smart account where the user holds withdrawal authority and the
    service holds a limited session key avoid custody? Where exactly is the
    line?
12. Does any part of the flow constitute money transmission federally or in
    Virginia?
13. If leveraged or perpetual products are ever added, do CFTC
    commodity-trading-adviser or commodity-pool rules attach?

## Tier 3 — Competitions and prizes

14. Does a free-to-enter competition with sponsored prizes trigger contest,
    sweepstakes, or gambling rules in any state?
15. Does any entry fee structure change that answer? (Working assumption:
    avoid paid entry with cash prizes entirely.)
16. What disclosure and eligibility terms are required for a public
    leaderboard?

## Tier 4 — Assets and jurisdiction

17. Robinhood's Stock Tokens are tokenized debt securities restricted from
    U.S. persons per their own terms. What are the implications of a U.S.
    developer building infrastructure that could interact with them, even if
    the product does not currently do so?
18. Does simulating trades in an asset carry any exposure that actually
    trading it would carry?
19. What geographic restrictions are advisable, and is IP-based geoblocking
    legally sufficient?
20. Does an offshore entity change any of the above — and what are the risks
    of assuming it does?

## Tier 5 — Later

21. What conditions would a future utility token need to avoid being a
    security?
22. Are subscription or performance-fee models permissible, and under what
    registration?
23. What are the tax reporting implications for users and for the operator?
24. What user disclosures are required before activating any automation?

---

## Working position pending advice

Recorded so the assumptions are explicit and reviewable, not because they are
conclusions.

- No real capital. No custody. No advice on securities.
- Crypto assets only in simulation. No tokenized equities.
- No claims about returns, safety, or NFT price appreciation.
- Free entry to all competitions; prizes sponsored, not pooled from entries.
- Nothing marketed as an investment.
- Mint deferred until counsel reviews the sale and its copy.
