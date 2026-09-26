// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {RiskEngine, TradeProposal, Side, RejectReason} from "../src/RiskEngine.sol";
import {IAccountRegistry} from "../src/interfaces/IAccountRegistry.sol";
import {Mandate, MandateLib, MandateParams} from "../src/Mandate.sol";

/// @title MockAccountRegistry
/// @notice Minimal `IAccountRegistry` for engine tests.
/// @dev Mirrors the real registry's semantics in the two ways the engine
///      depends on: the reverting views revert for a missing account, and
///      `isAutomationPaused` / `mandateOf` return EFFECTIVE state with pending
///      transfers applied. Getting either wrong here would let an engine bug
///      pass.
contract MockAccountRegistry is IAccountRegistry {
    error NoAccount(uint256 tokenId);

    mapping(uint256 => Account) private _accounts;
    mapping(uint256 => bool) private _transferPending;

    function create(uint256 tokenId, uint256 balance, Mandate mandate, bool paused) external {
        Account storage a = _accounts[tokenId];
        a.exists = true;
        a.lastKnownOwner = address(this);
        a.depositedTotal = balance;
        a.balance = balance;
        a.automationPaused = paused;
        a.ownerPeriod = 1;
        a.mandate = mandate;
    }

    function setPaused(uint256 tokenId, bool paused) external {
        _accounts[tokenId].automationPaused = paused;
    }

    function setMandate(uint256 tokenId, Mandate mandate) external {
        _accounts[tokenId].mandate = mandate;
    }

    function setBalance(uint256 tokenId, uint256 balance) external {
        _accounts[tokenId].balance = balance;
    }

    function setTransferPending(uint256 tokenId, bool pending) external {
        _transferPending[tokenId] = pending;
    }

    function _effective(uint256 tokenId) private view returns (Account memory a) {
        a = _accounts[tokenId];
        if (_transferPending[tokenId]) {
            a.automationPaused = true;
            a.mandate = Mandate.Unset;
        }
    }

    function accountExists(uint256 tokenId) external view returns (bool) {
        return _accounts[tokenId].exists;
    }

    function getAccount(uint256 tokenId) external view returns (Account memory) {
        if (!_accounts[tokenId].exists) revert NoAccount(tokenId);
        return _effective(tokenId);
    }

    function isAutomationPaused(uint256 tokenId) external view returns (bool) {
        return _effective(tokenId).automationPaused;
    }

    function mandateOf(uint256 tokenId) external view returns (Mandate) {
        if (!_accounts[tokenId].exists) revert NoAccount(tokenId);
        return _effective(tokenId).mandate;
    }

    function mandateParamsOf(uint256 tokenId) external view returns (MandateParams memory) {
        if (!_accounts[tokenId].exists) revert NoAccount(tokenId);
        return MandateLib.paramsOf(_effective(tokenId).mandate);
    }
}

/// @title RiskEngineTest
/// @dev Invariant ids refer to docs/specs/RiskEngine.md.
contract RiskEngineTest is Test {
    MockAccountRegistry internal registry;
    RiskEngine internal engine;

    // Test fixtures, NOT real token addresses. Named neutrally on purpose:
    // calling an invented address `ASSET_A` would imply a verified mainnet
    // address, and this repo does not fabricate those (rule 2).
    address internal constant ASSET_A = address(0x1000000000000000000000000000000000000001);
    address internal constant ASSET_B = address(0x1000000000000000000000000000000000000002);
    address internal constant UNLISTED_ASSET = address(0x1000000000000000000000000000000000000003);

    uint256 internal constant TOKEN = 1;
    uint256 internal constant BALANCE = 10_000e18;

    function setUp() public {
        // Far enough past zero that data can be MAX_DATA_AGE old without
        // underflowing.
        vm.warp(1_000_000);

        registry = new MockAccountRegistry();
        address[] memory assets = new address[](2);
        assets[0] = ASSET_A;
        assets[1] = ASSET_B;
        engine = new RiskEngine(IAccountRegistry(address(registry)), assets);

        registry.create(TOKEN, BALANCE, Mandate.Preservation, false);
    }

    /// @dev A proposal that passes every check under Preservation.
    ///      500 units against a 10,000 balance, well under the 1,000 cap.
    function _validProposal() internal view returns (TradeProposal memory) {
        return TradeProposal({
            asset: ASSET_A,
            side: Side.Buy,
            sizeUnits: 500e18,
            slippageBps: 25,
            dataTimestamp: block.timestamp
        });
    }

    function _assert(
        TradeProposal memory p,
        bool wantApproved,
        RejectReason wantReason,
        string memory what
    ) internal view {
        (bool approved, RejectReason reason) = engine.validate(TOKEN, p);
        assertEq(approved, wantApproved, string.concat(what, ": approved"));
        assertEq(uint8(reason), uint8(wantReason), string.concat(what, ": reason"));
    }

    // ------------------------------------------------------------- approval

    /// WHAT: A fully valid proposal under Preservation is approved, reason None.
    /// WHY: If the happy path fails, nothing can ever trade and the product
    ///      does nothing.
    /// FAILURE MEANS: Every proposal is rejected.
    function test_ValidProposalIsApproved() public view {
        _assert(_validProposal(), true, RejectReason.None, "valid");
    }

    /// WHAT: A proposal exactly at the position cap is approved.
    /// WHY: The cap is inclusive. An off-by-one here silently narrows every
    ///      mandate by one unit.
    /// FAILURE MEANS: The documented limit is not the enforced limit.
    function test_ProposalExactlyAtPositionCapIsApproved() public view {
        TradeProposal memory p = _validProposal();
        p.sizeUnits = 1000e18; // 1000 bps of 10,000
        _assert(p, true, RejectReason.None, "at position cap");
    }

    /// WHAT: A proposal exactly at the slippage cap is approved.
    /// WHY: Same inclusivity question on the other boundary.
    /// FAILURE MEANS: The documented slippage tolerance is off by one bp.
    function test_ProposalExactlyAtSlippageCapIsApproved() public view {
        TradeProposal memory p = _validProposal();
        p.slippageBps = 50; // Preservation's cap
        _assert(p, true, RejectReason.None, "at slippage cap");
    }

    /// WHAT: Each of the four mandates approves a proposal sized for it.
    /// WHY: The engine must read the selected mandate's parameters, not a
    ///      hardcoded set.
    /// FAILURE MEANS: Limits do not track the holder's choice.
    function test_EachMandateApprovesCorrectlySizedProposal() public {
        Mandate[4] memory mandates =
            [Mandate.Preservation, Mandate.Balanced, Mandate.Tactical, Mandate.Speculative];
        uint256[4] memory caps = [uint256(1000e18), 2000e18, 3500e18, 5000e18];
        uint16[4] memory slippages = [uint16(50), 100, 200, 300];
        // Labels as literals rather than MandateLib.name(): that function is
        // `internal`, so calling it here would inline its revert INTO this
        // loop, which trips the require-revert-in-loop lint against
        // Mandate.sol — a warning caused by the test, not by the library.
        string[4] memory labels = ["Preservation", "Balanced", "Tactical", "Speculative"];

        for (uint256 i = 0; i < 4; i++) {
            registry.setMandate(TOKEN, mandates[i]);
            TradeProposal memory p = _validProposal();
            p.sizeUnits = caps[i];
            p.slippageBps = slippages[i];
            _assert(p, true, RejectReason.None, labels[i]);
        }
    }

    // ---------------------------------------------------- rejection reasons

    /// WHAT: An account that does not exist is rejected by name.
    /// WHY: Must be checked first — every other registry view reverts for a
    ///      missing account, and validate must never revert.
    /// FAILURE MEANS: validate reverts instead of answering.
    function test_RejectsAccountDoesNotExist() public view {
        (bool approved, RejectReason reason) = engine.validate(999, _validProposal());
        assertFalse(approved, "approved a nonexistent account");
        assertEq(uint8(reason), uint8(RejectReason.AccountDoesNotExist), "reason");
    }

    /// WHAT: A paused account is rejected with AutomationPaused.
    /// WHY: The kill switch is the holder's, requires nobody's approval, and
    ///      must be honoured immediately.
    /// FAILURE MEANS: Automation keeps running after the holder stopped it.
    ///      Invariant 3.
    function test_RejectsAutomationPaused() public {
        registry.setPaused(TOKEN, true);
        _assert(_validProposal(), false, RejectReason.AutomationPaused, "paused");
    }

    /// WHAT: An account with no mandate is rejected with MandateNotSet.
    /// WHY: No mandate means no limits to validate against. Defaulting to any
    ///      mandate would impose a risk level the holder never chose.
    /// FAILURE MEANS: Trades run under limits nobody selected. Invariant 4.
    function test_RejectsMandateNotSet() public {
        registry.setMandate(TOKEN, Mandate.Unset);
        _assert(_validProposal(), false, RejectReason.MandateNotSet, "no mandate");
    }

    /// WHAT: Side.Unset is rejected with InvalidSide.
    /// WHY: Zero-means-unset applies to the proposal type too; an unset side is
    ///      a malformed proposal, not a buy.
    /// FAILURE MEANS: A malformed proposal is treated as a valid direction.
    function test_RejectsInvalidSide() public view {
        TradeProposal memory p = _validProposal();
        p.side = Side.Unset;
        _assert(p, false, RejectReason.InvalidSide, "unset side");
    }

    /// WHAT: A zero-size proposal is rejected with ZeroSize.
    /// WHY: A zero-size trade is always a mistake and should fail by name
    ///      rather than be approved as a no-op.
    /// FAILURE MEANS: Meaningless proposals get approved and recorded.
    function test_RejectsZeroSize() public view {
        TradeProposal memory p = _validProposal();
        p.sizeUnits = 0;
        _assert(p, false, RejectReason.ZeroSize, "zero size");
    }

    /// WHAT: Market data older than MAX_DATA_AGE is rejected.
    /// WHY: Acting on stale data is acting on a price that no longer exists.
    /// FAILURE MEANS: Trades are validated against prices from any point in
    ///      the past.
    function test_RejectsStaleMarketData() public view {
        TradeProposal memory p = _validProposal();
        p.dataTimestamp = block.timestamp - (engine.MAX_DATA_AGE() + 1);
        _assert(p, false, RejectReason.StaleMarketData, "stale");
    }

    /// WHAT: An asset not on the allowlist is rejected.
    /// WHY: The allowlist is fixed at deployment and is the only set of assets
    ///      this engine will ever permit.
    /// FAILURE MEANS: Arbitrary assets become tradeable. Invariant 6.
    function test_RejectsAssetNotApproved() public view {
        TradeProposal memory p = _validProposal();
        p.asset = UNLISTED_ASSET;
        _assert(p, false, RejectReason.AssetNotApproved, "unapproved asset");
    }

    /// WHAT: A position above the mandate's cap is rejected.
    /// WHY: This is the core sizing limit the mandate exists to express.
    /// FAILURE MEANS: Position sizing is unbounded.
    function test_RejectsMaxPositionExceeded() public view {
        TradeProposal memory p = _validProposal();
        p.sizeUnits = 2000e18; // twice Preservation's 1,000 cap
        _assert(p, false, RejectReason.MaxPositionExceeded, "oversized");
    }

    /// WHAT: Slippage above the mandate's cap is rejected.
    /// WHY: Accepting unlimited slippage makes the fill price meaningless.
    /// FAILURE MEANS: A strategy can accept any price and still look compliant.
    function test_RejectsMaxSlippageExceeded() public view {
        TradeProposal memory p = _validProposal();
        p.slippageBps = 51; // one bp over Preservation
        _assert(p, false, RejectReason.MaxSlippageExceeded, "slippage");
    }

    // ------------------------------------------------------------- ordering

    /// WHAT: A paused account with an oversized, unapproved-asset, stale
    ///       proposal returns AutomationPaused — not any of the others.
    /// WHY: The holder's instruction outranks every property of the trade. If
    ///      a different reason surfaced, the demo would show the kill switch
    ///      being incidental rather than absolute.
    /// FAILURE MEANS: The kill switch reads as one rule among many.
    function test_PauseOutranksEveryOtherFailure() public {
        registry.setPaused(TOKEN, true);
        TradeProposal memory p = TradeProposal({
            asset: UNLISTED_ASSET,
            side: Side.Unset,
            sizeUnits: 999_999e18,
            slippageBps: 10_000,
            dataTimestamp: 1
        });
        _assert(p, false, RejectReason.AutomationPaused, "pause outranks all");
    }

    /// WHAT: No mandate plus an oversized proposal returns MandateNotSet.
    /// WHY: Reporting MaxPositionExceeded would imply limits were checked, when
    ///      there are none to check. It would also mean mandateParamsOf had
    ///      been called on Unset, which reverts.
    /// FAILURE MEANS: A misleading reason, or a revert instead of an answer.
    function test_MandateNotSetOutranksPositionCap() public {
        registry.setMandate(TOKEN, Mandate.Unset);
        TradeProposal memory p = _validProposal();
        p.sizeUnits = 999_999e18;
        _assert(p, false, RejectReason.MandateNotSet, "mandate outranks cap");
    }

    // ----------------------------------------------------------- the demo arc

    /// WHAT: Approved, then the holder pauses and THE IDENTICAL PROPOSAL is
    ///       rejected AutomationPaused, then unpaused and approved again.
    /// WHY: This is the product claim in one assertion. Nothing about the trade
    ///      changes across the three calls — only the holder's instruction.
    ///      The agent cannot reach the switch that stopped it.
    /// FAILURE MEANS: The central demonstration does not hold, and the
    ///      architectural claim is unsupported.
    function test_DemoArc_ApprovePauseRejectUnpauseApprove() public {
        TradeProposal memory proposal = _validProposal();

        _assert(proposal, true, RejectReason.None, "beat 1: approved");

        registry.setPaused(TOKEN, true);
        _assert(proposal, false, RejectReason.AutomationPaused, "beat 2: same proposal rejected");

        registry.setPaused(TOKEN, false);
        _assert(proposal, true, RejectReason.None, "beat 3: approved again");
    }

    // -------------------------------------------------------------- transfer

    /// WHAT: After transfer and before sync, a previously valid proposal is
    ///       rejected AutomationPaused.
    /// WHY: The registry's fail-safe read reaches the engine. A sold account
    ///      must not be validated against the seller's risk appetite during
    ///      the window before anyone interacts.
    /// FAILURE MEANS: The buyer's account trades on the seller's settings.
    ///      Invariant 5.
    function test_PendingTransferRejectsAsAutomationPaused() public {
        _assert(_validProposal(), true, RejectReason.None, "precondition: approved");

        registry.setTransferPending(TOKEN, true);

        _assert(_validProposal(), false, RejectReason.AutomationPaused, "pending transfer");
    }

    /// WHAT: After the new holder syncs and picks their own mandate, validation
    ///       uses THEIR limits.
    /// WHY: A buyer choosing Speculative should be able to size to Speculative,
    ///      not remain capped at the seller's Preservation.
    /// FAILURE MEANS: Risk limits outlive the holder who chose them.
    function test_AfterSyncNewHolderLimitsApply() public {
        // 3,000 units exceeds Preservation's 1,000 cap.
        TradeProposal memory p = _validProposal();
        p.sizeUnits = 3000e18;
        p.slippageBps = 300;
        _assert(p, false, RejectReason.MaxPositionExceeded, "seller's cap applies");

        // Transfer, then the new holder syncs and chooses Speculative.
        registry.setTransferPending(TOKEN, true);
        registry.setTransferPending(TOKEN, false);
        registry.setMandate(TOKEN, Mandate.Speculative);
        registry.setPaused(TOKEN, false);

        _assert(p, true, RejectReason.None, "buyer's own cap applies");
    }

    // ------------------------------------------------------------ boundaries

    /// WHAT: One unit above the position cap is rejected.
    /// WHY: Pins the boundary exactly rather than approximately.
    /// FAILURE MEANS: The cap is not where it is documented to be.
    function test_OneUnitAbovePositionCapIsRejected() public view {
        TradeProposal memory p = _validProposal();
        p.sizeUnits = 1000e18 + 1;
        _assert(p, false, RejectReason.MaxPositionExceeded, "cap + 1 wei");
    }

    /// WHAT: One bp above the slippage cap is rejected.
    /// WHY: Same, on the slippage boundary.
    /// FAILURE MEANS: Slippage tolerance is wider than documented.
    function test_OneBpAboveSlippageCapIsRejected() public view {
        TradeProposal memory p = _validProposal();
        p.slippageBps = 51;
        _assert(p, false, RejectReason.MaxSlippageExceeded, "cap + 1 bp");
    }

    /// WHAT: Data exactly MAX_DATA_AGE old is accepted; one second older is not.
    /// WHY: Freshness is inclusive at the boundary, and the boundary must be
    ///      exact rather than roughly right.
    /// FAILURE MEANS: The freshness window is not the documented 300 seconds.
    function test_DataExactlyAtMaxAgeAcceptedOneSecondOlderRejected() public view {
        uint256 maxAge = engine.MAX_DATA_AGE();

        TradeProposal memory atLimit = _validProposal();
        atLimit.dataTimestamp = block.timestamp - maxAge;
        _assert(atLimit, true, RejectReason.None, "exactly at max age");

        TradeProposal memory tooOld = _validProposal();
        tooOld.dataTimestamp = block.timestamp - maxAge - 1;
        _assert(tooOld, false, RejectReason.StaleMarketData, "one second older");
    }

    /// WHAT: A future dataTimestamp is rejected.
    /// WHY: Data observed in the future is malformed, and without this check
    ///      the age subtraction would underflow and revert.
    /// FAILURE MEANS: validate reverts on a malformed proposal instead of
    ///      returning a reason.
    function test_FutureDataTimestampIsRejected() public view {
        TradeProposal memory p = _validProposal();
        p.dataTimestamp = block.timestamp + 1;
        _assert(p, false, RejectReason.StaleMarketData, "future timestamp");
    }

    // ------------------------------------------------------ constructor guards

    /// WHAT: A zero registry address is rejected at construction.
    /// WHY: Every validation path would revert against a zero registry,
    ///      producing an engine that approves nothing and looks deployed.
    /// FAILURE MEANS: A bricked engine deploys successfully.
    function test_ConstructorRejectsZeroRegistry() public {
        address[] memory assets = new address[](1);
        assets[0] = ASSET_A;
        vm.expectRevert(RiskEngine.ZeroAddress.selector);
        new RiskEngine(IAccountRegistry(address(0)), assets);
    }

    /// WHAT: An empty asset list is rejected at construction.
    /// WHY: With no approved assets the engine can never approve anything, and
    ///      the list has no setter to fix it afterwards.
    /// FAILURE MEANS: An engine that rejects everything forever deploys
    ///      successfully.
    function test_ConstructorRejectsEmptyAssetList() public {
        address[] memory empty = new address[](0);
        vm.expectRevert(RiskEngine.EmptyAssetList.selector);
        new RiskEngine(IAccountRegistry(address(registry)), empty);
    }

    /// WHAT: A zero address inside the asset list is rejected.
    /// WHY: address(0) is not an asset; approving it would be a permanent
    ///      nonsense entry in an unchangeable list.
    /// FAILURE MEANS: The fixed allowlist contains a meaningless entry forever.
    function test_ConstructorRejectsZeroAssetAddress() public {
        address[] memory assets = new address[](2);
        assets[0] = ASSET_A;
        assets[1] = address(0);
        vm.expectRevert(RiskEngine.ZeroAddress.selector);
        new RiskEngine(IAccountRegistry(address(registry)), assets);
    }

    /// WHAT: The allowlist is inspectable and counts distinct assets.
    /// WHY: A fixed list must be publicly checkable, and a duplicated argument
    ///      should not inflate the count.
    /// FAILURE MEANS: The published count misdescribes what is approved.
    function test_AllowlistIsInspectableAndCountsDistinct() public {
        assertTrue(engine.isApprovedAsset(ASSET_A), "ASSET_A should be approved");
        assertTrue(engine.isApprovedAsset(ASSET_B), "ASSET_B should be approved");
        assertFalse(engine.isApprovedAsset(UNLISTED_ASSET), "BAD should not be");
        assertEq(engine.approvedAssetCount(), 2, "count");

        address[] memory dupes = new address[](3);
        dupes[0] = ASSET_A;
        dupes[1] = ASSET_A;
        dupes[2] = ASSET_B;
        RiskEngine e2 = new RiskEngine(IAccountRegistry(address(registry)), dupes);
        assertEq(e2.approvedAssetCount(), 2, "duplicates should count once");
    }

    // ------------------------------------------------------------------ fuzz

    /// WHAT: A paused account is never approved, whatever the proposal says.
    /// WHY: Invariant 3 is the product claim, so it is fuzzed across every
    ///      field rather than checked in one case.
    /// FAILURE MEANS: Some proposal shape slips past a holder's kill switch.
    function testFuzz_PausedNeverApproves(
        address asset,
        uint8 rawSide,
        uint256 sizeUnits,
        uint16 slippageBps,
        uint256 dataTimestamp
    ) public {
        registry.setPaused(TOKEN, true);

        TradeProposal memory p = TradeProposal({
            asset: asset,
            side: Side(bound(uint256(rawSide), 0, 2)),
            sizeUnits: sizeUnits,
            slippageBps: slippageBps,
            dataTimestamp: dataTimestamp
        });

        (bool approved, RejectReason reason) = engine.validate(TOKEN, p);
        assertFalse(approved, "approved while paused");
        assertEq(uint8(reason), uint8(RejectReason.AutomationPaused), "wrong reason while paused");
    }

    /// WHAT: approved is always exactly (reason == None).
    /// WHY: Two return values that can disagree are a trap for every caller.
    ///      The implementation derives one from the other, so this guards
    ///      against a refactor reintroducing independent returns.
    /// FAILURE MEANS: A caller trusting `approved` and a caller trusting
    ///      `reason` reach different conclusions. Invariant 2.
    function testFuzz_ApprovedMatchesReasonNone(
        address asset,
        uint8 rawSide,
        uint256 sizeUnits,
        uint16 slippageBps,
        uint256 dataTimestamp,
        uint8 rawMandate,
        bool paused
    ) public {
        registry.setMandate(TOKEN, Mandate(bound(uint256(rawMandate), 0, 4)));
        registry.setPaused(TOKEN, paused);

        TradeProposal memory p = TradeProposal({
            asset: asset,
            side: Side(bound(uint256(rawSide), 0, 2)),
            sizeUnits: sizeUnits,
            slippageBps: slippageBps,
            dataTimestamp: dataTimestamp
        });

        (bool approved, RejectReason reason) = engine.validate(TOKEN, p);
        assertEq(approved, reason == RejectReason.None, "approved disagrees with reason");
    }

    /// WHAT: A size exceeding the balance is never approved, for any mandate.
    /// WHY: The largest maxPositionBps is 5000, so no mandate permits a
    ///      position above half the balance. A size above the whole balance
    ///      must therefore always fail.
    /// FAILURE MEANS: An account can take a position larger than it holds.
    ///      Invariant 7.
    function testFuzz_SizeExceedingBalanceNeverApproved(uint8 rawMandate, uint256 excess) public {
        registry.setMandate(TOKEN, Mandate(bound(uint256(rawMandate), 1, 4)));
        uint256 size = BALANCE + bound(excess, 1, type(uint256).max - BALANCE);

        TradeProposal memory p = _validProposal();
        p.sizeUnits = size;

        (bool approved, RejectReason reason) = engine.validate(TOKEN, p);
        assertFalse(approved, "approved a position larger than the balance");
        assertEq(uint8(reason), uint8(RejectReason.MaxPositionExceeded), "reason");
    }

    /// WHAT: Two identical calls return identical results.
    /// WHY: The engine must be deterministic — no dependence on caller, call
    ///      count, or ordering. A validator that answers differently on a
    ///      second ask cannot be reasoned about.
    /// FAILURE MEANS: Hidden state or caller dependence. Invariant 10.
    function testFuzz_IdenticalCallsReturnIdenticalResults(
        address asset,
        uint8 rawSide,
        uint256 sizeUnits,
        uint16 slippageBps,
        uint256 dataTimestamp,
        address caller
    ) public {
        TradeProposal memory p = TradeProposal({
            asset: asset,
            side: Side(bound(uint256(rawSide), 0, 2)),
            sizeUnits: sizeUnits,
            slippageBps: slippageBps,
            dataTimestamp: dataTimestamp
        });

        (bool a1, RejectReason r1) = engine.validate(TOKEN, p);
        vm.prank(caller);
        (bool a2, RejectReason r2) = engine.validate(TOKEN, p);

        assertEq(a1, a2, "approved differed between identical calls");
        assertEq(uint8(r1), uint8(r2), "reason differed between identical calls");
    }
}
