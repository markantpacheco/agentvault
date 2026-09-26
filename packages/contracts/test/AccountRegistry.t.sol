// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {AccountRegistry} from "../src/AccountRegistry.sol";

/// @title MockAgentNft
/// @notice Minimal IERC721 standing in for the Genesis Agent NFT.
/// @dev Deliberately NOT `GenesisAgent`. The registry depends on the
///      interface, so these tests do too — they cannot break because
///      `GenesisAgent` changed, and they cannot accidentally reach an
///      archetype. Only `ownerOf` is real; everything else is a stub present
///      to satisfy the interface.
contract MockAgentNft is IERC721 {
    error NonexistentToken(uint256 tokenId);
    error NotImplemented();

    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;

    /// @dev Test helper. Assigns a token to an address.
    function mintTo(address to, uint256 tokenId) external {
        require(to != address(0), "mock: zero owner");
        require(_owners[tokenId] == address(0), "mock: exists");
        _owners[tokenId] = to;
        _balances[to] += 1;
    }

    /// @dev Test helper. Moves a token without any of ERC-721's checks.
    function transfer(uint256 tokenId, address to) external {
        address from = _owners[tokenId];
        require(from != address(0), "mock: nonexistent");
        require(to != address(0), "mock: zero owner");
        _owners[tokenId] = to;
        _balances[from] -= 1;
        _balances[to] += 1;
    }

    /// @dev Reverts for a token that was never minted. The registry relies on
    ///      this revert as its token-existence check, mirroring OpenZeppelin
    ///      v5's `ERC721NonexistentToken`.
    function ownerOf(uint256 tokenId) public view returns (address) {
        address owner = _owners[tokenId];
        if (owner == address(0)) {
            revert NonexistentToken(tokenId);
        }
        return owner;
    }

    function balanceOf(address owner) external view returns (uint256) {
        return _balances[owner];
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IERC721).interfaceId;
    }

    // Unused by the registry. Present only to satisfy IERC721.
    function safeTransferFrom(address, address, uint256, bytes calldata) external pure {
        revert NotImplemented();
    }

    function safeTransferFrom(address, address, uint256) external pure {
        revert NotImplemented();
    }

    function transferFrom(address, address, uint256) external pure {
        revert NotImplemented();
    }

    function approve(address, uint256) external pure {
        revert NotImplemented();
    }

    function setApprovalForAll(address, bool) external pure {
        revert NotImplemented();
    }

    function getApproved(uint256) external pure returns (address) {
        return address(0);
    }

    function isApprovedForAll(address, address) external pure returns (bool) {
        return false;
    }
}

/// @title AccountRegistryTest
/// @dev Invariant ids refer to docs/specs/AccountRegistry.md.
contract AccountRegistryTest is Test {
    MockAgentNft internal nft;
    AccountRegistry internal registry;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");

    uint256 internal constant TOKEN_A = 1;
    uint256 internal constant TOKEN_B = 2;

    event AccountCreated(uint256 indexed tokenId, address indexed owner, uint256 seedBalance);
    event AutomationPausedSet(uint256 indexed tokenId, bool paused);
    event OwnerPeriodStarted(uint256 indexed tokenId, address indexed newOwner, uint32 ownerPeriod);

    function setUp() public {
        nft = new MockAgentNft();
        registry = new AccountRegistry(IERC721(address(nft)));
        nft.mintTo(alice, TOKEN_A);
        nft.mintTo(bob, TOKEN_B);
    }

    function _createFor(address who, uint256 tokenId) internal {
        vm.prank(who);
        registry.createAccount(tokenId);
    }

    function _assertSameAccount(
        AccountRegistry.Account memory got,
        AccountRegistry.Account memory want
    ) internal pure {
        assertEq(got.exists, want.exists, "exists changed");
        assertEq(got.lastKnownOwner, want.lastKnownOwner, "lastKnownOwner changed");
        assertEq(got.depositedTotal, want.depositedTotal, "depositedTotal changed");
        assertEq(got.withdrawnTotal, want.withdrawnTotal, "withdrawnTotal changed");
        assertEq(got.balance, want.balance, "balance changed");
        assertEq(got.automationPaused, want.automationPaused, "automationPaused changed");
        assertEq(uint256(got.ownerPeriod), uint256(want.ownerPeriod), "ownerPeriod changed");
        assertEq(uint256(got.createdAt), uint256(want.createdAt), "createdAt changed");
    }

    // ---------------------------------------------------------------- creation

    /// WHAT: A new account is seeded with SEED_BALANCE as principal, PnL zero.
    /// WHY: The seed is principal, not performance. If it counted as profit,
    ///      every account would start by appearing to have made money.
    /// FAILURE MEANS: The performance record is inflated from the first block.
    function test_CreateAccountSeedsBalanceAndZeroPnl() public {
        _createFor(alice, TOKEN_A);

        AccountRegistry.Account memory a = registry.getAccount(TOKEN_A);
        assertEq(a.balance, registry.SEED_BALANCE(), "balance not seeded");
        assertEq(a.depositedTotal, registry.SEED_BALANCE(), "deposited not seeded");
        assertEq(a.withdrawnTotal, 0, "withdrawn not zero");
        assertEq(registry.netPrincipalOf(TOKEN_A), registry.SEED_BALANCE(), "net principal wrong");
        assertEq(registry.pnlOf(TOKEN_A), int256(0), "PnL not zero at creation");
    }

    /// WHAT: A new account starts at ownerPeriod 1.
    /// WHY: Zero means "no account", the same convention as the archetype zero
    ///      value and token ids starting at 1.
    /// FAILURE MEANS: A real account is indistinguishable from an empty slot.
    function test_NewAccountStartsAtOwnerPeriodOne() public {
        _createFor(alice, TOKEN_A);
        assertEq(uint256(registry.getAccount(TOKEN_A).ownerPeriod), 1, "ownerPeriod not 1");
    }

    /// WHAT: A new account starts paused.
    /// WHY: Automation must start off and be turned on deliberately.
    /// FAILURE MEANS: An account begins acting before its holder asked it to.
    function test_NewAccountStartsPaused() public {
        _createFor(alice, TOKEN_A);
        assertTrue(registry.isAutomationPaused(TOKEN_A), "new account not paused");
    }

    /// WHAT: createAccount emits AccountCreated with the right arguments.
    /// WHY: Account creation must be reconstructable from logs alone.
    /// FAILURE MEANS: Indexers cannot tell when an account came into being.
    function test_CreateAccountEmitsAccountCreated() public {
        vm.expectEmit(true, true, false, true, address(registry));
        emit AccountCreated(TOKEN_A, alice, 10_000e18);
        _createFor(alice, TOKEN_A);
    }

    /// WHAT: totalAccounts increments on creation.
    /// WHY: A simple population count used by later milestones.
    /// FAILURE MEANS: The registry miscounts its own accounts.
    function test_TotalAccountsIncrements() public {
        assertEq(registry.totalAccounts(), 0, "should start empty");
        _createFor(alice, TOKEN_A);
        assertEq(registry.totalAccounts(), 1, "not 1 after first");
        _createFor(bob, TOKEN_B);
        assertEq(registry.totalAccounts(), 2, "not 2 after second");
    }

    /// WHAT: Creating an account twice for the same token reverts.
    /// WHY: A second creation would reset balance and history to the seed,
    ///      erasing the record the product exists to keep.
    /// FAILURE MEANS: Anyone can wipe their own track record by re-creating.
    function test_CreateAccountTwiceReverts() public {
        _createFor(alice, TOKEN_A);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(AccountRegistry.AccountAlreadyExists.selector, TOKEN_A)
        );
        registry.createAccount(TOKEN_A);
    }

    /// WHAT: Creating an account for a token that was never minted reverts.
    /// WHY: The registry uses ownerOf's revert as its existence check rather
    ///      than duplicating one that could drift.
    /// FAILURE MEANS: Accounts can exist for tokens that do not.
    function test_CreateAccountForNonexistentTokenReverts() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(MockAgentNft.NonexistentToken.selector, uint256(99)));
        registry.createAccount(99);
    }

    /// WHAT: A non-owner cannot create an account for someone else's token.
    /// WHY: Only the holder controls their account, from the first call on.
    /// FAILURE MEANS: A stranger seeds and configures your account. Invariant 3.
    function test_NonOwnerCannotCreateAccount() public {
        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(AccountRegistry.NotTokenOwner.selector, TOKEN_A, bob)
        );
        registry.createAccount(TOKEN_A);
    }

    // --------------------------------------------------------------- isolation

    /// WHAT: Two tokens produce two accounts with independent balances.
    /// WHY: One isolated account per NFT is the architecture's first premise.
    /// FAILURE MEANS: Accounts share state. Invariant 1.
    function test_TwoTokensHaveIndependentAccounts() public {
        _createFor(alice, TOKEN_A);
        _createFor(bob, TOKEN_B);

        vm.prank(alice);
        registry.deposit(TOKEN_A, 500e18);

        assertEq(registry.getAccount(TOKEN_A).balance, 10_500e18, "A wrong");
        assertEq(registry.getAccount(TOKEN_B).balance, 10_000e18, "B moved");
    }

    /// WHAT: Depositing into A changes no field of B.
    /// WHY: Cross-account leakage is the failure the whole design guards.
    /// FAILURE MEANS: Account isolation is broken. Invariant 2.
    function test_DepositIntoADoesNotChangeB() public {
        _createFor(alice, TOKEN_A);
        _createFor(bob, TOKEN_B);
        AccountRegistry.Account memory before = registry.getAccount(TOKEN_B);

        vm.prank(alice);
        registry.deposit(TOKEN_A, 1234e18);

        _assertSameAccount(registry.getAccount(TOKEN_B), before);
    }

    /// WHAT: Withdrawing from A changes no field of B.
    /// WHY: As above, for the balance-reducing path.
    /// FAILURE MEANS: Account isolation is broken. Invariant 2.
    function test_WithdrawFromADoesNotChangeB() public {
        _createFor(alice, TOKEN_A);
        _createFor(bob, TOKEN_B);
        AccountRegistry.Account memory before = registry.getAccount(TOKEN_B);

        vm.prank(alice);
        registry.withdraw(TOKEN_A, 2500e18);

        _assertSameAccount(registry.getAccount(TOKEN_B), before);
    }

    /// WHAT: Pausing A does not change B's pause state.
    /// WHY: The kill switch is per account. A shared one would let one
    ///      holder's choice stop another holder's automation.
    /// FAILURE MEANS: Kill switches are not isolated. Invariant 2.
    function test_PausingADoesNotChangeB() public {
        _createFor(alice, TOKEN_A);
        _createFor(bob, TOKEN_B);

        vm.prank(bob);
        registry.setAutomationPaused(TOKEN_B, false);
        assertFalse(registry.isAutomationPaused(TOKEN_B), "B should be unpaused");

        vm.prank(alice);
        registry.setAutomationPaused(TOKEN_A, true);

        assertFalse(registry.isAutomationPaused(TOKEN_B), "B pause state changed");
    }

    /// WHAT: Any random sequence of operations on A leaves B byte-identical.
    /// WHY: Invariant 2 is the premise of the product, so it is fuzzed rather
    ///      than checked in a single hand-picked case.
    /// FAILURE MEANS: Some operation sequence leaks across accounts.
    function testFuzz_RandomOperationsOnALeaveBIdentical(uint256 seed, uint8 steps) public {
        _createFor(alice, TOKEN_A);
        _createFor(bob, TOKEN_B);
        AccountRegistry.Account memory before = registry.getAccount(TOKEN_B);

        uint256 count = bound(uint256(steps), 1, 24);
        for (uint256 i = 0; i < count; i++) {
            uint256 r = uint256(keccak256(abi.encode(seed, i)));
            uint256 op = r % 3;
            uint256 amount = bound(r >> 8, 1, 1_000e18);

            // Each vm.prank applies to exactly one call, so any read must
            // happen before it, never between it and the pranked call.
            if (op == 0) {
                vm.prank(alice);
                registry.deposit(TOKEN_A, amount);
            } else if (op == 1) {
                uint256 balance = registry.getAccount(TOKEN_A).balance;
                uint256 toWithdraw = amount > balance ? balance : amount;
                if (toWithdraw > 0) {
                    vm.prank(alice);
                    registry.withdraw(TOKEN_A, toWithdraw);
                }
            } else {
                vm.prank(alice);
                registry.setAutomationPaused(TOKEN_A, r % 2 == 0);
            }
        }

        _assertSameAccount(registry.getAccount(TOKEN_B), before);
    }

    // ---------------------------------------------------------- access control

    /// WHAT: A non-owner cannot deposit, withdraw, or pause.
    /// WHY: Only the current holder may act on an account.
    /// FAILURE MEANS: A stranger controls your account. Invariant 3.
    function test_NonOwnerCannotDepositWithdrawOrPause() public {
        _createFor(alice, TOKEN_A);
        bytes memory expected =
            abi.encodeWithSelector(AccountRegistry.NotTokenOwner.selector, TOKEN_A, carol);

        vm.prank(carol);
        vm.expectRevert(expected);
        registry.deposit(TOKEN_A, 1e18);

        vm.prank(carol);
        vm.expectRevert(expected);
        registry.withdraw(TOKEN_A, 1e18);

        vm.prank(carol);
        vm.expectRevert(expected);
        registry.setAutomationPaused(TOKEN_A, false);
    }

    /// WHAT: After transfer, the previous owner cannot act at all.
    /// WHY: The owner is read live, never cached. A cached owner is a previous
    ///      holder still controlling an account they sold.
    /// FAILURE MEANS: Selling the NFT does not surrender control. Invariant 4.
    function test_PreviousOwnerCannotActAfterTransfer() public {
        _createFor(alice, TOKEN_A);
        nft.transfer(TOKEN_A, carol);

        bytes memory expected =
            abi.encodeWithSelector(AccountRegistry.NotTokenOwner.selector, TOKEN_A, alice);

        vm.prank(alice);
        vm.expectRevert(expected);
        registry.deposit(TOKEN_A, 1e18);

        vm.prank(alice);
        vm.expectRevert(expected);
        registry.withdraw(TOKEN_A, 1e18);

        vm.prank(alice);
        vm.expectRevert(expected);
        registry.setAutomationPaused(TOKEN_A, false);
    }

    // -------------------------------------------------------- transfer handling

    /// WHAT: A detected transfer pauses automation on the new owner's first call.
    /// WHY: A new holder must not inherit running automation they never chose.
    /// FAILURE MEANS: Automation keeps running for a holder who never enabled
    ///      it. Invariant 5.
    function test_TransferPausesAutomationOnFirstInteraction() public {
        _createFor(alice, TOKEN_A);
        vm.prank(alice);
        registry.setAutomationPaused(TOKEN_A, false);
        assertFalse(registry.isAutomationPaused(TOKEN_A), "precondition: unpaused");

        nft.transfer(TOKEN_A, carol);

        vm.prank(carol);
        registry.deposit(TOKEN_A, 1e18);

        assertTrue(registry.getAccount(TOKEN_A).automationPaused, "not paused after sync");
    }

    /// WHAT: A transfer increments ownerPeriod by exactly one.
    /// WHY: Performance history keys on (tokenId, ownerPeriod) so a previous
    ///      holder's results stay attributable to them.
    /// FAILURE MEANS: Owner periods collide and records get misattributed.
    function test_TransferIncrementsOwnerPeriodByOne() public {
        _createFor(alice, TOKEN_A);
        nft.transfer(TOKEN_A, carol);

        vm.prank(carol);
        registry.setAutomationPaused(TOKEN_A, true);

        assertEq(uint256(registry.getAccount(TOKEN_A).ownerPeriod), 2, "period not 2");
    }

    /// WHAT: lastKnownOwner updates to the new owner on sync.
    /// WHY: Without it, every later call would re-detect the same transfer.
    /// FAILURE MEANS: ownerPeriod inflates on every call after a transfer.
    function test_TransferUpdatesLastKnownOwner() public {
        _createFor(alice, TOKEN_A);
        nft.transfer(TOKEN_A, carol);

        vm.prank(carol);
        registry.setAutomationPaused(TOKEN_A, true);
        assertEq(registry.getAccount(TOKEN_A).lastKnownOwner, carol, "lastKnownOwner stale");

        vm.prank(carol);
        registry.setAutomationPaused(TOKEN_A, true);
        assertEq(uint256(registry.getAccount(TOKEN_A).ownerPeriod), 2, "period re-incremented");
    }

    /// WHAT: OwnerPeriodStarted is emitted with the new owner and new period.
    /// WHY: The owner transition must be reconstructable from logs.
    /// FAILURE MEANS: Ownership history cannot be rebuilt off-chain.
    function test_OwnerPeriodStartedEmitted() public {
        _createFor(alice, TOKEN_A);
        nft.transfer(TOKEN_A, carol);

        vm.expectEmit(true, true, false, true, address(registry));
        emit OwnerPeriodStarted(TOKEN_A, carol, 2);
        vm.prank(carol);
        registry.setAutomationPaused(TOKEN_A, true);
    }

    /// WHAT: isAutomationPaused already reads true BEFORE the new owner acts.
    /// WHY: This is the fail-safe read. Transfer detection is lazy, so between
    ///      the transfer and the first interaction the stored flag is stale.
    ///      Anything asking whether automation may run must get the safe
    ///      answer during that window.
    /// FAILURE MEANS: The risk engine runs automation on an account whose
    ///      holder has already changed. Invariant 6.
    function test_IsAutomationPausedTrueBeforeSync() public {
        _createFor(alice, TOKEN_A);
        vm.prank(alice);
        registry.setAutomationPaused(TOKEN_A, false);
        assertFalse(registry.isAutomationPaused(TOKEN_A), "precondition: unpaused");

        nft.transfer(TOKEN_A, carol);

        // Stored flag is still false; the read must not be.
        assertFalse(registry.getAccount(TOKEN_A).automationPaused, "raw flag should be stale");
        assertTrue(registry.isAutomationPaused(TOKEN_A), "unsynced transfer read as running");
    }

    /// WHAT: isTransferPending is true after transfer and false after sync.
    /// WHY: Callers need to distinguish a stale account from a current one.
    /// FAILURE MEANS: Staleness is invisible to callers.
    function test_IsTransferPendingTrueUntilSync() public {
        _createFor(alice, TOKEN_A);
        assertFalse(registry.isTransferPending(TOKEN_A), "pending before any transfer");

        nft.transfer(TOKEN_A, carol);
        assertTrue(registry.isTransferPending(TOKEN_A), "not pending after transfer");

        vm.prank(carol);
        registry.setAutomationPaused(TOKEN_A, true);
        assertFalse(registry.isTransferPending(TOKEN_A), "still pending after sync");
    }

    /// WHAT: Balance and principal totals survive a transfer unchanged.
    /// WHY: The record attaches to the NFT and is portable. A change of holder
    ///      must not wipe the account's financial history.
    /// FAILURE MEANS: Transferring resets the record the product sells.
    function test_FinancialHistorySurvivesTransfer() public {
        _createFor(alice, TOKEN_A);
        vm.prank(alice);
        registry.deposit(TOKEN_A, 700e18);
        vm.prank(alice);
        registry.withdraw(TOKEN_A, 200e18);

        AccountRegistry.Account memory before = registry.getAccount(TOKEN_A);
        nft.transfer(TOKEN_A, carol);
        vm.prank(carol);
        registry.setAutomationPaused(TOKEN_A, true);
        AccountRegistry.Account memory afterTransfer = registry.getAccount(TOKEN_A);

        assertEq(afterTransfer.balance, before.balance, "balance wiped");
        assertEq(afterTransfer.depositedTotal, before.depositedTotal, "deposits wiped");
        assertEq(afterTransfer.withdrawnTotal, before.withdrawnTotal, "withdrawals wiped");
        assertEq(uint256(afterTransfer.createdAt), uint256(before.createdAt), "createdAt changed");
    }

    /// WHAT: Two consecutive transfers increment ownerPeriod by two.
    /// WHY: ownerPeriod only ever increases and never resets.
    /// FAILURE MEANS: Owner periods are reused. Invariant 10.
    function test_TwoTransfersIncrementOwnerPeriodByTwo() public {
        _createFor(alice, TOKEN_A);

        nft.transfer(TOKEN_A, carol);
        vm.prank(carol);
        registry.setAutomationPaused(TOKEN_A, true);

        nft.transfer(TOKEN_A, bob);
        vm.prank(bob);
        registry.setAutomationPaused(TOKEN_A, true);

        assertEq(uint256(registry.getAccount(TOKEN_A).ownerPeriod), 3, "period not 3");
    }

    // ------------------------------------------------------- principal and PnL

    /// WHAT: A deposit raises balance and depositedTotal equally; PnL is flat.
    /// WHY: "A deposit never increases recorded profit" is an acceptance
    ///      criterion, and here it holds by construction.
    /// FAILURE MEANS: Funding an account looks like making money. Invariant 7.
    function test_DepositKeepsPnlUnchanged() public {
        _createFor(alice, TOKEN_A);
        int256 before = registry.pnlOf(TOKEN_A);

        vm.prank(alice);
        registry.deposit(TOKEN_A, 4321e18);

        AccountRegistry.Account memory a = registry.getAccount(TOKEN_A);
        assertEq(a.balance, 14_321e18, "balance wrong");
        assertEq(a.depositedTotal, 14_321e18, "depositedTotal wrong");
        assertEq(registry.pnlOf(TOKEN_A), before, "PnL moved on deposit");
    }

    /// WHAT: A withdrawal lowers balance, raises withdrawnTotal, PnL flat.
    /// WHY: Removing principal is not a loss.
    /// FAILURE MEANS: Withdrawing looks like losing money.
    function test_WithdrawKeepsPnlUnchanged() public {
        _createFor(alice, TOKEN_A);
        int256 before = registry.pnlOf(TOKEN_A);

        vm.prank(alice);
        registry.withdraw(TOKEN_A, 1000e18);

        AccountRegistry.Account memory a = registry.getAccount(TOKEN_A);
        assertEq(a.balance, 9000e18, "balance wrong");
        assertEq(a.withdrawnTotal, 1000e18, "withdrawnTotal wrong");
        assertEq(registry.pnlOf(TOKEN_A), before, "PnL moved on withdrawal");
    }

    /// WHAT: Across random deposits and withdrawals, PnL stays exactly zero.
    /// WHY: Nothing in this milestone can generate real PnL, so any nonzero
    ///      result means principal has leaked into performance.
    /// FAILURE MEANS: The performance record is contaminated by funding
    ///      activity. Invariant 7.
    function testFuzz_PnlStaysZeroAcrossDepositsAndWithdrawals(uint256 seed, uint8 steps) public {
        _createFor(alice, TOKEN_A);

        uint256 count = bound(uint256(steps), 1, 24);
        for (uint256 i = 0; i < count; i++) {
            uint256 r = uint256(keccak256(abi.encode(seed, i)));
            uint256 amount = bound(r >> 8, 1, 5_000e18);

            if (r % 2 == 0) {
                vm.prank(alice);
                registry.deposit(TOKEN_A, amount);
            } else {
                uint256 balance = registry.getAccount(TOKEN_A).balance;
                uint256 toWithdraw = amount > balance ? balance : amount;
                if (toWithdraw > 0) {
                    vm.prank(alice);
                    registry.withdraw(TOKEN_A, toWithdraw);
                }
            }

            assertEq(registry.pnlOf(TOKEN_A), int256(0), "principal leaked into PnL");
        }
    }

    // ------------------------------------------------------------- kill switch

    /// WHAT: The holder can pause and unpause their own account.
    /// WHY: The kill switch requires no protocol approval, and none exists.
    /// FAILURE MEANS: The holder cannot stop their own automation.
    function test_HolderCanPauseAndUnpause() public {
        _createFor(alice, TOKEN_A);

        vm.prank(alice);
        registry.setAutomationPaused(TOKEN_A, false);
        assertFalse(registry.isAutomationPaused(TOKEN_A), "unpause failed");

        vm.prank(alice);
        registry.setAutomationPaused(TOKEN_A, true);
        assertTrue(registry.isAutomationPaused(TOKEN_A), "pause failed");
    }

    /// WHAT: Withdrawal succeeds while automation is paused.
    /// WHY: Named acceptance criterion — the kill switch never blocks
    ///      withdrawal. There is deliberately no pause check in withdraw.
    /// FAILURE MEANS: Stopping automation traps the holder's principal.
    ///      Invariant 8.
    function test_WithdrawSucceedsWhilePaused() public {
        _createFor(alice, TOKEN_A);
        vm.prank(alice);
        registry.setAutomationPaused(TOKEN_A, true);
        assertTrue(registry.isAutomationPaused(TOKEN_A), "precondition: paused");

        vm.prank(alice);
        registry.withdraw(TOKEN_A, 3000e18);

        assertEq(registry.getAccount(TOKEN_A).balance, 7000e18, "withdrawal blocked by pause");
    }

    /// WHAT: Deposit also succeeds while paused.
    /// WHY: Pausing stops automation, not the holder.
    /// FAILURE MEANS: The kill switch locks the holder out of their own
    ///      account.
    function test_DepositSucceedsWhilePaused() public {
        _createFor(alice, TOKEN_A);
        vm.prank(alice);
        registry.setAutomationPaused(TOKEN_A, true);

        vm.prank(alice);
        registry.deposit(TOKEN_A, 250e18);

        assertEq(registry.getAccount(TOKEN_A).balance, 10_250e18, "deposit blocked by pause");
    }

    // -------------------------------------------------------------- validation

    /// WHAT: Zero-amount deposit and withdraw both revert.
    /// WHY: A zero-amount call is always a mistake and should fail loudly
    ///      rather than emit a meaningless event.
    /// FAILURE MEANS: The log fills with no-op entries.
    function test_ZeroAmountDepositAndWithdrawRevert() public {
        _createFor(alice, TOKEN_A);

        vm.prank(alice);
        vm.expectRevert(AccountRegistry.ZeroAmount.selector);
        registry.deposit(TOKEN_A, 0);

        vm.prank(alice);
        vm.expectRevert(AccountRegistry.ZeroAmount.selector);
        registry.withdraw(TOKEN_A, 0);
    }

    /// WHAT: Withdrawing more than the balance reverts with the amounts.
    /// WHY: Balance must never go negative, and the caller should be told what
    ///      was available rather than getting a bare panic.
    /// FAILURE MEANS: Underflow, or an unhelpful failure. Invariant 9.
    function test_WithdrawMoreThanBalanceReverts() public {
        _createFor(alice, TOKEN_A);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                AccountRegistry.InsufficientBalance.selector, 10_000e18 + 1, 10_000e18
            )
        );
        registry.withdraw(TOKEN_A, 10_000e18 + 1);
    }

    /// WHAT: A balance past int256's range makes pnlOf revert, not wrap.
    /// WHY: Deposits are unbounded in this prototype, so a balance above
    ///      2^255-1 is reachable by a holder depositing absurd amounts. A raw
    ///      cast would wrap it into a large negative number and report a
    ///      catastrophic loss that never happened. Reverting is the correct
    ///      failure: a fabricated number in an accounting path is worse than
    ///      an error, because nothing downstream can tell it is wrong.
    /// FAILURE MEANS: The performance record can be driven to show an
    ///      invented loss. Turns the SafeCast reasoning into something
    ///      enforced rather than argued in a comment.
    function test_PnlRevertsRatherThanWrappingOnHugeBalance() public {
        _createFor(alice, TOKEN_A);

        // 2^255 — one past int256's maximum, but well inside uint256, so the
        // deposit itself does not overflow.
        uint256 huge = uint256(1) << 255;
        vm.prank(alice);
        registry.deposit(TOKEN_A, huge);

        uint256 balance = registry.getAccount(TOKEN_A).balance;
        assertGt(balance, uint256(type(int256).max), "precondition: balance must exceed int256");

        // The unsigned view still answers; only the signed one cannot.
        assertEq(registry.netPrincipalOf(TOKEN_A), balance, "net principal unreadable");

        vm.expectRevert(
            abi.encodeWithSelector(SafeCast.SafeCastOverflowedUintToInt.selector, balance)
        );
        registry.pnlOf(TOKEN_A);
    }

    /// WHAT: The constructor rejects a zero NFT address.
    /// WHY: A zero NFT makes every authorisation path revert, producing a dead
    ///      registry that still looks deployed.
    /// FAILURE MEANS: A bricked deployment appears successful.
    function test_ConstructorRevertsOnZeroAddress() public {
        vm.expectRevert(AccountRegistry.ZeroAddress.selector);
        new AccountRegistry(IERC721(address(0)));
    }

    /// WHAT: Views revert for an account that was never created.
    /// WHY: Returning zeroed state would be indistinguishable from a real
    ///      account holding nothing.
    /// FAILURE MEANS: Callers cannot tell "no account" from "empty account".
    function test_ViewsRevertForMissingAccount() public {
        bytes memory expected =
            abi.encodeWithSelector(AccountRegistry.AccountDoesNotExist.selector, TOKEN_A);

        vm.expectRevert(expected);
        registry.getAccount(TOKEN_A);
        vm.expectRevert(expected);
        registry.netPrincipalOf(TOKEN_A);
        vm.expectRevert(expected);
        registry.pnlOf(TOKEN_A);
        vm.expectRevert(expected);
        registry.isTransferPending(TOKEN_A);

        assertFalse(registry.accountExists(TOKEN_A), "accountExists should be false");
    }
}
