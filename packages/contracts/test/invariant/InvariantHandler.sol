// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {GenesisAgent} from "../../src/GenesisAgent.sol";
import {AccountRegistry} from "../../src/AccountRegistry.sol";
import {Archetype} from "../../src/Archetype.sol";
import {Mandate} from "../../src/Mandate.sol";

/// @title InvariantHandler
/// @notice Drives the real contracts through bounded, always-valid sequences so
///         stateful fuzzing explores reachable states instead of bouncing off
///         reverts.
///
/// @dev DESIGN RULE: NO FUNCTION HERE MAY REVERT. Every action checks its
///      preconditions and returns early when they are unmet. That lets
///      `fail_on_revert = true` be meaningful — any revert is then a real
///      problem, not an expected rejection.
///
///      But "did not revert" is weak evidence on its own: a handler whose
///      functions all return early would satisfy `fail_on_revert` while doing
///      nothing at all. So every counter below increments ONLY AFTER a state
///      change actually succeeded. The counters measure work done, not calls
///      attempted, and the invariant suite asserts they are non-trivial.
///
///      Uses NO `vm.setEnv`. That cheatcode mutates shared process state and
///      races across parallel test contracts — see the gotcha in CLAUDE.md.
contract InvariantHandler is Test {
    GenesisAgent public immutable nft;
    AccountRegistry public immutable registry;

    /// @notice General-purpose actors, each holding one token from setUp.
    address[] public actors;
    uint256[] public tokenIds;

    /// @notice Twin tokens for the archetype-isolation invariant. They differ
    ///         ONLY in archetype and receive byte-identical operations.
    /// @dev Deliberately excluded from transfers: a transfer changes holder and
    ///      owner period, which has nothing to do with archetype, and would
    ///      break the lockstep the invariant depends on.
    uint256 public twinGuardian;
    uint256 public twinMaverick;
    address public twinHolderGuardian;
    address public twinHolderMaverick;

    // ---- ghost accounting, kept independently of the contract -------------
    mapping(uint256 => uint256) public ghostDeposited;
    mapping(uint256 => uint256) public ghostWithdrawn;

    // ---- mutation counters: incremented only on success -------------------
    uint256 public countCreateAccount;
    uint256 public countDeposit;
    uint256 public countWithdraw;
    uint256 public countSetPause;
    uint256 public countSetMandate;
    uint256 public countTransfer;
    uint256 public countSync;
    uint256 public countTwinDeposit;
    uint256 public countTwinWithdraw;
    uint256 public countTwinMandate;
    uint256 public countTwinPause;

    constructor(GenesisAgent nft_, AccountRegistry registry_) {
        nft = nft_;
        registry = registry_;

        // Six general actors. GenesisAgent allows one mint per address ever, so
        // each actor needs its own address and mints exactly once here.
        Archetype[6] memory kinds = [
            Archetype.Guardian,
            Archetype.Navigator,
            Archetype.Tactician,
            Archetype.Maverick,
            Archetype.Guardian,
            Archetype.Navigator
        ];
        for (uint256 i = 0; i < 6; i++) {
            address actor = makeAddr(string.concat("actor", vm.toString(i)));
            actors.push(actor);
            vm.prank(actor);
            tokenIds.push(nft_.mint(kinds[i]));
        }

        // Twins: different archetypes, everything else identical.
        twinHolderGuardian = makeAddr("twinGuardian");
        twinHolderMaverick = makeAddr("twinMaverick");
        vm.prank(twinHolderGuardian);
        twinGuardian = nft_.mint(Archetype.Guardian);
        vm.prank(twinHolderMaverick);
        twinMaverick = nft_.mint(Archetype.Maverick);

        vm.prank(twinHolderGuardian);
        registry_.createAccount(twinGuardian);
        vm.prank(twinHolderMaverick);
        registry_.createAccount(twinMaverick);

        // Identical starting mandate and pause state.
        vm.prank(twinHolderGuardian);
        registry_.setMandate(twinGuardian, Mandate.Balanced);
        vm.prank(twinHolderMaverick);
        registry_.setMandate(twinMaverick, Mandate.Balanced);
        vm.prank(twinHolderGuardian);
        registry_.setAutomationPaused(twinGuardian, false);
        vm.prank(twinHolderMaverick);
        registry_.setAutomationPaused(twinMaverick, false);

        ghostDeposited[twinGuardian] = registry_.SEED_BALANCE();
        ghostDeposited[twinMaverick] = registry_.SEED_BALANCE();
    }

    function actorCount() external view returns (uint256) {
        return actors.length;
    }

    function tokenAt(uint256 i) external view returns (uint256) {
        return tokenIds[i];
    }

    /// @dev The LIVE holder, read fresh. Never cached — a cached holder is a
    ///      previous holder.
    function _holder(uint256 tokenId) private view returns (address) {
        return nft.ownerOf(tokenId);
    }

    function _pickToken(uint256 seed) private view returns (uint256) {
        return tokenIds[bound(seed, 0, tokenIds.length - 1)];
    }

    // -----------------------------------------------------------------------
    // General actions
    // -----------------------------------------------------------------------

    function createAccount(uint256 seed) external {
        uint256 tokenId = _pickToken(seed);
        if (registry.accountExists(tokenId)) return;

        vm.prank(_holder(tokenId));
        registry.createAccount(tokenId);
        ghostDeposited[tokenId] += registry.SEED_BALANCE();
        countCreateAccount += 1;
    }

    function deposit(uint256 seed, uint256 rawAmount) external {
        uint256 tokenId = _pickToken(seed);
        if (!registry.accountExists(tokenId)) return;

        uint256 amount = bound(rawAmount, 1, 1_000_000e18);
        vm.prank(_holder(tokenId));
        registry.deposit(tokenId, amount);
        ghostDeposited[tokenId] += amount;
        countDeposit += 1;
    }

    function withdraw(uint256 seed, uint256 rawAmount) external {
        uint256 tokenId = _pickToken(seed);
        if (!registry.accountExists(tokenId)) return;

        uint256 balance = registry.getAccount(tokenId).balance;
        if (balance == 0) return;

        uint256 amount = bound(rawAmount, 1, balance);
        vm.prank(_holder(tokenId));
        registry.withdraw(tokenId, amount);
        ghostWithdrawn[tokenId] += amount;
        countWithdraw += 1;
    }

    function setPause(uint256 seed, bool paused) external {
        uint256 tokenId = _pickToken(seed);
        if (!registry.accountExists(tokenId)) return;

        vm.prank(_holder(tokenId));
        registry.setAutomationPaused(tokenId, paused);
        countSetPause += 1;
    }

    function setMandate(uint256 seed, uint256 mandateSeed) external {
        uint256 tokenId = _pickToken(seed);
        if (!registry.accountExists(tokenId)) return;

        Mandate mandate = Mandate(bound(mandateSeed, 1, 4));
        vm.prank(_holder(tokenId));
        registry.setMandate(tokenId, mandate);
        countSetMandate += 1;
    }

    /// @notice Move a token between actors, creating the stale-state window the
    ///         registry's lazy transfer detection has to cope with.
    function transferToken(uint256 seed, uint256 toSeed) external {
        uint256 tokenId = _pickToken(seed);
        address from = _holder(tokenId);
        address to = actors[bound(toSeed, 0, actors.length - 1)];
        if (to == from || to == address(0)) return;

        vm.prank(from);
        nft.transferFrom(from, to, tokenId);
        countTransfer += 1;
    }

    /// @notice Force the lazy transfer sync to run, closing the stale window.
    /// @dev Any state-changing call syncs. Writing back the effective pause
    ///      state is the least intrusive way to trigger it.
    function syncAccount(uint256 seed) external {
        uint256 tokenId = _pickToken(seed);
        if (!registry.accountExists(tokenId)) return;
        if (!registry.isTransferPending(tokenId)) return;

        bool effective = registry.isAutomationPaused(tokenId);
        vm.prank(_holder(tokenId));
        registry.setAutomationPaused(tokenId, effective);
        countSync += 1;
    }

    // -----------------------------------------------------------------------
    // Twin actions — applied byte-identically to both twins
    // -----------------------------------------------------------------------

    /// @notice One operation, applied identically to the Guardian twin and the
    ///         Maverick twin.
    /// @dev A single entry point rather than four, so the fuzzer reaches every
    ///      twin operation often instead of spreading thinly across functions.
    ///      Sub-operation counters are tracked separately so coverage stays
    ///      visible per operation.
    function twinOperation(uint256 opSeed, uint256 rawAmount, uint256 mandateSeed) external {
        uint256 op = bound(opSeed, 0, 3);

        if (op == 0) {
            uint256 amount = bound(rawAmount, 1, 500_000e18);
            vm.prank(twinHolderGuardian);
            registry.deposit(twinGuardian, amount);
            vm.prank(twinHolderMaverick);
            registry.deposit(twinMaverick, amount);
            ghostDeposited[twinGuardian] += amount;
            ghostDeposited[twinMaverick] += amount;
            countTwinDeposit += 1;
        } else if (op == 1) {
            // Balances are equal by construction, so one bound serves both.
            uint256 balance = registry.getAccount(twinGuardian).balance;
            if (balance == 0) return;
            uint256 amount = bound(rawAmount, 1, balance);
            vm.prank(twinHolderGuardian);
            registry.withdraw(twinGuardian, amount);
            vm.prank(twinHolderMaverick);
            registry.withdraw(twinMaverick, amount);
            ghostWithdrawn[twinGuardian] += amount;
            ghostWithdrawn[twinMaverick] += amount;
            countTwinWithdraw += 1;
        } else if (op == 2) {
            Mandate mandate = Mandate(bound(mandateSeed, 1, 4));
            vm.prank(twinHolderGuardian);
            registry.setMandate(twinGuardian, mandate);
            vm.prank(twinHolderMaverick);
            registry.setMandate(twinMaverick, mandate);
            countTwinMandate += 1;
        } else {
            bool paused = (rawAmount % 2 == 0);
            vm.prank(twinHolderGuardian);
            registry.setAutomationPaused(twinGuardian, paused);
            vm.prank(twinHolderMaverick);
            registry.setAutomationPaused(twinMaverick, paused);
            countTwinPause += 1;
        }
    }
}
