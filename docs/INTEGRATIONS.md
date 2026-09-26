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
| I10 | Settlement stablecoin | MOCK | ERC-20 | `MockStable` |
| I11 | Market data feed | MOCK | `IMarketData` | fixture replay |
| I12 | Block explorer verification | MOCK | Foundry config | n/a |

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

Full record, including transaction hashes and constructor arguments, in
`deployments/robinhood-testnet.json`.

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
