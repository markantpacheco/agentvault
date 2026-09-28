# AgentVault — External Integration Register

**Rule:** nothing external is hardcoded. Every integration gets a typed
interface, a mock, a config placeholder, and a verification gate. Addresses
live only in `packages/config`, never inline — a fabricated address then has
nowhere to hide.

**Status key:** `MOCK` = interface + mock only · `VERIFYING` = checking now ·
`VERIFIED` = confirmed onchain, address recorded · `LIVE` = in use

**Last reviewed:** 2026-08-19

---

| ID | Integration | Status | Interface | Mock |
|---|---|---|---|---|
| I1 | Chain config (RPC, chain ID) | **VERIFIED** 2026-09-26 | chain ID 46630 measured; RPC live | Anvil still used for local tests |
| I2 | ERC-4337 EntryPoint | MOCK | `IEntryPoint` | `MockEntryPoint` |
| I3 | ERC-6551 registry | MOCK | `IERC6551Registry` | `MockRegistry` |
| I4 | Bundler / paymaster | MOCK | `IBundlerClient` | local stub |
| I5 | Price oracle | MOCK | `IPriceOracle` | `MockPriceOracle` |
| I6 | AMM venue adapter | MOCK | `IVenueAdapter` | `MockVenueAdapter` |
| I7 | AMM pool state (reserves) | MOCK | `IPoolState` | `MockPool` |
| I8 | Token safety screener | MOCK | `ITokenScreener` | `MockScreener` |
| I9 | WETH | MOCK | ERC-20 | `MockWETH` |
| I10 | Settlement stablecoin | **VERIFIED** 2026-09-28 — Paxos USDG, see I16 | ERC-20 | `MockStable` still used locally |
| I11 | Market data feed | MOCK | `IMarketData` | fixture replay |
| I12 | Block explorer verification | **VERIFIED** 2026-09-26 | Blockscout v10.2.6 at `explorer.testnet.chain.robinhood.com/api`; both contracts verified | n/a |
| I13 | Testnet tokenized equity tokens (faucet) | **VERIFIED** 2026-09-26 — verified but **NOT allowlisted** | ERC-20, 5 tokens, addresses below | n/a — real testnet contracts |
| I14 | `TestAsset` ERC-20s (purpose-deployed) | **DEPLOYED & VERIFIED** 2026-09-26 | `src/mocks/TestAsset.sol` | is itself the placeholder |
| I15 | `RiskEngine` deployment | **DEPLOYED & VERIFIED** 2026-09-26 | `src/RiskEngine.sol` | n/a |
| I16 | Paxos USDG (Global Dollar) | **VERIFIED** 2026-09-28 | ERC-20, 6 decimals | n/a — real testnet contract |

---

### I16 — Paxos USDG (Global Dollar), Robinhood Chain testnet

| Field | Value |
|---|---|
| Address | `0x7E955252E15c84f5768B83c41a71F9eba181802F` |
| Symbol / name | `USDG` / `Global Dollar` |
| **Decimals** | **6** — not 18 |
| Total supply | 56,201,240 USDG at time of check |
| Holders | 3,878 |
| Contract type | `ERC1967Proxy` (EIP-1967), verified on Blockscout |
| Implementation | `0xF0863D7A29a55d0c4263c11bFac754312ff078DF` |
| Verified | 2026-09-28 |

**How it was verified, in order:**

1. **First-party source.** Paxos publishes testnet deployments at
   `docs.paxos.com/guides/stablecoin/usdg/testnet`, which lists
   "Robinhood Testnet" with this exact address. This is the step that matters —
   see the warning below.
2. **On chain.** `symbol()`, `name()`, `decimals()` and `totalSupply()` read
   directly with `cast call` against `rpc.testnet.chain.robinhood.com`, after
   confirming `cast chain-id` returns 46630. Bytecode is non-empty.
3. **Explorer cross-check.** Blockscout reports the contract verified, an
   EIP-1967 proxy, 3,878 holders — consistent with a real, widely used testnet
   stablecoin rather than a freshly deployed impostor.

#### Warning: the explorer token list is full of USDG impostors

Searching the explorer for `USDG` returns **more than fifty ERC-20s**, many
named to look canonical: several literally called **"Paxos USDG"**
(`0x293b3377…`, `0x0d0710E6…`, `0x022F49db…`, `0xC899788E…`, `0xeB5Ef28F…`),
plus "Global Dollar", "Paxos Global Dollar", "Mock USDG", "Test USDG" and more.

**None of the ones named "Paxos USDG" is the real one.** The genuine contract is
named simply `Global Dollar`. Contract deployment on this chain is permissionless
(`ASSUMPTIONS.md` V6), so a convincing name is worth nothing.

This is the concrete case for the rule in `ASSUMPTIONS.md` U2 — never take an
address from a blog, a search result, or a token list. The only thing that
settled it was the address published by Paxos themselves, then confirmed on
chain.

#### USDG is 6 decimals; simulated balances are 18

`AccountRegistry` seeds accounts with `SEED_BALANCE = 10_000e18` and
`TradeProposal.sizeUnits` is documented as "simulated units, 18 decimals".
USDG uses **6**.

`RiskEngine` never reads a token's decimals — the allowlist is an address
check, and the position cap compares `sizeUnits` against the account balance —
so allowlisting USDG breaks nothing today. But a proposal denominated in USDG's
native 6 decimals would be 10^12 times smaller than the cap intends, and would
pass the position check trivially.

That is latent, not live, because nothing prices or executes anything yet
(I5, I6, I7 all still MOCK). It becomes real the moment a fill simulator exists.
Whoever builds that must decide explicitly whether `sizeUnits` is a normalised
18-decimal quantity or a token-native amount. Recorded here so the decision is
made deliberately rather than discovered.

#### Observation, not a concern

The implementation address behind this proxy,
`0xF0863D7A29a55d0c4263c11bFac754312ff078DF`, is the same address Paxos lists
as the USDG token on **X-Layer Testnet**. That is consistent with deterministic
(CREATE2-style) deployment of identical bytecode across chains, which is normal
practice. Noted because it looks surprising at first glance.

---

## Verification gates

Each integration is only promoted to VERIFIED when every box is ticked and the
address is recorded below.

### I2 — ERC-4337 EntryPoint
- [ ] Address obtained from official chain documentation, not a third party
- [ ] `eth_getCode` returns non-empty bytecode at that address
- [ ] Version confirmed (0.6 vs 0.7 vs 0.8 — they are not interchangeable)
- [ ] One UserOperation succeeds on testnet
- [ ] Address recorded in `packages/config`

### I3 — ERC-6551 registry
- [ ] Deployed at the expected deterministic address
- [ ] Implementation matches the published spec
- [ ] Account creation succeeds on testnet
- [ ] Address recorded

### I5 — Price oracle
- [ ] A feed actually exists on this chain for the intended assets
- [ ] Update cadence (heartbeat) documented
- [ ] Deviation threshold documented
- [ ] Decimals confirmed
- [ ] Staleness behaviour tested — what does it return when the feed is down?
- [ ] Addresses recorded per asset

### I6 / I7 — AMM venue and pool state
- [ ] Router address from official source
- [ ] Pool reserves readable
- [ ] **Price impact measured at intended trade sizes, not at $1**
- [ ] Fee tier confirmed
- [ ] Behaviour on failed swap tested
- [ ] Independent emergency-disable switch works

### I8 — Token safety screener
Deterministic checks required before any Volatile-tier position:
- [ ] Mint authority present/renounced
- [ ] Blacklist or freeze capability
- [ ] Transfer tax on buy and on sell
- [ ] LP lock status and duration
- [ ] Holder concentration (top-10 share)
- [ ] Pool age and depth
- [ ] Proxy/upgradeable contract detection

### I9 / I10 — Assets
- [ ] Canonical address from official source
- [ ] Decimals confirmed
- [ ] Freeze/blacklist capability documented
- [ ] Liquidity confirmed at intended sizes

---

## Verified addresses

No longer empty. Every entry below was measured or deployed, never copied from
a blog or inferred.

| ID | Network | Address | Verified by | Date |
|---|---|---|---|---|
| I1 | Robinhood Chain testnet (46630) | n/a — chain config | `cast chain-id` returned 46630 against the testnet RPC | 2026-09-26 |
| — | Robinhood Chain testnet (46630) | `0x0EBdDD089f8203DD5cD1Bd1f148F75757285CF96` — `GenesisAgent` | Deployed from commit `b8cdd38`; source verified on Blockscout | 2026-09-26 |
| — | Robinhood Chain testnet (46630) | `0x0D0080582D317D2878A31b01D97614a3E918dC65` — `AccountRegistry` | Deployed from commit `b8cdd38`; source verified on Blockscout | 2026-09-26 |

| I13 | Robinhood Chain testnet (46630) | `0xC9f9c86933092BbbfFF3CCb4b105A4A94bf3Bd4E` — TSLA "Tesla" | `symbol()`, `name()`, `decimals()` read on chain with `cast call`; 18 decimals; non-empty `code` | 2026-09-26 |
| I13 | Robinhood Chain testnet (46630) | `0x71178BAc73cBeb415514eB542a8995b82669778d` — AMD "AMD" | same method | 2026-09-26 |
| I13 | Robinhood Chain testnet (46630) | `0x5884aD2f920c162CFBbACc88C9C51AA75eC09E02` — AMZN "Amazon" | same method | 2026-09-26 |
| I13 | Robinhood Chain testnet (46630) | `0x3b8262A63d25f0477c4DDE23F83cfe22Cb768C93` — NFLX "Netflix" | same method | 2026-09-26 |
| I13 | Robinhood Chain testnet (46630) | `0x1FBE1a0e43594b3455993B5dE5Fd0A7A266298d0` — PLTR "Palantir Technologies" | same method | 2026-09-26 |

Full record, including transaction hashes and constructor arguments, in
`deployments/robinhood-testnet.json`.

### I13 — verified, and deliberately NOT allowlisted

These five are the ONLY ERC-20s the testnet faucet provided to the deployer: 5
units each, 18 decimals, obtained 2026-09-26. Each was verified by reading
`symbol()`, `name()` and `decimals()` directly from the contract with
`cast call`, and confirming non-empty bytecode — not from the faucet's or the
explorer's description of them.

**They are tokenized equities, which sits in tension with three recorded
decisions.** `DECISIONS.md` D5 chose Core (ETH/WETH/stables) and Volatile
(memecoins) tiers, reasoning that memecoins "sit further from securities
classification than tokenized equities". The corrections log in
`ASSUMPTIONS.md` records "tokenized stocks are the natural asset class for this
chain" as an assumption that turned out **wrong**, and separately that
"tokenized securities remain securities". `PRODUCT.md` states this is not
advice on securities, and tokenized equities are neither defined asset tier.

**They are therefore NOT in the `RiskEngine` allowlist.** The allowlist has no
setter, so whatever the first deployment contains is permanent for that engine
and reads as a positioning statement about what this system is for. Two
purpose-built `TestAsset` ERC-20s were deployed instead — see I14 below and
`DECISIONS.md` D13.

Their addresses stay recorded here because the verification work is real and
worth keeping: if an in-tier asset appears on this testnet later, or if the
position on tokenized equities changes with counsel's input, the groundwork is
already done. Recorded, verified, and not used.

No WETH (I9) or settlement stablecoin (I10) exists on this testnet, which is
why both remain MOCK — and why no in-tier asset was available to borrow.

---

### I14 — `TestAsset` ERC-20s, purpose-deployed for the allowlist

Two minimal fixed-supply ERC-20s, deployed by
`script/DeployRiskEngine.s.sol` solely so the risk engine has a non-empty
allowlist that does not make a claim about asset class.

| Symbol | Name | Address | Deploy tx | Verified |
|---|---|---|---|---|
| AVTA | AgentVault Test Asset A | `0x87CEd5dc138F825B3F42924A8Bb6E15ae5EC9A7d` | `0x0e85aa74…49620f` | yes |
| AVTB | AgentVault Test Asset B | `0x9D97ebc6A395aaf981B26d952A4e22604eAFEc75` | `0x096d7189…4fff48` | yes |

Both deployed and source-verified on Blockscout 2026-09-26, block 124753509 and
124753520. `symbol()`, `name()`, `decimals()` and `totalSupply()` were read back
on chain: 18 decimals, 1,000,000e18 total supply, entire supply held by the
deployer. The predicted addresses from `cast compute-address` (nonces 7 and 8)
matched what was actually deployed.

**A verification gotcha worth recording.** `forge verify-contract` reported AVTB
as "already verified. Skipping verification" — because Blockscout had matched its
bytecode from AVTA's submission, the two being byte-identical. But the explorer
API still reported `is_verified: false` with no constructor arguments. Re-running
with `--skip-is-verified-check` verified it properly. Always confirm
verification against the explorer API rather than trusting the CLI's message.

### I15 — `RiskEngine`

| Address | Deploy tx | Allowlist | Verified |
|---|---|---|---|
| `0x36df9096162b9f18d13574Fba930C9e2Ce6cc4a4` | `0x825e87bb…fa55d4` | AVTA, AVTB, USDG | yes |

Superseded engine `0x158A97c9b56043b5F3b841B3435D249326F43777` (tx `0x2ed949ae…740f3f`, allowlist AVTA + AVTB only) is
still deployed and verified but is **no longer current** — the allowlist is
immutable, so adding USDG required a replacement. Record kept in
`deployments/robinhood-testnet.json`.

Read back on chain: `registry()` returns the live `AccountRegistry`,
`approvedAssetCount()` is 2, `MAX_DATA_AGE()` is 300,
`isApprovedAsset(AVTA)` and `isApprovedAsset(AVTB)` are both true, and
**`isApprovedAsset(TSLA)` is false** — so D13's position is enforced on chain,
not merely documented.

Source lives at `src/mocks/TestAsset.sol`, under `mocks/` so its status is
unambiguous from the path. No mint function, no owner, no pause: the entire
supply is minted to the deployer at construction and can never change. These
are not real assets — no market, no price, no liquidity, no value.

**Mainnet (4663) has nothing deployed to it**, and `DeployTestnet.s.sol`
refuses that chain id outright — asserted by a test.

---

## Deliberately deferred

Not built now. Interfaces only, so later addition is not a rewrite.

- Perpetuals adapter
- FOREX adapter
- Lending adapter
- Reward router
- Sponsored treasury sleeve
- Cross-chain bridge

Each is a `TODO(integration)` marker in code pointing back to this file.
