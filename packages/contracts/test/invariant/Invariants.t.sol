// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {GenesisAgent} from "../../src/GenesisAgent.sol";
import {AccountRegistry} from "../../src/AccountRegistry.sol";
import {IAccountRegistry} from "../../src/interfaces/IAccountRegistry.sol";
import {Mandate} from "../../src/Mandate.sol";
import {RiskEngine, TradeProposal, Side, RejectReason} from "../../src/RiskEngine.sol";
import {InvariantHandler} from "./InvariantHandler.sol";

/// @title Invariants
/// @notice Stateful fuzz (invariant) tests. Each invariant is a claim this
///         project makes publicly, and each needs state to EVOLVE across a
///         sequence of calls — which is why the existing pure-fuzz tests cannot
///         reach them. A pure fuzz test randomises inputs against one state;
///         these randomise the state itself.
///
/// @dev Uses NO `vm.setEnv`. See the gotcha in CLAUDE.md — it races across
///      parallel test contracts and is what made the suite flaky before.
contract InvariantsTest is Test {
    GenesisAgent internal nft;
    AccountRegistry internal registry;
    RiskEngine internal engine;
    InvariantHandler internal handler;

    /// @dev Test fixtures, not real token addresses.
    address internal constant ASSET_OK = address(0x1000000000000000000000000000000000000001);
    address internal constant ASSET_UNLISTED = address(0x1000000000000000000000000000000000000009);

    function setUp() public {
        // Far enough past zero that a proposal can be MAX_DATA_AGE old without
        // the age subtraction underflowing.
        vm.warp(1_000_000);

        nft = new GenesisAgent(10_000);
        registry = new AccountRegistry(IERC721(address(nft)));
        address[] memory assets = new address[](1);
        assets[0] = ASSET_OK;
        engine = new RiskEngine(IAccountRegistry(address(registry)), assets);

        handler = new InvariantHandler(nft, registry);

        // Only the handler is fuzzed. Without this, the fuzzer would also call
        // the contracts directly, unbounded, and spend the whole run reverting.
        targetContract(address(handler));
    }

    /// @dev Pseudo-random proposal, varied by `salt`. Deterministic given the
    ///      salt so a failure is reproducible.
    function _proposal(uint256 salt, address asset) internal view returns (TradeProposal memory) {
        uint256 r = uint256(keccak256(abi.encode(salt, block.timestamp)));
        return TradeProposal({
            asset: asset,
            side: Side(1 + (r % 2)),
            sizeUnits: (r >> 8) % 2_000_000e18,
            slippageBps: uint16((r >> 16) % 10_001),
            dataTimestamp: block.timestamp - ((r >> 32) % 400)
        });
    }

    // =======================================================================
    // I1 — Withdrawal liveness
    // =======================================================================

    /// WHAT: In every reachable state — paused, mid-transfer, unsynced — the
    ///       current holder can withdraw their entire balance.
    /// WHY: The kill switch must never trap a holder's principal, and neither
    ///      must a pending transfer. This is the strongest promise the system
    ///      makes, and it is the one a holder would care about at the worst
    ///      moment.
    /// FAILURE MEANS: Some reachable state locks funds. Unacceptable regardless
    ///      of how the state was reached.
    /// @dev Mutates state to prove liveness, so it snapshots first and reverts
    ///      after. A leaked mutation would surface later as a spurious failure
    ///      in a different invariant and be miserable to diagnose.
    function invariant_I1_WithdrawalLivenessInEveryState() public {
        uint256 snapshot = vm.snapshotState();

        uint256 count = handler.actorCount();
        for (uint256 i = 0; i < count; i++) {
            uint256 tokenId = handler.tokenAt(i);
            if (!registry.accountExists(tokenId)) continue;

            uint256 balance = registry.getAccount(tokenId).balance;
            if (balance == 0) continue;

            // The LIVE holder, whatever the stored state thinks.
            address holder = nft.ownerOf(tokenId);

            vm.prank(holder);
            registry.withdraw(tokenId, balance);

            assertEq(
                registry.getAccount(tokenId).balance,
                0,
                "I1: holder could not withdraw the full balance"
            );
        }

        assertTrue(vm.revertToState(snapshot), "I1: snapshot revert failed");
    }

    // =======================================================================
    // I2 — A deposit is never profit
    // =======================================================================

    /// WHAT: PnL equals balance minus net principal, and — because nothing can
    ///       move a balance except the holder's own deposits and withdrawals —
    ///       balance equals net principal exactly, so PnL is always zero.
    /// WHY: The product's whole value is that the performance record cannot be
    ///      inflated. Funding an account must never look like making money.
    /// FAILURE MEANS: Principal has leaked into recorded performance.
    /// @dev Compares the contract's accounting against GHOST totals tracked
    ///      independently in the handler, so this is not the contract being
    ///      asked to agree with itself.
    ///
    ///      NOTE: this invariant necessarily CHANGES SHAPE once execution
    ///      exists. Today no code path moves a balance, so `balance == net
    ///      principal` holds exactly and PnL is identically zero. When trade
    ///      settlement lands (TODO(milestone-6)), balance will diverge from net
    ///      principal by realised PnL, and only the first equation below will
    ///      still hold. The second must then be replaced, not deleted.
    function invariant_I2_DepositIsNeverProfit() public view {
        uint256 count = handler.actorCount();
        for (uint256 i = 0; i < count; i++) {
            uint256 tokenId = handler.tokenAt(i);
            if (!registry.accountExists(tokenId)) continue;

            AccountRegistry.Account memory a = registry.getAccount(tokenId);

            // The contract's own totals must match the handler's ghosts.
            assertEq(
                a.depositedTotal, handler.ghostDeposited(tokenId), "I2: depositedTotal != ghost"
            );
            assertEq(
                a.withdrawnTotal, handler.ghostWithdrawn(tokenId), "I2: withdrawnTotal != ghost"
            );

            uint256 netPrincipal = a.depositedTotal - a.withdrawnTotal;

            // Equation 1: definitional. Survives the arrival of execution.
            assertEq(
                registry.pnlOf(tokenId),
                int256(a.balance) - int256(netPrincipal),
                "I2: pnl != balance - netPrincipal"
            );

            // Equation 2: A DELIBERATE TRIPWIRE. DO NOT DELETE THIS WHEN IT
            // FAILS.
            //
            // This asserts balance == netPrincipal, which is true ONLY while no
            // code path can move a balance. Today none can: the only mutations
            // are the holder's own deposits and withdrawals, and trade
            // settlement does not exist (TODO(milestone-6) in
            // AccountRegistry.sol).
            //
            // **It is SUPPOSED to fail the day execution lands.** That failure
            // is not a bug and not a regression — it is the signal that
            // settlement is now moving balances, which is exactly the moment
            // this equation stops describing the system.
            //
            // When it fires: REPLACE it, do not delete it. The successor should
            // assert that balance diverges from net principal only by realised
            // PnL, which is the same claim adapted to a system that can
            // actually trade. Deleting it silently removes the only automated
            // check that principal has not leaked into performance — the
            // product's central promise.
            //
            // Equation 1 above is definitional and survives unchanged.
            assertEq(
                a.balance,
                netPrincipal,
                "I2 TRIPWIRE: balance diverged from net principal - if settlement now exists this is expected, REPLACE this assertion, do not delete it"
            );
            assertEq(registry.pnlOf(tokenId), int256(0), "I2: PnL is not zero");
        }
    }

    // =======================================================================
    // I3 — Paused implies never approved
    // =======================================================================

    /// WHAT: After any sequence of operations, if effective automation-paused is
    ///       true, `validate` approves nothing — for any asset, side, size,
    ///       slippage or timestamp.
    /// WHY: The holder's kill switch outranks every property of a trade. The
    ///      pure-fuzz version proves this for one state; this proves it for
    ///      every reachable state, including the unsynced window after a
    ///      transfer where the stored flag still says "running".
    /// FAILURE MEANS: Some reachable state lets automation run after the holder
    ///      stopped it, or after the NFT changed hands.
    function invariant_I3_PausedImpliesNeverApproved() public view {
        uint256 count = handler.actorCount();
        for (uint256 i = 0; i < count; i++) {
            uint256 tokenId = handler.tokenAt(i);
            if (!registry.accountExists(tokenId)) continue;
            if (!registry.isAutomationPaused(tokenId)) continue;

            for (uint256 k = 0; k < 4; k++) {
                address asset = (k % 2 == 0) ? ASSET_OK : ASSET_UNLISTED;
                TradeProposal memory p = _proposal(tokenId * 100 + k, asset);

                (bool approved, RejectReason reason) = engine.validate(tokenId, p);
                assertFalse(approved, "I3: approved while effectively paused");
                assertEq(
                    uint8(reason),
                    uint8(RejectReason.AutomationPaused),
                    "I3: paused account rejected for the wrong reason"
                );
            }
        }
    }

    // =======================================================================
    // I4 — Archetype cannot influence risk
    // =======================================================================

    /// WHAT: Two accounts differing ONLY in archetype, given identical mandates
    ///       and identical balances and identical operations, always produce
    ///       identical verdicts and identical reasons for identical proposals.
    /// WHY: This is the separation the whole architecture is arranged around. A
    ///      Maverick holder who wants to be cautious must be able to be, and a
    ///      Guardian holder who wants to be aggressive must be able to be.
    /// FAILURE MEANS: Collectible rarity influences financial risk.
    /// @dev Also asserts the PREMISE — that the twins really are otherwise
    ///      identical. Without that, the verdict comparison could pass
    ///      vacuously because the twins had drifted apart for an unrelated
    ///      reason, and the invariant would be proving nothing.
    function invariant_I4_ArchetypeCannotInfluenceRisk() public view {
        uint256 g = handler.twinGuardian();
        uint256 m = handler.twinMaverick();

        AccountRegistry.Account memory ag = registry.getAccount(g);
        AccountRegistry.Account memory am = registry.getAccount(m);

        // The premise: identical in everything except archetype.
        assertEq(ag.balance, am.balance, "I4 premise: twin balances diverged");
        assertEq(ag.depositedTotal, am.depositedTotal, "I4 premise: deposits diverged");
        assertEq(ag.withdrawnTotal, am.withdrawnTotal, "I4 premise: withdrawals diverged");
        assertEq(uint8(ag.mandate), uint8(am.mandate), "I4 premise: mandates diverged");
        assertEq(
            registry.isAutomationPaused(g),
            registry.isAutomationPaused(m),
            "I4 premise: pause states diverged"
        );
        // And they really are different archetypes, or this proves nothing.
        assertTrue(nft.archetypeOf(g) != nft.archetypeOf(m), "I4 premise: twins share an archetype");

        for (uint256 k = 0; k < 6; k++) {
            address asset = (k % 3 == 0) ? ASSET_UNLISTED : ASSET_OK;
            TradeProposal memory p = _proposal(k, asset);

            (bool approvedG, RejectReason reasonG) = engine.validate(g, p);
            (bool approvedM, RejectReason reasonM) = engine.validate(m, p);

            assertEq(approvedG, approvedM, "I4: verdict differed across archetypes");
            assertEq(uint8(reasonG), uint8(reasonM), "I4: reason differed across archetypes");
        }
    }

    // =======================================================================
    // Coverage — the trap this guards against
    // =======================================================================

    /// @notice Runs at the end of every invariant run and REPORTS what the
    ///         handler achieved. Deliberately contains no assertions.
    ///
    /// @dev A coverage assertion CANNOT live here. When an invariant fails,
    ///      Foundry shrinks the failing sequence toward the shortest one that
    ///      still fails — and a coverage assertion is trivially failable by a
    ///      one-call sequence, so the shrinker drives straight to it and reports
    ///      "no withdrawal succeeded" against a single call. That is what
    ///      happened on the first run of this suite: 4096 calls, zero reverts,
    ///      and a reported failure on a sequence of length 1.
    ///
    ///      So coverage is REPORTED here, from real invariant runs, and
    ///      ASSERTED in `test_HandlerIsNotDecorative` below, which is an
    ///      ordinary test and therefore not subject to shrinking.
    function afterInvariant() public view {
        uint256 total = _totalMutations();

        console.log("--- handler mutations this run ---");
        console.log("  createAccount ", handler.countCreateAccount());
        console.log("  deposit       ", handler.countDeposit());
        console.log("  withdraw      ", handler.countWithdraw());
        console.log("  setPause      ", handler.countSetPause());
        console.log("  setMandate    ", handler.countSetMandate());
        console.log("  transferToken ", handler.countTransfer());
        console.log("  syncAccount   ", handler.countSync());
        console.log("  twinDeposit   ", handler.countTwinDeposit());
        console.log("  twinWithdraw  ", handler.countTwinWithdraw());
        console.log("  twinMandate   ", handler.countTwinMandate());
        console.log("  twinPause     ", handler.countTwinPause());
        console.log("  TOTAL         ", total);
    }

    function _totalMutations() internal view returns (uint256) {
        return handler.countCreateAccount() + handler.countDeposit() + handler.countWithdraw()
            + handler.countSetPause() + handler.countSetMandate() + handler.countTransfer()
            + handler.countSync() + handler.countTwinDeposit() + handler.countTwinWithdraw()
            + handler.countTwinMandate() + handler.countTwinPause();
    }

    /// WHAT: Driven through a long pseudo-random sequence, every handler action
    ///       succeeds a meaningful number of times.
    /// WHY: THE TRAP THIS GUARDS AGAINST — an invariant suite whose handler
    ///      calls mostly revert, or mostly return early, passes trivially while
    ///      exploring nothing. Four green invariants over an inert handler are
    ///      decorative, and worse than having none because they look like
    ///      evidence.
    /// FAILURE MEANS: The invariants above are not actually exercising the
    ///      system, and their passing means nothing.
    /// @dev An ordinary test, not an invariant, precisely so the shrinker cannot
    ///      reduce it to a trivially-failing short sequence. Counters increment
    ///      only after a state change succeeded, so these are mutations
    ///      performed and not calls attempted.
    function test_HandlerIsNotDecorative() public {
        for (uint256 i = 0; i < 600; i++) {
            uint256 r = uint256(keccak256(abi.encode("coverage", i)));
            uint256 action = r % 8;

            if (action == 0) handler.createAccount(r >> 8);
            else if (action == 1) handler.deposit(r >> 8, r >> 16);
            else if (action == 2) handler.withdraw(r >> 8, r >> 16);
            else if (action == 3) handler.setPause(r >> 8, (r >> 16) % 2 == 0);
            else if (action == 4) handler.setMandate(r >> 8, r >> 16);
            else if (action == 5) handler.transferToken(r >> 8, r >> 16);
            else if (action == 6) handler.syncAccount(r >> 8);
            else handler.twinOperation(r >> 8, r >> 16, r >> 32);
        }

        console.log("--- coverage drive: mutations achieved ---");
        console.log("  createAccount ", handler.countCreateAccount());
        console.log("  deposit       ", handler.countDeposit());
        console.log("  withdraw      ", handler.countWithdraw());
        console.log("  setPause      ", handler.countSetPause());
        console.log("  setMandate    ", handler.countSetMandate());
        console.log("  transferToken ", handler.countTransfer());
        console.log("  syncAccount   ", handler.countSync());
        console.log("  twinDeposit   ", handler.countTwinDeposit());
        console.log("  twinWithdraw  ", handler.countTwinWithdraw());
        console.log("  twinMandate   ", handler.countTwinMandate());
        console.log("  twinPause     ", handler.countTwinPause());
        console.log("  TOTAL         ", _totalMutations());

        assertGt(handler.countCreateAccount(), 0, "createAccount never succeeded");
        assertGt(handler.countDeposit(), 5, "deposit barely succeeded");
        assertGt(handler.countWithdraw(), 5, "withdraw barely succeeded");
        assertGt(handler.countSetPause(), 5, "setPause barely succeeded");
        assertGt(handler.countSetMandate(), 5, "setMandate barely succeeded");
        assertGt(handler.countTransfer(), 5, "transferToken barely succeeded");
        assertGt(
            handler.countSync(),
            0,
            "syncAccount never succeeded - the stale-transfer window is untested"
        );
        assertGt(handler.countTwinDeposit(), 0, "twin deposit never succeeded");
        assertGt(handler.countTwinWithdraw(), 0, "twin withdraw never succeeded");
        assertGt(handler.countTwinMandate(), 0, "twin mandate never succeeded");
        assertGt(handler.countTwinPause(), 0, "twin pause never succeeded");
        assertGt(_totalMutations(), 200, "handler did too little work overall");
    }
}
