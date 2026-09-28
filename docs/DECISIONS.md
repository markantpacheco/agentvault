# AgentVault — Decision Record

Why things are the way they are. Append new decisions; do not delete old ones —
a reversed decision is more useful with its history attached.

Format: what was decided, why, what it costs, and what would reverse it.

---

## D1 — Simulated capital, not real capital (2026-08-19)

**Decided:** The product launches with simulated capital and real market data.
No user funds.

**Why:** Removes custody, advice, and management from the picture almost
entirely. Also the only version buildable solo in ~10 weeks. The original spec
already required 90 days of forward testing before Speculative went live — this
ships that as the product rather than as a gate.

**Cost:** No trading revenue. Harder to convince users it matters.

**Reverses if:** Legal review clears a specific live-trading configuration
*and* an audit is complete. Not before both.

---

## D2 — Not an AI-managed trading protocol (2026-08-19)

**Decided:** Dropped discretionary AI trading of user accounts.

**Why:** Two reasons. (a) Discretionary authority over another person's account
is the *most* regulated arrangement in the adviser framework, not the least.
Automation is why robo-advisers register, not why they don't. (b) Robinhood
already shipped Agentic Accounts with distribution to millions of funded
accounts. That race is over.

**Correction recorded:** An early working assumption was that automated
execution is *less* adviser-like than recommend-and-wait. That is backwards.
The law asks who exercises investment judgment, not who clicks the button.

**Cost:** Loses the most exciting-sounding version of the pitch.

**Reverses if:** Registration is pursued deliberately with counsel, as a
business decision rather than an oversight.

**Reviewed 2026-09-18:** Unaffected by the Innovation Exemption. That order is
Exchange Act relief; the Advisers Act is a separate statute. See D9.

---

## D3 — Reputation layer, not competitor (2026-08-19)

**Decided:** Position as the proving ground and reputation layer for agents on
the chain — complementary to the platform's agent product, not competing.

**Why:** The chain operator has the rails and the distribution. The unanswered
question is which strategies actually work, and they have no incentive to
answer it honestly. Reputation compounds: every recorded month makes the
dataset harder to replicate.

**Cost:** Less immediately legible than "AI that trades for you."

**Reviewed 2026-09-18:** Strengthened. The Innovation Exemption requires TSVs
to publish transaction data at regular intervals. A market with mandated public
trade data is one where an independent, verifiable performance layer is more
useful, not less.

---

## D4 — Robinhood Chain, not Hyperliquid (2026-08-19)

**Decided:** Deploy on Robinhood Chain. Write contracts chain-agnostic.

**Why:**
- Hyperliquid's native third-party vaults already provide verifiable onchain
  copy-trading performance. The differentiator is largely solved there.
- 170+ projects on HyperEVM as of March 2026, $2B TVL — crowded, funded
  competition.
- Hyperliquid's centre of gravity is perpetuals (derivatives, CFTC exposure)
  and it geoblocks U.S. persons.
- HyperCore/HyperEVM with precompiles is a harder first dev surface than a
  standard Arbitrum Orbit L2.
- Robinhood Chain is new, uncrowded, and actively recruiting builders with
  $1M committed to Arbitrum Open House.

**Key realisation:** The chain hosting the record and the market being
simulated are *separate choices*. Contracts on Robinhood Chain; simulation can
use whatever market data is most liquid.

**Reverses if:** CFTC opens Hyperliquid to U.S. persons *and* the product
moves to real capital. Revisit ~Feb 2027.

**Reviewed 2026-09-18:** Held, with a caveat. The Innovation Exemption makes
U.S.-facing chains more attractive to funded teams. The uncrowded-chain
advantage now decays faster than assumed in August. Grant application should
move sooner rather than later.

---

## D5 — Two asset tiers, Volatile included (2026-08-19)

**Decided:** Core tier (ETH/WETH/stables/established) and Volatile tier
(memecoins). Build Core first.

**Why:** Memecoins are where the chain's real liquidity and users are. RWA
activity on the chain is thin. Memecoins also sit further from securities
classification than tokenized equities. Maverick was always the volatility
archetype — this was anticipated.

**Cost:** Requires an AMM fill simulator and a token safety screener that the
original plan did not have. Adds roughly one week.

**Reviewed 2026-09-18 — held, and partially validated.** The Innovation
Exemption is built on permissioned AMM liquidity pools, so fill simulation
against pool reserves with real price impact is the correct model for tokenized
equities under the framework too, not only for memecoins. The Volatile-tier
work is therefore not a detour.

Reasons for holding the scope unchanged:
- The exemption does not create tokenized NMS liquidity on Robinhood Chain.
  No TSV has announced there.
- Volume caps are deliberately small (0.25% of ADV for up to 75 symbols).
- Issuers can object to tokenization on a given venue.
- The three original reasons for avoiding tokenized equities — adviser
  exposure, absent liquidity, solo-builder capacity — are all untouched.

**Forward path:** keep the asset layer as configuration so a third tier
("Regulated RWA") can be added if and when compliant tokenized NMS stock exists
on this chain with real depth, and counsel has cleared the position.

---

## D6 — Mint deferred (2026-08-19)

**Decided:** No NFT mint until the product is live and has real users.

**Why:** A mint converts users into creditors on day one. Same supply is worth
more after utility exists. Far more defensible with live utility and no claims
about future value. A stalled project after a mint follows you permanently.

**Cost:** No upfront funding. Mitigated by grant applications.

**Note:** The NFT itself is *not* dropped. It is load-bearing here because it
is the ownership handle on a live account with persistent state and an
accumulating record — something a subscription cannot transfer.

---

## D7 — Realistic fills are non-negotiable (2026-08-19)

**Decided:** Simulated fills price against actual pool reserves with real
price impact, fees, and failure modes.

**Why:** Mid-price fills would make every memecoin strategy look brilliant.
Publishing those records would be worse than screenshots — fake data wearing
the appearance of proof. This is the product, not a refinement.

---

## D8 — Funding via grants before mint (2026-08-19)

**Decided:** Pursue Robinhood ecosystem grants and Arbitrum Open House
buildathons.

**Why:** A new chain whose dominant activity is memecoins is highly motivated
to fund a legitimate application. Applying from a position of working code is
far stronger than a whitepaper. That window closes as the ecosystem fills.

**Contact on file:** `chain-developers-group@robinhood.com` (from official
chain docs — verify before sending).

**Updated 2026-09-18:** Priority raised. See D4 review note.

---

## D9 — Innovation Exemption reviewed; scope unchanged (2026-09-18)

**Context:** On 2026-09-17 the SEC issued the Innovation Exemption, granting
five-year conditional relief to Tokenized Securities Venues from the "exchange"
definition and to certain liquidity providers from "dealer" registration.
Details in `ASSUMPTIONS.md` V17.

**Decided:** No change to product scope, asset tiers, or roadmap.

**Why:**
- The relief is under the Exchange Act. The Advisers Act question that drove
  D1 and D2 is a different statute and is unaffected.
- The relief runs to venues and proprietary liquidity providers. AgentVault is
  neither and should not attempt to become one.
- The order expressly excludes synthetic products, which is what Robinhood's
  existing Stock Tokens are. It does not open those to U.S. persons.
- No tokenized NMS liquidity exists on the target chain today.

**What did change:**
- Grant application priority raised (D4, D8)
- Fill-simulation approach validated (D5)
- New blocking unknown B6: whether agent-mediated order flow is permissible on
  a TSV, and under what conditions
- New action: submit a public comment letter on the order's request for comment

**Reverses if:** A TSV begins operating on Robinhood Chain with meaningful
depth in tokenized NMS stock, *and* counsel clears a configuration in which
this product interacts with it. Both, not either.

**Process lesson:** The August entry recorded this exemption as possibly
abandoned after a cancelled meeting. It arrived four weeks later. Regulatory
assumptions get re-checked monthly from now on.

---

## D10 — Prototype mint: permissionless, one-per-address, free, capped supply (2026-09-25)

**Decided:** The Milestone 3 `GenesisAgent` mint is permissionless (any address
may call), limited to one token per address ever, free, and capped at a
constructor-set immutable `maxSupply`, deployed at 10,000. All four values are
PROTOTYPE.

**Why:**
- Permissionless and free matches the business sequencing: ship free, run
  publicly, mint later (D6). An allowlist or a price would add operational work
  and a privileged role for no prototype benefit.
- A supply cap is cheap insurance. It is immutable, so it cannot be raised
  later by anyone, including a privileged role added in a future milestone.
  10,000 is a placeholder — `ROADMAP.md` commits to sizing real supply to
  actual user count, and this decision does not pre-empt that.
- A zero cap is rejected at deploy because it would produce a permanently
  unmintable contract that otherwise looks like a successful deployment.

**The one-per-address limit is NOT sybil resistance.** It is a courtesy limit
for a faucet-style testnet mint: it stops one script taking the whole prototype
supply in a single transaction. Addresses are free, so anyone wanting more
tokens simply uses more addresses. Nothing in this system may assume that one
address means one person. The limit keys on *has ever minted* rather than
*currently holds*, which closes the transfer-away-and-re-mint loop but does
nothing about fresh addresses, because nothing can.

**No admin role, and no `Ownable`.** `GenesisAgent` has no owner, no admin,
and no role-gated function, because there is no owner-only function for one to
gate. An unused privileged role is an attack surface with no corresponding
benefit — exactly what `THREAT-MODEL.md` T5 (malicious or compromised insider)
argues against. Nothing that does not exist can be compromised, and no actor
can alter an assigned archetype even in principle.

Metadata hosting, and any setter it requires, are **Phase 8**, gated on an
`INTEGRATIONS.md` entry with a verification gate like every other external
dependency. `tokenURI` is therefore deliberately unimplemented rather than
stubbed, so that the absence is documented here and in
`docs/specs/GenesisAgent.md` rather than discovered later by someone wondering
why it returns nothing. A role is introduced in the milestone that actually
needs one — most likely Milestone 6, when transfer-triggered permission
revocation arrives.

**Cost:** The prototype leaderboard and account set can be padded by anyone
willing to spend gas on multiple addresses. Accepted: with simulated capital
and no payment there is nothing to win, and the record is segmented per NFT
anyway.

**Production gating is deferred to Phase 8**, decided together with the
archetype randomness mechanism, since both concern how a real mint distributes
scarce things fairly. Candidates: allowlist, proof-of-personhood, paid mint,
or a curated onboarding — none chosen.

**Reverses if:** the mint stops being free, or the prototype is exposed to an
audience where a padded record would mislead someone.

---

## D11 — Mandate ships without cooling-off or a strategy registry (2026-09-26)

**Decided:** Milestone 5 ships mandate *selection* only. Three pieces named in
the roadmap deliverable are deferred:

1. **Cooling-off on raising risk.** Lowering a mandate's risk should take
   effect immediately; raising it should wait. `MandateLib.riskRank` exists and
   is tested precisely so that comparison is available when the rule is
   written, but no delay is enforced today.
2. **Strategy registry.**
3. **Mandate–strategy compatibility checking.**

**Why:**
- Cooling-off is a scheduling choice, not an oversight. It appears nowhere in
  the demo, and time-based tests — warping, boundary conditions either side of
  the delay, interaction with the transfer reset — cost hours this sprint does
  not have. Writing it badly is worse than not writing it: a cooling-off period
  that can be bypassed is a false guarantee, and rule 6 forbids implying a
  safety the system does not have.
- No strategies exist. A registry of nothing is ceremony. When strategies
  arrive, compatibility checking belongs in the risk engine, which is where the
  deterministic decision already lives, not in a registry beside it.

**Cost:** A holder can raise risk instantly today. In a simulation with no live
execution path that costs nothing real, but it must be closed before any
configuration with live capital — and the live-capital gate in `ROADMAP.md`
already blocks that independently.

**What this is NOT:** the absence of cooling-off is not a claim that raising
risk is safe, and `Speculative.liveEligible == false` is not a claim that live
execution exists. Nothing in this system has a live-execution path.

**Reverses if:** the risk engine lands (Milestone 7) — cooling-off should be
written alongside it, since that is where risk changes are already validated.

**Also decided here: views never expose raw account state.** Transfer
detection is lazy, so between a transfer and the new holder's first interaction
stored state still describes the previous holder. `getAccount`, `mandateOf`,
`mandateParamsOf` and `isAutomationPaused` all route through
`_effectiveAccount`, which applies the pending-transfer transformations in
memory. Without it, `mandateParamsOf` would hand out the seller's risk limits
to anything that read it before somebody happened to interact — and the risk
engine sizing a position off those limits would be working from an appetite the
current holder never chose. Recorded as a convention in `CLAUDE.md` because it
applies to every future view, not just these four.

---

## D12 — Two mandate parameters are specified but not enforced (2026-09-26)

**Decided:** `RiskEngine` enforces `maxPositionBps` and `maxSlippageBps`. It
does **not** enforce `maxOpenPositions` or `maxDailyDrawdownBps`, which remain
in `MandateParams` and in the PROTOTYPE table, carrying `TODO(positions)` and
`TODO(drawdown)` comments at the site where each check would go.

**Why they cannot be enforced yet:**

- **`maxOpenPositions`** needs open-position tracking. Nothing records what an
  account currently holds — `AccountRegistry` stores a balance, not positions.
  Enforcing the cap would mean inventing that state here, in a `view` function
  that writes nothing, which is impossible by design.
- **`maxDailyDrawdownBps`** needs PnL history with daily boundaries. The
  registry derives PnL from a point-in-time balance and has no history and no
  concept of a day. Enforcing it would require the same invented state.

Both belong with execution and settlement, which is where positions and
realised PnL will first exist.

**Why leave them visible rather than delete them:** they are real parts of the
mandate design and will be enforced. Removing them would lose the design;
silently not enforcing them would be worse than either. **A parameter that
looks enforced and is not is more dangerous than one openly marked pending** —
the first invites someone to rely on it.

**What this means concretely today:** a mandate's position cap and slippage cap
bind. Its open-position count and daily drawdown limit do **not**. Nobody
should describe an account as drawdown-limited, in code, docs, or UI, until
this entry is superseded. That is also why `RiskEngine` states the
`MAX_DATA_AGE` self-reporting limitation in a comment rather than letting a
freshness check imply an oracle guarantee it does not have.

**Reverses if:** execution and settlement land, giving positions and realised
PnL somewhere real to live. Drawdown enforcement should be written alongside
them, not before.

---

## D13 — The first RiskEngine allowlist holds purpose-deployed test assets, not the faucet's tokenized equities (2026-09-26)

**Decided:** The first `RiskEngine` deployed to testnet allowlists two
purpose-built ERC-20s — `AgentVault Test Asset A` (AVTA) and
`AgentVault Test Asset B` (AVTB), source at `src/mocks/TestAsset.sol`. It does
**not** allowlist the five tokenized equities the faucet supplied: TSLA, AMD,
AMZN, NFLX and PLTR.

**Why:** The allowlist has no setter. It is fixed at construction, and changing
it means deploying a new engine. That makes it the configuration seam through
which assets will eventually arrive — and it makes **what goes into it at first
deployment a positioning statement**, not merely a test fixture.

This project's recorded position excludes securities:

- **D5** chose Core (ETH/WETH/stables) and Volatile (memecoins) tiers,
  reasoning explicitly that memecoins "sit further from securities
  classification than tokenized equities". Tokenized equities are neither tier.
- The `ASSUMPTIONS.md` corrections log records "tokenized stocks are the natural
  asset class for this chain" as an assumption that turned out **wrong**, and
  separately that "tokenized securities remain securities".
- **`PRODUCT.md`** states this is not advice on securities.
- `STATE.md` still records "securities lawyer — not engaged".

An engine whose entire permanent allowlist was TSLA, AMZN, NFLX, PLTR and AMD
would contradict all four, in a public repository with verified source and a
demo aimed at judges. The technical exposure is small — testnet, simulated
capital, and `RiskEngine` only validates and cannot execute — but the
positioning is not, and positioning is the thing the allowlist permanently
encodes.

**Why assets were deployed rather than borrowed:** the faucet supplied **no
in-tier alternative**. There is no WETH and no settlement stablecoin on this
testnet (`INTEGRATIONS.md` I9 and I10, both still MOCK), so there was nothing
neutral to point at. Deploying two deliberately characterless tokens was the
only option that neither fabricated an address nor made an asset-class claim.

**Cost:** the allowlisted assets are not real, so the testnet demo validates
against tokens with no market, no price and no liquidity. That costs nothing
today, because nothing prices or executes anything yet — the fill simulator and
the AMM adapters are still MOCK. It would matter the moment either exists.

**The five equity addresses stay recorded** in `INTEGRATIONS.md` I13 with their
on-chain verification intact. The verification work is real and worth keeping if
an in-tier asset appears later, or if the position changes with counsel's input.
Recorded, verified, and not used.

**Reverses if:** an in-tier asset becomes available on this testnet, or counsel
reviews and clears a specific configuration involving tokenized equities. Either
way it means a new engine deployment, which is the intended mechanism rather
than a workaround.

---

## D14 — `sizeUnits` is a normalised 18-decimal unit, not a token amount (2026-09-28)

**Decided:** `TradeProposal.sizeUnits` is a **normalised simulated unit at 18
decimals**, independent of the traded asset's native decimals. `RiskEngine`
never calls `decimals()` on anything, and never will. Conversion between
normalised units and token-native amounts belongs at the execution or fill
boundary, not in the validator.

**Why this needed deciding now:** until 2026-09-28 the allowlist held only
AVTA and AVTB, both 18-decimal, so the question was invisible — every plausible
interpretation gave the same answer. Adding Paxos USDG, which is **6-decimal**
(`INTEGRATIONS.md` I16), makes the ambiguity real for the first time. Mixing
conventions inside one allowlist is precisely when an unstated assumption turns
into a bug.

**Why normalised rather than token-native:**

- The position cap compares `sizeUnits` against the account's **simulated
  balance**, which is simulated capital at 18 decimals — not a token balance.
  Comparing a token-native amount against it would be comparing two different
  units and calling the result a limit.
- A validator that reads `decimals()` gains a dependency on every allowlisted
  token behaving honestly. `decimals()` is not part of the ERC-20 required
  interface, can revert, and on a proxy can change. A pure validator should not
  have that surface.
- Keeping the engine asset-agnostic means adding an asset never changes how
  sizing is interpreted.

**The concrete hazard, stated plainly:** passing a native 6-decimal USDG amount
where a normalised 18-decimal one is expected **understates the position by a
factor of 10^12** and passes every cap trivially. In the other direction it
overstates by the same factor and rejects everything. The first is far more
dangerous, because it fails open.

**This is latent, not live.** Nothing prices or executes anything yet — I5
(oracle), I6 (venue adapter) and I7 (pool state) are all still MOCK, and
`RiskEngine` cannot execute. The hazard becomes real the moment a fill simulator
exists. A `TODO(decimals)` marks the position-cap site, and the rule is stated
at the `TradeProposal` struct as well, so it is visible from both the type and
the check that depends on it.

**Cost:** anyone building execution must write and test a conversion layer, and
get it right per asset. That is real work that a token-native convention would
have avoided — but it would have moved the same problem into the risk engine,
where it would be harder to see and would compromise the validator's
independence from token behaviour.

**Reverses if:** execution lands and the boundary turns out to be cleaner with
token-native amounts throughout. That is a decision to make with the fill
simulator in front of you, not before it exists.
