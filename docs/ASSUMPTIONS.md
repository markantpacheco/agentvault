# AgentVault — Assumptions Register

Three categories. The distinction is the difference between a project that
survives contact with reality and one that does not.

**Rule:** nothing moves from Unverified to Verified because it appeared in a
blog post, a Discord message, or an LLM response. Verified means checked
against an official source, and for anything onchain, checked by querying the
chain directly.

**Last reviewed:** 2026-09-18

---

## Verified

| # | Fact | Source | Checked |
|---|---|---|---|
| V1 | Robinhood Chain mainnet live since 2026-07-01 | Robinhood support pages | 2026-08-19 |
| V2 | Mainnet chain ID 4663 | Measured: `cast chain-id` against mainnet RPC (also Robinhood support article) | 2026-09-26 |
| V3 | Testnet chain ID 46630 | **Measured: `cast chain-id` against testnet RPC** (closes U1; also official docs + Alchemy) | 2026-09-26 |
| V4 | Arbitrum Orbit / Nitro L2, settles to Ethereum, ETH for gas | Official docs | 2026-08-19 |
| V5 | Fully EVM-compatible; Foundry, Hardhat, ethers, viem, Wagmi work unmodified | Official docs | 2026-08-19 |
| V6 | Contract deployment is permissionless | Official docs | 2026-08-19 |
| V7 | First-class ERC-4337 support incl. session keys, batching, gas sponsorship | Official docs | 2026-08-19 |
| V8 | 123,181 ERC-4337 smart accounts, 1.6M user operations | Chainstack | 2026-08-19 |
| V9 | Alchemy is recommended infra provider (RPC, bundler, gas manager) | Official docs | 2026-08-19 |
| V10 | Uniswap, Pleiades, Morpho, Lighter deployed | Chainstack, ecosystem page | 2026-08-19 |
| V11 | Robinhood Stock Tokens are tokenized debt securities, Jersey issuer, barred to U.S. persons | Robinhood's own disclosure | 2026-08-19 |
| V12 | $1M committed to 2026 Arbitrum Open House; 4 buildathons, 2 founder houses | Arbitrum blog | 2026-08-19 |
| V13 | SEC approved Nasdaq tokenized securities rule 2026-03-18 | SEC release 34-105047 | 2026-08-19 |
| V14 | SEC approved NYSE tokenized securities rule 2026-04-17 | SEC release, SR-NYSE-2026-17 | 2026-08-19 |
| V15 | DTC no-action letter; tokenization service H2 2026, 3-year term | DTCC announcement | 2026-08-19 |
| V16 | SEC staff position: onchain format does not change securities law application | SEC statement 2026-01-28 | 2026-08-19 |

### V17 — Innovation Exemption issued 2026-09-17 (supersedes prior V17)

Source: SEC press release 2026-90; statements by Chairman Atkins and
Commissioner Uyeda, both dated 2026-09-17. Checked 2026-09-18.

- Temporary, conditional relief under Exchange Act section 36(a)(1)
- **Relief 1:** Tokenized Securities Venues (TSVs) exempt from the definition
  of "exchange," permitting trading of tokenized NMS stock through
  permissioned automated market makers and liquidity pools
- **Relief 2:** liquidity providers supplying tokenized NMS stock with
  proprietary capital in those pools exempt from "dealer" registration
- Effective immediately; expires five years after publication
- No SEC designation required. A venue self-certifies: publish a specified
  notice on its public website at least 30 calendar days before operating,
  then notify the SEC in writing within one business day
- Tokens must carry rights equivalent to the underlying equity
- Issuers receive 30 days' notice and may object to tokenization on a
  specific venue
- Volume caps: 0.25% of average daily volume for up to 75 highly liquid
  securities; up to 250 securities at a 2.5% threshold
- Public transaction data required at regular intervals: price, size, time,
  pool address, end-of-day pool size, daily volume
- **Explicitly excludes synthetic products** — tokenized linked securities and
  tokenized security-based swaps providing only synthetic exposure
- Paired with a request for public comment

---

## Implications of V17 for this project

Recorded because the temptation to over-read this is real.

| Claim | Status |
|---|---|
| Relieves investment-adviser obligations | **No.** Exchange Act relief only. The Advisers Act is a separate statute and is untouched. |
| Makes Robinhood's existing Stock Tokens available to U.S. persons | **No.** Those are Jersey-issued synthetic/debt instruments — the category the order expressly excludes. Robinhood's own contractual restriction is also unaffected. |
| Lets a solo developer trade tokenized equities | **No.** Relief runs to venues meeting TSV conditions and to liquidity providers using proprietary capital. |
| Creates tokenized NMS liquidity on Robinhood Chain today | **No.** No TSV has been announced there. Volume caps are deliberately small. |
| Could put compliant tokenized NMS stock on this chain within 1–2 years | **Plausible.** Worth tracking. Does not change current build scope. |
| Validates AMM-reserve fill simulation as the right model | **Yes.** The framework is built on permissioned AMM pools, matching the fill model already chosen for the Volatile tier. |

---

## Unverified — check before writing integration code

Each gets a typed interface and a mock until confirmed. See `INTEGRATIONS.md`.

| # | Assumption | How to verify |
|---|---|---|
| U2 | Canonical ERC-4337 EntryPoint address and version | Query chain; check bytecode. **Never** take an EntryPoint address from a blog. |
| U3 | ERC-6551 registry deployed at the usual deterministic address | Query chain |
| U4 | Any oracle publishes prices on this chain, for which assets, at what cadence | Check Chainlink / Pyth / RedStone deployment pages, then query |
| U5 | Which DEXs have real depth (not just "deployed") | Query pool reserves at intended trade sizes |
| U6 | Canonical WETH address | Query chain / official docs |
| U7 | Settlement stablecoin address and whether it has freeze capability | Read contract source |
| U8 | Alchemy gas sponsorship works for arbitrary custom smart accounts | Test a UserOperation |
| U9 | Testnet has usable test assets | Faucet + explorer |
| U10 | Chain TVL and RWA share | ~$76.7M TVL and ~$12.8M RWA both reported July 2026. Stale. Re-check DefiLlama. |
| U11 | Robinhood dev contact address still active | Send one email |
| U12 | Innovation Exemption order number (reported as 34-106402) | Confirm against sec.gov directly before citing anywhere |
| U13 | Comment deadline for the Innovation Exemption | Tied to Federal Register publication. Check the Federal Register notice. |
| U14 | Whether any TSV intends to operate on Robinhood Chain | Watch for the 30-day public notices the order requires |

---

## Blocking unknowns — gate real money, not code

None block Milestones 1–10. All block any live-capital phase.

| # | Unknown |
|---|---|
| B1 | Legal status of the product for a U.S.-based builder and for users by jurisdiction |
| B2 | Whether any live-capital configuration triggers investment-adviser registration |
| B3 | Whether the NFT sale is a securities offering |
| B4 | Whether tokenized-stock liquidity will ever support real strategy execution |
| B5 | Whether platform terms permit third-party automation around their assets |
| B6 | Whether agent-mediated order flow is permissible on a TSV, and under what conditions |

See `LEGAL-QUESTIONS.md`.

---

## Corrections log

Assumptions that turned out to be wrong. Kept deliberately.

| Date | Wrong assumption | Correction |
|---|---|---|
| 2026-08-19 | Automated execution is less adviser-like than recommend-and-wait | Backwards. Discretionary authority is the most regulated arrangement. Robo-advisers register. |
| 2026-08-19 | Tokenized stocks are the natural asset class for this chain | RWA activity is thin; memecoins and stables dominate. Risk engine would reject most RWA trades on liquidity grounds — correctly. |
| 2026-08-19 | "SEC approved tokenized stock trading" means the asset class opened up | Approvals were for regulated exchanges and DTC infrastructure. Tokenized securities remain securities. |
| 2026-09-18 | The Innovation Exemption may never arrive (recorded 2026-08-19 after the Aug 14 meeting was cancelled) | It arrived 2026-09-17, two days after the Senate failed to advance the CLARITY Act. Lesson: "delayed indefinitely" is not "abandoned." Re-check regulatory assumptions monthly, not quarterly. |
| 2026-09-26 | Testnet chain ID might be 46646 (one third-party source, recorded 2026-08-19 as U1) | Wrong. `cast chain-id` against `https://rpc.testnet.chain.robinhood.com` returned **46630**, matching the official chain docs. **There is no discrepancy with the official docs** — the third-party figure was simply incorrect. U1 closed and folded into V3. `.env.example` already had 46630 and needed no change. Lesson: a single unsourced third-party number is not enough to cast doubt on first-party docs; measure early and cheaply instead of carrying the doubt for five weeks. |
| 2026-09-28 | A single green test run establishes that the suite passes | Wrong, and it cost real credibility. The deploy-script guard tests were flaky from the moment they were written: `vm.setEnv` mutates the shared process environment and Foundry runs test CONTRACTS in parallel, so two files both setting `EXPECTED_CHAIN_ID` clobbered each other mid-test. Local runs passed and "126 passing" was reported more than once on that basis. A clean-clone check caught it, and running the suite five times then failed **three**. The first fix was also wrong — consolidating into a single test *function* does not help, because the race is across contracts, not functions. Replaced with: every env-dependent assertion in one function in one contract, and **run a suite five to eight times before trusting an intermittent pass**. Applied since: the invariant suite was verified over 8 consecutive runs plus 3 explicit fuzz seeds, not once. |
