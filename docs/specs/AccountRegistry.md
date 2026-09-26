# Specification — AccountRegistry.sol

**Milestone:** 4
**Status:** specification, not yet implemented
**Target path:** `packages/contracts/src/AccountRegistry.sol`
**Test path:** `packages/contracts/test/AccountRegistry.t.sol`

---

## Purpose

Holds one isolated simulated-capital account per Genesis Agent NFT. Tracks
principal separately from profit and loss, detects NFT transfers, and owns the
holder's kill switch.

It holds no real assets. Balances are simulated units with no redeemable
value, and nothing in this contract moves ether or ERC-20 tokens.

## Trust assumptions

- The **current** NFT holder, read live, is the only party who may act on an
  account. There is no owner, admin, pauser, or protocol role anywhere in this
  contract — the same position as `GenesisAgent`.
- Withdrawal is always available to the holder, including while automation is
  paused. Nothing can block it.
- Not upgradeable.

## Dependency — depend on the interface, not the implementation

The constructor takes an `IERC721`, **not** a `GenesisAgent`. This registry
needs exactly two things from the NFT contract:

- `ownerOf(uint256)` to determine who may act
- the fact that `ownerOf` reverts (`ERC721NonexistentToken` in OpenZeppelin
  v5) for a token that was never minted, which serves as the existence check

It must **not** import `GenesisAgent`, read archetypes, or call any custom
function. Archetype is collectible identity; this contract handles financial
state. Rule 4 in `CLAUDE.md` says they stay separate, and the cleanest way to
enforce that is to make it structurally impossible for the registry to see an
archetype at all.

Practical benefit: tests can use a minimal `IERC721` mock, so registry tests
do not break when `GenesisAgent` changes.

```solidity
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
```

---

## Storage

```solidity
struct Account {
    bool exists;
    address lastKnownOwner;
    uint256 depositedTotal;   // cumulative principal in
    uint256 withdrawnTotal;   // cumulative principal out
    uint256 balance;          // current simulated balance
    bool automationPaused;
    uint32 ownerPeriod;       // increments on each detected transfer
    uint64 createdAt;         // block.timestamp at creation
}

mapping(uint256 tokenId => Account) private _accounts;
uint256 private _accountCount;
IERC721 public immutable agentNft;
```

`ownerPeriod` starts at 1 for a new account. Zero means no account, same
convention as `Archetype.Unassigned` and token IDs starting at 1. Performance
history in a later milestone will key on `(tokenId, ownerPeriod)` so that a
previous holder's results stay attributable to them.

### Seed balance

```solidity
uint256 public constant SEED_BALANCE = 10_000e18; // PROTOTYPE
```

An account is created with `balance = SEED_BALANCE` **and**
`depositedTotal = SEED_BALANCE`, so profit and loss is exactly zero at
creation. The seed is principal, not performance. Labelled PROTOTYPE; not
audited, not final, not a claim about anything.

### Profit and loss

Derived, never stored:

```
netPrincipal = depositedTotal - withdrawnTotal
pnl          = int256(balance) - int256(netPrincipal)
```

Storing PnL would let it drift out of sync with the balance. Deriving it makes
"a deposit never increases profit" true by construction rather than by
discipline.

---

## Constructor

```
constructor(IERC721 agentNft_)
```

Reverts `ZeroAddress()` if `address(agentNft_) == address(0)`.

## Owner resolution and transfer detection

Every state-changing function begins with the same internal step.

```
_requireOwnerAndSync(uint256 tokenId) internal returns (Account storage)
```

1. `address currentOwner = agentNft.ownerOf(tokenId);`
   — reverts on a nonexistent token, which is the existence check
2. `if (msg.sender != currentOwner) revert NotTokenOwner(tokenId, msg.sender);`
3. Load the account; `if (!a.exists) revert AccountDoesNotExist(tokenId);`
4. **If `a.lastKnownOwner != currentOwner`, a transfer happened since the last
   interaction.** Before doing anything else:
   - `a.automationPaused = true;`
   - `a.ownerPeriod += 1;`
   - `a.lastKnownOwner = currentOwner;`
   - emit `OwnerPeriodStarted(tokenId, currentOwner, a.ownerPeriod)`
5. Return the account

The owner is **read live on every call and never cached for authorization.** A
cached owner is a stale owner, and a stale owner is a previous holder still
holding control over an account they sold.

### Why lazy detection

There is no hook from the NFT contract into this registry. That keeps the two
contracts decoupled — no circular dependency, no mint-time coupling, and
`GenesisAgent` stays a plain ERC-721 with nothing bolted on.

The cost is that state is stale between a transfer and the new holder's first
interaction. That is handled by making reads fail safe, below.

### Reads fail safe

```solidity
function isAutomationPaused(uint256 tokenId) public view returns (bool)
```

Returns `true` if `automationPaused` is set **or** if
`lastKnownOwner != agentNft.ownerOf(tokenId)`.

This is the critical line in the contract. A transfer that has not yet been
synced must read as paused, so that anything checking whether automation may
run — the risk engine, in a later milestone — gets the safe answer rather than
the stale one. Never expose the raw `automationPaused` field on its own.

---

## Public functions

### `createAccount(uint256 tokenId) external`

- `ownerOf` must succeed and equal `msg.sender`, else `NotTokenOwner`
- Revert `AccountAlreadyExists(tokenId)` if one exists
- Initialise: `exists = true`, `lastKnownOwner = msg.sender`,
  `depositedTotal = SEED_BALANCE`, `withdrawnTotal = 0`,
  `balance = SEED_BALANCE`, `automationPaused = true`, `ownerPeriod = 1`,
  `createdAt = uint64(block.timestamp)`
- `_accountCount += 1`
- Emit `AccountCreated(tokenId, msg.sender, SEED_BALANCE)`

**Accounts are created paused.** Automation starts off and the holder turns it
on deliberately. Defaulting to on would mean an account begins doing things its
holder never asked for.

### `deposit(uint256 tokenId, uint256 amount) external`

- `_requireOwnerAndSync`
- Revert `ZeroAmount()` if `amount == 0`
- `balance += amount; depositedTotal += amount;`
- Emit `Deposited(tokenId, msg.sender, amount)`

Both fields move by the same amount, so PnL is unchanged. That is the
acceptance criterion, satisfied structurally.

### `withdraw(uint256 tokenId, uint256 amount) external`

- `_requireOwnerAndSync`
- Revert `ZeroAmount()` if `amount == 0`
- Revert `InsufficientBalance(amount, a.balance)` if `amount > a.balance`
- `balance -= amount; withdrawnTotal += amount;`
- Emit `Withdrawn(tokenId, msg.sender, amount)`

**There is no pause check in this function, deliberately.** Withdrawal must
work when automation is paused, when the kill switch is on, and when every
other part of the protocol is broken. A comment in the code should say so, so
that nobody adds a modifier here later thinking it was an oversight.

### `setAutomationPaused(uint256 tokenId, bool paused) external`

- `_requireOwnerAndSync`
- Set the flag, emit `AutomationPausedSet(tokenId, paused)`

This is the kill switch. Current holder only. No protocol role is consulted
and none exists.

### Views

```solidity
function getAccount(uint256 tokenId) external view returns (Account memory)
function accountExists(uint256 tokenId) external view returns (bool)
function isAutomationPaused(uint256 tokenId) public view returns (bool)
function netPrincipalOf(uint256 tokenId) external view returns (uint256)
function pnlOf(uint256 tokenId) external view returns (int256)
function isTransferPending(uint256 tokenId) external view returns (bool)
function totalAccounts() external view returns (uint256)
```

`getAccount`, `netPrincipalOf`, `pnlOf` and `isTransferPending` revert
`AccountDoesNotExist` for an account that was never created.

---

## Events

```solidity
event AccountCreated(uint256 indexed tokenId, address indexed owner, uint256 seedBalance);
event Deposited(uint256 indexed tokenId, address indexed owner, uint256 amount);
event Withdrawn(uint256 indexed tokenId, address indexed owner, uint256 amount);
event AutomationPausedSet(uint256 indexed tokenId, bool paused);
event OwnerPeriodStarted(uint256 indexed tokenId, address indexed newOwner, uint32 ownerPeriod);
```

## Custom errors

```solidity
error ZeroAddress();
error ZeroAmount();
error AccountAlreadyExists(uint256 tokenId);
error AccountDoesNotExist(uint256 tokenId);
error NotTokenOwner(uint256 tokenId, address caller);
error InsufficientBalance(uint256 requested, uint256 available);
```

## Upgrade assumptions

None. Not upgradeable, no proxy, no admin. Consistent with `GenesisAgent`.

## Emergency behavior

The per-account kill switch is the only emergency control, and only the holder
can operate it. There is no protocol-wide pause in this contract, because a
protocol-wide pause is a privileged role and there is nothing here it could
safely be trusted with. Withdrawal is never blocked by anything.

---

## Invariants

Must hold under fuzzing, not just in the happy path.

1. One account per token; no two tokens share account state
2. Any sequence of operations on account A leaves account B byte-identical
3. Only the current NFT owner can change account state
4. A previous owner cannot act after transfer
5. A detected transfer sets `automationPaused = true` before any other state
   change in that call
6. `isAutomationPaused` returns `true` whenever a transfer is pending
7. `deposit` never changes `pnlOf`
8. `withdraw` succeeds regardless of pause state
9. `balance >= 0` always (unsigned; underflow would revert)
10. `ownerPeriod` only ever increases, never resets
11. No function reads or references an archetype

Invariant 2 is the premise of the whole product. It deserves a fuzz test that
hammers A with random operations while asserting every field of B is unchanged
— not a single-case unit test.

---

## Tests

Every test carries WHAT / WHY / FAILURE MEANS, matching existing style.

### Test setup

Build a minimal `MockAgentNft is IERC721` with a settable
`ownerOf` mapping and a `transfer(tokenId, to)` helper. Do not import
`GenesisAgent` into these tests. Integration between the two belongs in a
separate test file later, if at all.

### Creation

1. Creating an account sets balance and depositedTotal to `SEED_BALANCE`, and
   PnL to exactly zero
2. A new account starts with `ownerPeriod == 1`
3. A new account starts **paused**
4. `createAccount` emits `AccountCreated` with correct arguments
5. `totalAccounts` increments
6. Creating twice for the same token reverts `AccountAlreadyExists`
7. Creating for a nonexistent token reverts (the `ownerOf` revert propagates)
8. A non-owner cannot create an account for someone else's token

### Isolation — the important ones

9. Two tokens produce two independent accounts with independent balances
10. Depositing into A does not change any field of B
11. Withdrawing from A does not change any field of B
12. Pausing A does not change B's pause state
13. **Fuzz:** a random sequence of deposits, withdrawals, and pause toggles on
    A leaves every field of B identical to its initial state

### Access control

14. A non-owner cannot deposit, withdraw, or pause — each reverts
    `NotTokenOwner`
15. After transfer, the **previous** owner cannot deposit, withdraw, or pause

### Transfer handling

16. After transfer, the new owner's first interaction sets
    `automationPaused = true`
17. After transfer, `ownerPeriod` increments by exactly 1
18. After transfer, `lastKnownOwner` updates to the new owner
19. `OwnerPeriodStarted` is emitted with the new owner and new period
20. **Before** the new owner interacts, `isAutomationPaused` already returns
    `true` — the fail-safe read
21. `isTransferPending` returns true after transfer, false after sync
22. Balance, `depositedTotal` and `withdrawnTotal` survive transfer unchanged —
   the account's financial history is not wiped by a change of holder
23. Two consecutive transfers increment `ownerPeriod` by 2

### Principal and PnL

24. A deposit increases balance and `depositedTotal` equally; `pnlOf` is
    unchanged
25. A withdrawal decreases balance and increases `withdrawnTotal`; `pnlOf` is
    unchanged
26. **Fuzz:** across random deposit and withdraw sequences, `pnlOf` remains
    exactly zero — since nothing in this milestone can generate real PnL, any
    nonzero result means principal is leaking into performance

### Kill switch

27. The holder can pause and unpause
28. **Withdrawal succeeds while paused** — the acceptance criterion
29. Deposit while paused also succeeds (pausing stops automation, not the
    holder)

### Validation

30. Zero-amount deposit and withdraw both revert `ZeroAmount`
31. Withdrawing more than the balance reverts `InsufficientBalance`
32. Constructor reverts `ZeroAddress` on a zero NFT address

---

## Deferred — do not implement now

**Trade settlement.** Nothing in this milestone can change `balance` other
than the holder's own deposits and withdrawals. There is no authorised caller
that can settle a trade result, because the risk engine does not exist yet and
there is no admin role to grant such permission. Designing that authorisation
is a Milestone 6 problem and getting it wrong would hand something other than
the holder the power to move an account's balance. Add a
`TODO(milestone-6)` comment where settlement will attach.

**Real token-bound accounts.** ERC-6551 is `MOCK` in `INTEGRATIONS.md` (I3)
with an unverified registry address. Accounts stay structs until that gate
clears.

**Mandate clearing on transfer.** The transfer path resets automation and
opens a new owner period. Clearing the risk mandate joins the same path in
Milestone 5, once a mandate exists to clear.

**Real assets.** No ether, no ERC-20, no transfers of anything. Simulated
units only.

---

## Acceptance criteria

- [ ] `forge build` succeeds, no warnings
- [ ] `forge test -vv` passes — all existing tests plus the new ones
- [ ] `forge fmt --check` clean
- [ ] No import of `GenesisAgent` in the contract or its tests
- [ ] No reference to archetypes anywhere in the file
- [ ] No owner, admin, or protocol role
- [ ] No pause check anywhere in `withdraw`
- [ ] Owner is read live in every authorisation path; never cached
- [ ] `isAutomationPaused` returns true for an unsynced transfer
- [ ] No hardcoded addresses, RPC URLs, or chain IDs
- [ ] Every test carries WHAT / WHY / FAILURE MEANS
