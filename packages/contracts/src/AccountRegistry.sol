// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Mandate, MandateLib, MandateParams} from "./Mandate.sol";

/// @title AccountRegistry
/// @notice One isolated simulated-capital account per Genesis Agent NFT.
///         Tracks principal separately from profit and loss, detects NFT
///         transfers, and owns the holder's kill switch.
///
/// @dev HOLDS NO REAL ASSETS. Balances are simulated units with no redeemable
///      value. Nothing in this contract moves ether or ERC-20 tokens, and no
///      function here can win or lose anything of value.
///
///      TRUST: the CURRENT NFT holder, read live, is the only party who may
///      act on an account. There is no owner, admin, pauser, or protocol role
///      anywhere in this contract — the same position as `GenesisAgent`. Not
///      upgradeable.
///
///      DEPENDS ON THE INTERFACE, NOT THE IMPLEMENTATION. This contract takes
///      an `IERC721` and needs exactly two things from it: `ownerOf` to decide
///      who may act, and the fact that `ownerOf` reverts for a token that was
///      never minted, which serves as the existence check. It deliberately
///      cannot see an archetype: collectible identity and financial state stay
///      separate (CLAUDE.md rule 4), and making it structurally impossible to
///      read one from here is stronger than a convention.
contract AccountRegistry {
    using SafeCast for uint256;

    /// @notice Per-token account state.
    /// @dev `ownerPeriod` starts at 1 for a new account; zero means no
    ///      account, the same convention as `Archetype.Unassigned` and token
    ///      ids starting at 1. A later milestone keys performance history on
    ///      `(tokenId, ownerPeriod)` so a previous holder's results stay
    ///      attributable to them.
    struct Account {
        bool exists;
        address lastKnownOwner;
        uint256 depositedTotal; // cumulative principal in
        uint256 withdrawnTotal; // cumulative principal out
        uint256 balance; // current simulated balance
        bool automationPaused;
        uint32 ownerPeriod; // increments on each detected transfer
        uint64 createdAt; // block.timestamp at creation
        Mandate mandate; // holder-selected risk setting; Unset until chosen
    }

    /// @notice Thrown when the NFT contract address is zero.
    error ZeroAddress();

    /// @notice Thrown when an amount argument is zero.
    error ZeroAmount();

    /// @notice Thrown when an account already exists for a token.
    error AccountAlreadyExists(uint256 tokenId);

    /// @notice Thrown when no account exists for a token.
    error AccountDoesNotExist(uint256 tokenId);

    /// @notice Thrown when the caller is not the current holder of the token.
    error NotTokenOwner(uint256 tokenId, address caller);

    /// @notice Thrown when a withdrawal exceeds the available balance.
    error InsufficientBalance(uint256 requested, uint256 available);

    event AccountCreated(uint256 indexed tokenId, address indexed owner, uint256 seedBalance);
    event Deposited(uint256 indexed tokenId, address indexed owner, uint256 amount);
    event Withdrawn(uint256 indexed tokenId, address indexed owner, uint256 amount);
    event AutomationPausedSet(uint256 indexed tokenId, bool paused);
    event OwnerPeriodStarted(uint256 indexed tokenId, address indexed newOwner, uint32 ownerPeriod);
    event MandateSelected(uint256 indexed tokenId, Mandate mandate, uint32 ownerPeriod);

    /// @notice Simulated units an account is seeded with at creation.
    /// @dev PROTOTYPE. Not audited, not final, and not a claim about anything.
    ///      The seed is recorded as principal, not as performance, so profit
    ///      and loss is exactly zero at creation.
    uint256 public constant SEED_BALANCE = 10_000e18;

    /// @notice The NFT whose holders control these accounts.
    IERC721 public immutable agentNft;

    mapping(uint256 tokenId => Account) private _accounts;
    uint256 private _accountCount;

    /// @param agentNft_ The ERC-721 whose current holder controls each account.
    constructor(IERC721 agentNft_) {
        if (address(agentNft_) == address(0)) {
            revert ZeroAddress();
        }
        agentNft = agentNft_;
    }

    // -----------------------------------------------------------------------
    // State-changing functions
    // -----------------------------------------------------------------------

    /// @notice Create the account for a token the caller currently holds.
    /// @dev Accounts are created PAUSED. Automation starts off and the holder
    ///      turns it on deliberately — defaulting to on would mean an account
    ///      begins doing things its holder never asked for.
    ///
    ///      This does not go through `_requireOwnerAndSync`, because that
    ///      requires an existing account. The live owner check is done here.
    function createAccount(uint256 tokenId) external {
        // Reverts for a token that was never minted. That revert is the
        // existence check; this contract does not duplicate it.
        address currentOwner = agentNft.ownerOf(tokenId);
        if (msg.sender != currentOwner) {
            revert NotTokenOwner(tokenId, msg.sender);
        }

        Account storage account = _accounts[tokenId];
        if (account.exists) {
            revert AccountAlreadyExists(tokenId);
        }

        account.exists = true;
        account.lastKnownOwner = msg.sender;
        account.depositedTotal = SEED_BALANCE;
        account.withdrawnTotal = 0;
        account.balance = SEED_BALANCE;
        account.automationPaused = true;
        account.ownerPeriod = 1;
        // SafeCast rather than a raw cast: a silent truncation here would
        // write a wrong creation time that nothing would ever flag.
        account.createdAt = block.timestamp.toUint64();
        // Written explicitly even though a fresh slot is already zero: the
        // holder chooses their risk level deliberately, and the protocol
        // never selects one on their behalf.
        account.mandate = Mandate.Unset;

        _accountCount += 1;

        emit AccountCreated(tokenId, msg.sender, SEED_BALANCE);
    }

    /// @notice Add principal to an account.
    /// @dev `balance` and `depositedTotal` move by the same amount, so profit
    ///      and loss is unchanged by construction. "A deposit never increases
    ///      recorded profit" is therefore structural, not a matter of
    ///      discipline.
    function deposit(uint256 tokenId, uint256 amount) external {
        Account storage account = _requireOwnerAndSync(tokenId);
        if (amount == 0) {
            revert ZeroAmount();
        }

        account.balance += amount;
        account.depositedTotal += amount;

        emit Deposited(tokenId, msg.sender, amount);
    }

    /// @notice Remove principal from an account.
    /// @dev THERE IS NO PAUSE CHECK IN THIS FUNCTION, DELIBERATELY. Withdrawal
    ///      must work when automation is paused, when the kill switch is on,
    ///      and when every other part of the protocol is broken. Do not add a
    ///      pause modifier here later thinking its absence was an oversight —
    ///      it is the point.
    function withdraw(uint256 tokenId, uint256 amount) external {
        Account storage account = _requireOwnerAndSync(tokenId);
        if (amount == 0) {
            revert ZeroAmount();
        }
        if (amount > account.balance) {
            revert InsufficientBalance(amount, account.balance);
        }

        account.balance -= amount;
        account.withdrawnTotal += amount;

        emit Withdrawn(tokenId, msg.sender, amount);
    }

    /// @notice The holder's kill switch.
    /// @dev Current holder only. No protocol role is consulted, and none
    ///      exists to consult. Pausing never blocks withdrawal.
    function setAutomationPaused(uint256 tokenId, bool paused) external {
        Account storage account = _requireOwnerAndSync(tokenId);
        account.automationPaused = paused;

        emit AutomationPausedSet(tokenId, paused);
    }

    /// @notice Select the account's risk mandate.
    /// @dev Current holder only. `Unset` is rejected, so there is no way to
    ///      un-choose a mandate except by transferring the NFT.
    ///
    ///      The protocol never assigns a mandate, never defaults one, and
    ///      never infers one from the token's archetype. This contract cannot
    ///      read an archetype at all — it depends only on `IERC721`.
    function setMandate(uint256 tokenId, Mandate newMandate) external {
        Account storage account = _requireOwnerAndSync(tokenId);
        MandateLib.requireValid(newMandate);

        account.mandate = newMandate;

        // ownerPeriod is included so an indexer can attribute the choice to
        // the holder who made it, which matters once performance history is
        // segmented by owner period.
        emit MandateSelected(tokenId, newMandate, account.ownerPeriod);
    }

    // TODO(milestone-6): trade settlement attaches here. Nothing in this
    // milestone can change `balance` other than the holder's own deposits and
    // withdrawals, because there is no authorised caller that could settle a
    // trade result — the risk engine does not exist yet and there is no admin
    // role to grant such permission. Designing that authorisation is a
    // Milestone 6 problem, and getting it wrong would hand something other
    // than the holder the power to move an account's balance.

    // -----------------------------------------------------------------------
    // Views
    // -----------------------------------------------------------------------

    /// @notice Full account state, as it will be after the next sync.
    /// @dev Routed through `_effectiveAccount`, so a pending transfer is
    ///      reflected here rather than leaking the previous holder's settings.
    function getAccount(uint256 tokenId) external view returns (Account memory) {
        _requireAccount(tokenId);
        return _effectiveAccount(tokenId);
    }

    /// @notice Whether an account has been created for a token.
    function accountExists(uint256 tokenId) external view returns (bool) {
        return _accounts[tokenId].exists;
    }

    /// @notice Whether automation is paused for a token.
    /// @dev THIS IS THE FAIL-SAFE READ, and the critical line in this
    ///      contract. It returns true if the stored flag is set OR if a
    ///      transfer has happened that this registry has not yet synced.
    ///
    ///      Transfer detection is lazy: there is no hook from the NFT contract
    ///      into this registry, which keeps the two decoupled. The cost is
    ///      that stored state is stale between a transfer and the new holder's
    ///      first interaction. Returning the raw flag during that window would
    ///      tell a caller — the risk engine, in a later milestone — that
    ///      automation may run on an account whose holder has changed. So the
    ///      unsynced case reads as paused, and the raw `automationPaused`
    ///      field is never exposed on its own.
    function isAutomationPaused(uint256 tokenId) public view returns (bool) {
        return _effectiveAccount(tokenId).automationPaused;
    }

    /// @notice Principal currently in the account: deposits minus withdrawals.
    /// @dev Cannot underflow in this milestone: nothing can change `balance`
    ///      except deposits and withdrawals, and a withdrawal is capped at the
    ///      balance, so `withdrawnTotal` can never exceed `depositedTotal`.
    function netPrincipalOf(uint256 tokenId) external view returns (uint256) {
        _requireAccount(tokenId);
        Account storage account = _accounts[tokenId];
        return account.depositedTotal - account.withdrawnTotal;
    }

    /// @notice Profit and loss, derived and never stored.
    /// @dev Storing PnL would let it drift out of sync with the balance.
    ///      Deriving it makes "a deposit never increases profit" true by
    ///      construction.
    function pnlOf(uint256 tokenId) external view returns (int256) {
        _requireAccount(tokenId);
        Account storage account = _accounts[tokenId];
        uint256 netPrincipal = account.depositedTotal - account.withdrawnTotal;
        // SafeCast rather than raw casts. Deposits are unbounded in this
        // prototype, so a balance above 2^255-1 is reachable by a holder
        // depositing absurd amounts. A raw cast would wrap it to a negative
        // number and report a catastrophic fake loss; this reverts instead.
        return account.balance.toInt256() - netPrincipal.toInt256();
    }

    /// @notice Whether the NFT has changed hands since this registry last
    ///         synced the account.
    function isTransferPending(uint256 tokenId) external view returns (bool) {
        _requireAccount(tokenId);
        return _accounts[tokenId].lastKnownOwner != agentNft.ownerOf(tokenId);
    }

    /// @notice The account's selected risk mandate, or `Unset` if none.
    function mandateOf(uint256 tokenId) external view returns (Mandate) {
        _requireAccount(tokenId);
        return _effectiveAccount(tokenId).mandate;
    }

    /// @notice Risk limits for the account's selected mandate.
    /// @dev Reverts `InvalidMandate(0)` when no mandate has been chosen.
    ///      Returning a zeroed struct would read as limits of zero rather than
    ///      as a decision nobody has made.
    function mandateParamsOf(uint256 tokenId) external view returns (MandateParams memory) {
        _requireAccount(tokenId);
        // A pending transfer yields `Unset`, so this reverts InvalidMandate(0)
        // rather than handing out the previous holder's limits.
        return MandateLib.paramsOf(_effectiveAccount(tokenId).mandate);
    }

    /// @notice Number of accounts created.
    function totalAccounts() external view returns (uint256) {
        return _accountCount;
    }

    // -----------------------------------------------------------------------
    // Internal
    // -----------------------------------------------------------------------

    /// @dev Authorises the caller against the LIVE owner and syncs a detected
    ///      transfer before returning the account.
    ///
    ///      The owner is read live on every call and NEVER cached for
    ///      authorisation. A cached owner is a stale owner, and a stale owner
    ///      is a previous holder still holding control over an account they
    ///      sold.
    function _requireOwnerAndSync(uint256 tokenId) internal returns (Account storage) {
        // Reverts for a token that was never minted; that is the existence
        // check for the token itself.
        address currentOwner = agentNft.ownerOf(tokenId);
        if (msg.sender != currentOwner) {
            revert NotTokenOwner(tokenId, msg.sender);
        }

        Account storage account = _accounts[tokenId];
        if (!account.exists) {
            revert AccountDoesNotExist(tokenId);
        }

        if (account.lastKnownOwner != currentOwner) {
            // A transfer happened since the last interaction. Pause FIRST,
            // before any other state change in this call, so that no operation
            // in this transaction can run against an account whose holder just
            // changed.
            account.automationPaused = true;
            account.ownerPeriod += 1;
            account.lastKnownOwner = currentOwner;

            // Starter Mode: the new holder inherits a paused account with no
            // risk setting and must choose one deliberately. Reset to `Unset`
            // rather than to `Preservation` — defaulting somebody into a risk
            // level they never picked is exactly what separating collectible
            // identity from financial risk exists to prevent.
            account.mandate = Mandate.Unset;

            emit OwnerPeriodStarted(tokenId, currentOwner, account.ownerPeriod);
        }

        return account;
    }

    /// @dev The stored account with pending-transfer transformations applied
    ///      IN MEMORY ONLY. Never writes storage — it is `view`, so it cannot.
    ///
    ///      Transfer detection is lazy: there is no hook from the NFT contract
    ///      into this registry, so between a transfer and the new holder's
    ///      first interaction the stored account still describes the previous
    ///      holder's setup. Reading raw storage in that window hands out a
    ///      stale answer — the seller's pause state and the seller's risk
    ///      mandate — and anything sizing a position off those limits would be
    ///      working from an appetite the current holder never chose.
    ///
    ///      Applying the same transformations `_requireOwnerAndSync` will
    ///      write means every view reports the state the account is already
    ///      committed to, so a caller cannot observe a difference that depends
    ///      only on whether somebody has interacted yet. Every view exposing
    ///      account state must go through here.
    ///
    ///      Deliberately NOT gated on `account.exists`: for a token that has
    ///      no account, `lastKnownOwner` is the zero address and so differs
    ///      from the live owner, which makes `isAutomationPaused` return true.
    ///      That is the fail-safe answer for an account that cannot run
    ///      anything at all.
    function _effectiveAccount(uint256 tokenId) internal view returns (Account memory account) {
        account = _accounts[tokenId];
        if (account.lastKnownOwner != agentNft.ownerOf(tokenId)) {
            account.automationPaused = true;
            account.mandate = Mandate.Unset;
        }
    }

    /// @dev Reverts unless an account exists for `tokenId`.
    function _requireAccount(uint256 tokenId) private view {
        if (!_accounts[tokenId].exists) {
            revert AccountDoesNotExist(tokenId);
        }
    }
}
