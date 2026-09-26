// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Mandate, MandateParams} from "./Mandate.sol";
import {IAccountRegistry} from "./interfaces/IAccountRegistry.sol";

/// @notice Which direction a proposal trades in. `Unset` is never valid.
enum Side {
    Unset,
    Buy,
    Sell
}

/// @notice The entire surface an agent gets to express a trade.
///
/// @dev THIS IS THE ARCHITECTURAL CLAIM, encoded as a type. There is no field
///      here for a contract address to call, for calldata, for a recipient,
///      for an approval, or for an amount of anything real. An agent that
///      wanted to drain an account could not encode the attempt — not because
///      validation would catch it, but because the type cannot represent it.
///      By construction, not by checking.
struct TradeProposal {
    address asset;
    Side side;
    uint256 sizeUnits; // position size, simulated units, 18 decimals
    uint16 slippageBps; // max slippage the proposer will accept
    uint256 dataTimestamp; // when the market data behind this was observed
}

/// @notice Why a proposal was rejected. `None` means approved.
///
/// @dev DELIBERATE DEPARTURE from the zero-means-unset convention used
///      everywhere else in this codebase. Here zero means APPROVED.
///
///      That convention exists because uninitialised storage reads as zero, so
///      a zero value must never be mistakable for a real one. `validate` is
///      `view` and touches no storage, so there is no uninitialised slot to
///      confuse anything with — and the `approved` boolean carries the real
///      signal regardless. The inconsistency is considered, not careless.
///
///      The risk it does introduce is the two return values disagreeing, which
///      is closed by a fuzz test asserting
///      `approved == (reason == RejectReason.None)` rather than by enum
///      gymnastics.
enum RejectReason {
    None, // 0 — approved
    AccountDoesNotExist,
    AutomationPaused,
    MandateNotSet,
    InvalidSide,
    ZeroSize,
    StaleMarketData,
    AssetNotApproved,
    MaxPositionExceeded,
    MaxSlippageExceeded
}

/// @title RiskEngine
/// @notice The deterministic authority that approves or rejects a proposed
///         trade. The AI proposes; this decides.
///
/// @dev A PURE VIEW VALIDATOR. No storage writes, no access control, no pause,
///      no admin. Anyone may call it because calling it changes nothing.
///
///      That is the strongest guarantee available rather than the laziest
///      option: a validator with no mutable state cannot be corrupted, cannot
///      be paused by anyone, cannot drift, and cannot be gamed by reordering
///      calls. Who is permitted to *act on* an approval is a separate question
///      belonging to execution, which is not in this milestone. Approval is not
///      execution, and nothing here moves a balance.
///
///      `validate` NEVER REVERTS. It returns a reason instead. A revert tells
///      you something failed; a reason code tells you which rule stopped it —
///      which is what makes a rejection legible in a demo, recordable in the
///      performance registry later, and honest in the public record. The whole
///      product premise is that rejections are visible, not swallowed.
///
///      Nothing here reads an archetype. The engine cannot: it depends on
///      `IAccountRegistry`, which exposes none.
contract RiskEngine {
    /// @notice Maximum age of the market data behind a proposal, in seconds.
    ///
    /// @dev PROTOTYPE. Not audited, not tuned against anything.
    ///
    ///      LIMITATION, STATED PLAINLY: `dataTimestamp` is SELF-REPORTED by
    ///      whoever builds the proposal. This check catches a stale pipeline,
    ///      not a dishonest one — a proposer who lies about when data was
    ///      observed passes it trivially. It is a sanity check, NOT a security
    ///      control, and must never be described as one.
    ///
    ///      Real freshness guarantees need an oracle. `INTEGRATIONS.md` I5 is
    ///      still `MOCK` with an unverified feed, so that guarantee does not
    ///      exist yet. Saying so here is the difference between a documented
    ///      limitation and an implied one.
    uint256 public constant MAX_DATA_AGE = 300;

    /// @notice Basis-points denominator. 10000 bps = 100%.
    uint256 private constant BPS_DENOMINATOR = 10_000;

    /// @notice Thrown when a constructor argument is the zero address.
    error ZeroAddress();

    /// @notice Thrown when the approved-asset list is empty.
    error EmptyAssetList();

    /// @notice The account registry this engine validates against.
    IAccountRegistry public immutable registry;

    /// @dev Fixed at construction. There is deliberately NO SETTER: an asset
    ///      allowlist that anyone can change requires an admin, and this
    ///      project has shipped four contracts without one. Changing the list
    ///      means redeploying. For a prototype that is the right trade — it
    ///      keeps the no-privileged-roles property intact rather than
    ///      introducing the first exception here, in the most
    ///      security-sensitive contract in the system.
    mapping(address => bool) private _approvedAsset;

    /// @notice How many distinct assets are approved.
    uint256 public approvedAssetCount;

    /// @param registry_ The account registry to read state from.
    /// @param approvedAssets_ The fixed asset allowlist. Cannot be empty.
    constructor(IAccountRegistry registry_, address[] memory approvedAssets_) {
        if (address(registry_) == address(0)) {
            revert ZeroAddress();
        }
        if (approvedAssets_.length == 0) {
            revert EmptyAssetList();
        }

        registry = registry_;

        uint256 count = 0;
        for (uint256 i = 0; i < approvedAssets_.length; i++) {
            address asset = approvedAssets_[i];
            // Reverting inside the loop is correct here: this is a constructor
            // over the deployer's own argument, so there is no untrusted caller
            // and no partial-state concern — a revert abandons the whole
            // deployment.
            if (asset == address(0)) {
                // forge-lint: disable-next-line(require-revert-in-loop)
                revert ZeroAddress();
            }
            // Duplicates are tolerated but counted once, so the public count
            // describes distinct assets rather than argument length.
            if (!_approvedAsset[asset]) {
                _approvedAsset[asset] = true;
                count += 1;
            }
        }
        approvedAssetCount = count;
    }

    /// @notice Whether an asset may be traded. Fixed at deployment.
    function isApprovedAsset(address asset) external view returns (bool) {
        return _approvedAsset[asset];
    }

    /// @notice Decide whether a proposal is permitted.
    /// @return approved True only when every check passes.
    /// @return reason `None` when approved, otherwise the first rule that
    ///         stopped it.
    ///
    /// @dev Checks short-circuit in a fixed order. Two orderings are
    ///      load-bearing rather than arbitrary:
    ///
    ///      - `accountExists` runs FIRST because `getAccount`, `mandateOf` and
    ///        `mandateParamsOf` all revert for a nonexistent account, and this
    ///        function must never revert.
    ///      - The mandate check runs BEFORE `mandateParamsOf`, which reverts
    ///        `InvalidMandate(0)` when the mandate is `Unset`.
    ///
    ///      And one ordering is a product decision: THE PAUSE CHECK COMES
    ///      SECOND, before anything about the trade itself. A proposal that is
    ///      valid in every respect must still be rejected the instant the
    ///      holder has stopped automation, and rejected FOR THAT REASON rather
    ///      than for some incidental one. The holder's instruction outranks
    ///      every property of the trade.
    function validate(uint256 tokenId, TradeProposal calldata proposal)
        external
        view
        returns (bool approved, RejectReason reason)
    {
        reason = _evaluate(tokenId, proposal);
        // SINGLE EXIT POINT, deliberately. `approved` is DERIVED from `reason`
        // rather than returned alongside it, so the two cannot disagree — the
        // invariant `approved == (reason == None)` holds by construction, not by
        // discipline. The fuzz test asserting it therefore guards against a
        // future refactor reintroducing two independent returns, rather than
        // against a mistake that is currently possible.
        approved = (reason == RejectReason.None);
    }

    /// @dev Returns the first rule that stops the proposal, or `None`.
    ///
    ///      Two orderings are load-bearing rather than arbitrary:
    ///
    ///      - `accountExists` runs FIRST because `getAccount`, `mandateOf` and
    ///        `mandateParamsOf` all revert for a nonexistent account, and
    ///        `validate` must never revert.
    ///      - The mandate check runs BEFORE `mandateParamsOf`, which reverts
    ///        `InvalidMandate(0)` when the mandate is `Unset`.
    ///
    ///      And one ordering is a product decision: THE PAUSE CHECK COMES
    ///      SECOND, before anything about the trade itself. A proposal valid in
    ///      every respect must still be rejected the instant the holder has
    ///      stopped automation, and rejected FOR THAT REASON rather than for
    ///      some incidental one. The holder's instruction outranks every
    ///      property of the trade.
    function _evaluate(uint256 tokenId, TradeProposal calldata proposal)
        private
        view
        returns (RejectReason)
    {
        // 1. Account must exist before anything else can be read.
        if (!registry.accountExists(tokenId)) {
            return RejectReason.AccountDoesNotExist;
        }

        // 2. The holder's kill switch outranks everything about the trade.
        //    Reads EFFECTIVE state, so a pending transfer lands here too — a
        //    sold account is never validated against the seller's appetite.
        if (registry.isAutomationPaused(tokenId)) {
            return RejectReason.AutomationPaused;
        }

        // 3. No mandate means no limits to check against. Must precede
        //    mandateParamsOf, which reverts on Unset.
        if (registry.mandateOf(tokenId) == Mandate.Unset) {
            return RejectReason.MandateNotSet;
        }

        // 4-5. The proposal must be well-formed.
        if (proposal.side == Side.Unset) {
            return RejectReason.InvalidSide;
        }
        if (proposal.sizeUnits == 0) {
            return RejectReason.ZeroSize;
        }

        // 6. Freshness. A future timestamp is malformed, not merely stale.
        //    block.timestamp is inherent to a freshness check; the limitation
        //    that dataTimestamp is self-reported is documented on MAX_DATA_AGE
        //    and matters far more than validator timestamp drift.
        // forge-lint: disable-next-line(block-timestamp)
        if (proposal.dataTimestamp > block.timestamp) {
            return RejectReason.StaleMarketData;
        }
        // forge-lint: disable-next-line(block-timestamp)
        if (block.timestamp - proposal.dataTimestamp > MAX_DATA_AGE) {
            return RejectReason.StaleMarketData;
        }

        // 7. Asset allowlist.
        if (!_approvedAsset[proposal.asset]) {
            return RejectReason.AssetNotApproved;
        }

        MandateParams memory params = registry.mandateParamsOf(tokenId);

        // 8. Position cap, as basis points of the current balance.
        //    Math.mulDiv rather than `balance * bps / 10000`: the product can
        //    overflow for an absurdly large balance, and an overflow would
        //    REVERT — which this function must never do. mulDiv computes the
        //    same value in full width, and the result can never exceed
        //    `balance` because maxPositionBps <= 10000.
        uint256 maxPositionUnits = Math.mulDiv(
            registry.getAccount(tokenId).balance, params.maxPositionBps, BPS_DENOMINATOR
        );
        if (proposal.sizeUnits > maxPositionUnits) {
            return RejectReason.MaxPositionExceeded;
        }

        // 9. Slippage cap.
        if (proposal.slippageBps > params.maxSlippageBps) {
            return RejectReason.MaxSlippageExceeded;
        }

        // TODO(positions): `params.maxOpenPositions` is specified but NOT
        // enforced. Enforcing it needs open-position tracking, which does not
        // exist — there is no record of what an account currently holds. Left
        // unenforced and openly marked rather than faked, because a parameter
        // that looks enforced and is not is worse than one marked pending.
        // See DECISIONS.md.

        // TODO(drawdown): `params.maxDailyDrawdownBps` is specified but NOT
        // enforced. Enforcing it needs PnL history with daily boundaries, and
        // the registry stores only a point-in-time balance with derived PnL.
        // Same reasoning as above.

        return RejectReason.None;
    }
}
