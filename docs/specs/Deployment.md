# Specification — Testnet Deployment

**Status:** specification and runbook, not yet executed
**Target paths:**
- `packages/contracts/script/DeployTestnet.s.sol` (new)
- `packages/contracts/script/SmokeTest.s.sol` (new)
- `deployments/robinhood-testnet.json` (new)
- `docs/INTEGRATIONS.md` (updated with real addresses)

---

## Purpose

Deploy `GenesisAgent` and `AccountRegistry` to Robinhood Chain **testnet**,
verify them on the block explorer, prove they work with a live smoke test, and
record every address.

This is the first time this project touches a network or a private key.
Nothing here goes near mainnet.

## Why now, before the risk engine

Every remaining unknown in this sprint lives in deployment, not in Solidity.
The chain ID is unverified, the RPC is unproven, the faucet is untouched, and
Blockscout verification has never been run. Those fail slowly and want a week
of runway, not two days. Four working contracts is enough to flush them out.

---

## Safety rules — read before anything else

1. **Testnet only.** The script must refuse to run on chain ID `4663`
   (mainnet) under any circumstances. Deploying there is gated on the
   live-capital checklist in `ROADMAP.md`, which is nowhere near satisfied.
2. **Use a brand-new wallet** created for this purpose. It will hold only
   testnet ETH, which is worthless. Never use a wallet holding anything real.
3. **No plaintext private key anywhere.** Use Foundry's encrypted keystore,
   not `--private-key` and not `DEPLOYER_PRIVATE_KEY` in `.env`. The keystore
   lives outside the repo and is password-protected.
4. **Never paste a private key or seed phrase into a chat**, a file, a commit,
   or a terminal command that lands in shell history.
5. **Dry run before broadcast, always.** A simulation costs nothing and
   catches almost everything.
6. **Mark runs the broadcast command personally.** Claude Code writes the
   script, runs the pre-flight checks, runs the dry run, and handles
   verification. The one command that signs and sends a transaction is run by
   the human. Testnet gas is free so nothing is at stake today — the point is
   to establish the boundary now, while it is cheap, rather than the first
   time it matters.

---

## Part 0 — Pre-flight

Read-only. No key, no cost, no transaction.

### 0.1 Resolve the chain ID (closes ASSUMPTIONS U1)

```bash
cast chain-id --rpc-url https://rpc.testnet.chain.robinhood.com
```

Official docs say `46630`. One third-party source said `46646`. **Whatever
this command prints is the answer** — update `ASSUMPTIONS.md` U1 from
Unverified to Verified with the measured value and today's date, and correct
`.env.example` if it disagrees.

If the command fails, the RPC is unreachable and everything below is blocked.
Report the exact error rather than working around it.

### 0.2 Confirm the RPC responds

```bash
cast block-number --rpc-url https://rpc.testnet.chain.robinhood.com
cast gas-price --rpc-url https://rpc.testnet.chain.robinhood.com
```

Record the gas price — it feeds the cost estimate later.

### 0.3 Confirm the mainnet chain ID too

```bash
cast chain-id --rpc-url https://rpc.mainnet.chain.robinhood.com
```

Purely so the script's mainnet guard is written against a measured value
rather than a remembered one. **Do not deploy anything there.**

---

## Part 1 — Deployer wallet

### 1.1 Create a fresh wallet

```bash
cast wallet new
```

Prints an address and a private key. This is a throwaway testnet deployer. Do
not reuse an existing wallet, and do not fund it with anything real.

Check the exact flags with `cast wallet --help` first — Foundry's CLI changes
between versions and the syntax below should be confirmed, not assumed.

### 1.2 Import it into the encrypted keystore

```bash
cast wallet import agentvault-testnet --interactive
```

Prompts for the private key (not echoed) and a password. Stores it encrypted
under `~/.foundry/keystores/`, outside the repo entirely.

After this, **clear the terminal scrollback** so the plaintext key from step
1.1 is not sitting in a buffer.

Confirm it registered:

```bash
cast wallet list
```

### 1.3 Fund it

Visit `https://faucet.testnet.chain.robinhood.com` and request testnet ETH for
the address from 1.1.

Confirm arrival:

```bash
cast balance <YOUR_ADDRESS> --rpc-url https://rpc.testnet.chain.robinhood.com
```

Returns wei. Non-zero means funded. Faucets rate-limit, so if it comes back
empty, wait rather than hammering it.

---

## Part 2 — `DeployTestnet.s.sol`

Create `packages/contracts/script/` — the repo has no script directory yet,
because the Foundry template's sample scripts were removed in Milestone 1.

Scripts live in `script/`, never in `src/`. Anything in `src/` gets compiled
as a project contract.

### Structure

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {GenesisAgent} from "../src/GenesisAgent.sol";
import {AccountRegistry} from "../src/AccountRegistry.sol";

contract DeployTestnet is Script {
    // PROTOTYPE deployment parameters
    string  constant NFT_NAME   = "AgentVault Genesis Agent";
    string  constant NFT_SYMBOL = "AGENT";
    uint256 constant MAX_SUPPLY = 10_000;

    uint256 constant ROBINHOOD_MAINNET_CHAIN_ID = 4663;

    error MainnetDeploymentNotPermitted(uint256 chainId);
    error UnexpectedChain(uint256 actual, uint256 expected);

    function run() external {
        // Guard 1: never mainnet, under any configuration.
        if (block.chainid == ROBINHOOD_MAINNET_CHAIN_ID) {
            revert MainnetDeploymentNotPermitted(block.chainid);
        }

        // Guard 2: must match the chain the operator intended.
        uint256 expected = vm.envUint("EXPECTED_CHAIN_ID");
        if (block.chainid != expected) {
            revert UnexpectedChain(block.chainid, expected);
        }

        vm.startBroadcast();

        GenesisAgent nft = new GenesisAgent(NFT_NAME, NFT_SYMBOL, MAX_SUPPLY);
        AccountRegistry registry = new AccountRegistry(IERC721(address(nft)));

        vm.stopBroadcast();

        console.log("chainId        ", block.chainid);
        console.log("GenesisAgent   ", address(nft));
        console.log("AccountRegistry", address(registry));
    }
}
```

### Notes

**Two contracts, not four.** `ArchetypeLib` and `MandateLib` contain only
`internal` functions, so the compiler inlines them into their callers. They
are not deployed and need no library linking. Library linking is a classic
deploy-time surprise and it is worth knowing up front that it does not apply
here — confirm by checking that neither library appears in the broadcast
artifact.

**Two independent guards.** The mainnet check is a hard constant that no
environment variable can override. The `EXPECTED_CHAIN_ID` check catches the
subtler mistake of pointing at the wrong RPC. A wrong-network deploy is not
reversible; you simply have a contract somewhere you did not mean to put one.

**Constructor arguments are PROTOTYPE** and must be labelled as such in a
comment. Note them down — Blockscout verification needs them ABI-encoded.

**No addresses are hardcoded.** `AccountRegistry` takes the `GenesisAgent`
address produced in the same run.

---

## Part 3 — Dry run

Simulates against live chain state, broadcasts nothing, costs nothing.

```bash
cd packages/contracts
export EXPECTED_CHAIN_ID=<value measured in 0.1>
forge script script/DeployTestnet.s.sol:DeployTestnet \
  --rpc-url https://rpc.testnet.chain.robinhood.com \
  --sender <YOUR_ADDRESS>
```

Expect a simulation summary with estimated gas and both addresses. Multiply
estimated gas by the gas price from 0.2 for a cost estimate — it should be
negligible, and if it is not, stop and work out why before broadcasting.

**Do not proceed until the dry run is clean.**

---

## Part 4 — Broadcast

**Mark runs this command.**

```bash
cd packages/contracts
export EXPECTED_CHAIN_ID=<value measured in 0.1>
forge script script/DeployTestnet.s.sol:DeployTestnet \
  --rpc-url https://rpc.testnet.chain.robinhood.com \
  --account agentvault-testnet \
  --sender <YOUR_ADDRESS> \
  --broadcast
```

Prompts for the keystore password. Signs and sends two real transactions to a
real network. Testnet only; testnet ETH is worthless.

Record from the output: both addresses, both transaction hashes, the block
numbers, and the actual gas used.

---

## Part 5 — Verify on Blockscout

Verification uploads source so the explorer can show readable code and a
working read/write interface. This matters for the demo: a judge clicking
through to an unverified contract sees bytecode, which looks like nothing.

The explorer is at `explorer.testnet.chain.robinhood.com`. **The Blockscout
verifier API URL is not something I can state reliably** — find it in
Robinhood's own chain documentation, or from Blockscout's verification page on
that explorer, before running anything. Do not guess it.

Robinhood's Foundry tutorial shows the shape:

```bash
forge verify-contract <ADDRESS> \
  src/GenesisAgent.sol:GenesisAgent \
  --chain-id <MEASURED_CHAIN_ID> \
  --rpc-url https://rpc.testnet.chain.robinhood.com \
  --verifier blockscout \
  --verifier-url <VERIFIER_URL> \
  --constructor-args $(cast abi-encode "constructor(string,string,uint256)" "AgentVault Genesis Agent" "AGENT" 10000)
```

`AccountRegistry` takes one address argument:

```bash
--constructor-args $(cast abi-encode "constructor(address)" <GENESIS_AGENT_ADDRESS>)
```

Constructor arguments must match the deployment exactly or verification fails
with an unhelpful message. That is the usual cause.

Confirm by opening each address in the explorer and checking the source tab
renders.

---

## Part 6 — Smoke test

Bytecode existing is not the same as the system working. Prove the whole path
end to end against the live deployment.

Write `script/SmokeTest.s.sol`, or use `cast send` / `cast call` directly:

1. `mint(<YOUR_ADDRESS>, Archetype.Guardian)` → returns token ID 1
2. `archetypeOf(1)` → Guardian
3. `createAccount(1)` → succeeds
4. `getAccount(1)` → balance and depositedTotal both `SEED_BALANCE`, PnL zero,
   automation paused, mandate `Unset`
5. `setMandate(1, Mandate.Preservation)` → succeeds
6. `mandateParamsOf(1)` → matches the PROTOTYPE table
7. `setAutomationPaused(1, false)` then `isAutomationPaused(1)` → false
8. `withdraw(1, small amount)` → succeeds

These are real transactions and cost real testnet gas, which is free.

Step 4 is the one worth watching: seeing simulated capital and zero PnL on a
live chain is the first real evidence the accounting model works outside a
test harness.

---

## Part 7 — Record

### `deployments/robinhood-testnet.json`

```json
{
  "network": "Robinhood Chain Testnet",
  "chainId": "<measured>",
  "rpcUrl": "https://rpc.testnet.chain.robinhood.com",
  "explorer": "https://explorer.testnet.chain.robinhood.com",
  "deployedAt": "2026-09-26",
  "commit": "<git rev-parse HEAD>",
  "deployer": "<address>",
  "contracts": {
    "GenesisAgent": {
      "address": "<address>",
      "txHash": "<hash>",
      "constructorArgs": ["AgentVault Genesis Agent", "AGENT", 10000],
      "verified": true
    },
    "AccountRegistry": {
      "address": "<address>",
      "txHash": "<hash>",
      "constructorArgs": ["<genesis agent address>"],
      "verified": true
    }
  }
}
```

Recording the commit hash matters — it ties deployed bytecode to source.

### `docs/INTEGRATIONS.md`

Move I1 (chain config) from `MOCK` to `VERIFIED` with the measured chain ID
and today's date. Add the two deployed addresses to the verified-addresses
table, which has been deliberately empty until now.

### `docs/ASSUMPTIONS.md`

U1 moves to Verified with the measured value. If the measurement contradicts
the official docs, say so plainly in the corrections log — a documented
discrepancy is more useful than a silently corrected one.

### `README.md`

Add a short "Deployed contracts" section with both explorer links, so a judge
opening the repo can click straight through to live, verified code.

---

## Troubleshooting

**`cast chain-id` times out.** RPC unreachable. Try again; if it persists the
testnet may be down. Report the error, do not route around it.

**Faucet returns nothing.** Rate limited. Wait. Do not create more wallets to
farm it.

**Dry run reverts `UnexpectedChain`.** `EXPECTED_CHAIN_ID` disagrees with the
RPC. The guard is doing its job — work out which is wrong before overriding
anything.

**Verification fails with a mismatch.** Almost always constructor arguments.
Re-encode them, confirming the exact values used at deploy.

**`forge script` cannot find the account.** Check `cast wallet list` and that
the `--account` name matches.

**Out of gas mid-deploy.** Faucet grant too small. Request more.

---

## Acceptance criteria

- [ ] Chain ID measured and `ASSUMPTIONS.md` U1 closed
- [ ] Deployer wallet created fresh, key in encrypted keystore, never in the
      repo or in chat
- [ ] `.env` still gitignored; `DEPLOYER_PRIVATE_KEY` still empty in
      `.env.example`
- [ ] Script refuses chain ID 4663 — assert this with a local test
- [ ] Dry run clean before any broadcast
- [ ] Both contracts deployed to testnet
- [ ] Both verified, source visible in the explorer
- [ ] All eight smoke-test steps pass against the live deployment
- [ ] `deployments/robinhood-testnet.json` written, including commit hash
- [ ] `INTEGRATIONS.md` verified-addresses table populated
- [ ] README links to both explorer pages
- [ ] Nothing deployed to mainnet

---

## Amendments

Corrections found while executing this runbook. The body above is left
unedited so the amendment reads as a discovery rather than a silent rewrite.

### 2026-09-26

**`GenesisAgent`'s constructor is `(uint256 maxSupply_)`.** The ERC-721 name
and symbol are fixed in the base call —
`ERC721("AgentVault Genesis Agent", "AGENT")` — and are **not** constructor
arguments. Part 2's script and Part 5's verification command in the body above
are both wrong. Use:

```bash
cast abi-encode "constructor(uint256)" 10000
```

not `constructor(string,string,uint256)`. Mismatched constructor arguments are
the usual cause of Blockscout verification failing with an unhelpful message,
so this would have surfaced there as a confusing error rather than as an
obvious one.

**Part 1's two-step create-then-import is superseded.** Use:

```bash
cast wallet new agentvault-testnet
```

This writes the encrypted keystore to `~/.foundry/keystores/` directly,
prompts for a hidden password (now the default), prints only the address, and
**never displays the private key**. The plaintext key never reaches the
terminal, so Part 1.2's instruction to clear the scrollback no longer applies.
Confirmed against `cast wallet new --help` in Foundry 1.8.3.
