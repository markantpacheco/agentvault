// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {GenesisAgent} from "../src/GenesisAgent.sol";
import {AccountRegistry} from "../src/AccountRegistry.sol";
import {Mandate, MandateParams} from "../src/Mandate.sol";
import {RiskEngine, TradeProposal, Side, RejectReason} from "../src/RiskEngine.sol";

/// @title LiveDemo
/// @notice The six-beat arc against the DEPLOYED contracts, using an existing
///         token's existing account.
///
/// @dev Unlike `Demo.s.sol`, which deploys its own throwaway instances, this
///      runs against live state. Most beats are `validate()` VIEW calls and cost
///      nothing at all — only the kill switch is a transaction.
///
///      Transactions this sends: one `setAutomationPaused(false)` IF automation
///      is already paused when it starts (so the arc is re-runnable), and one
///      `setAutomationPaused(true)` at beat 6. At most two. Every other beat is
///      a read.
///
///      It leaves automation PAUSED, which is the honest end state of the story
///      it tells. Re-running unpauses first, so the arc works repeatedly.
///
///      Only the current holder can toggle the switch, so `--sender` must be
///      the token's holder.
///
///      TESTNET ONLY.
contract LiveDemo is Script {
    uint256 constant ROBINHOOD_MAINNET_CHAIN_ID = 4663;
    uint256 constant UNIT = 1e18;

    error MainnetNotPermitted(uint256 chainId);

    function run() external {
        if (block.chainid == ROBINHOOD_MAINNET_CHAIN_ID) {
            revert MainnetNotPermitted(block.chainid);
        }

        GenesisAgent nft = GenesisAgent(vm.envAddress("GENESIS_AGENT"));
        AccountRegistry registry = AccountRegistry(vm.envAddress("ACCOUNT_REGISTRY"));
        RiskEngine engine = RiskEngine(vm.envAddress("RISK_ENGINE"));
        uint256 tokenId = vm.envUint("DEMO_TOKEN_ID");
        address asset = vm.envAddress("DEMO_ASSET");

        require(
            address(engine.registry()) == address(registry), "engine points at another registry"
        );

        _rule();
        console.log("AgentVault - LIVE on Robinhood Chain testnet");
        console.log("chainId", block.chainid);
        _rule();

        // ---- 1. The NFT (read) ----
        console.log("1. GENESIS AGENT");
        console.log("   token id          ", tokenId);
        console.log("   holder            ", nft.ownerOf(tokenId));
        console.log("   archetype         ", nft.archetypeNameOf(tokenId));
        console.log("   (permanent identity - never a risk limit)");
        console.log("");

        // ---- 2. The account (read) ----
        AccountRegistry.Account memory account = registry.getAccount(tokenId);
        console.log("2. ACCOUNT");
        console.log("   balance (units)   ", account.balance / UNIT);
        console.log("   deposited (units) ", account.depositedTotal / UNIT);
        console.log("   withdrawn (units) ", account.withdrawnTotal / UNIT);
        console.log("   profit and loss   ", registry.pnlOf(tokenId));
        console.log("   owner period      ", account.ownerPeriod);
        console.log("");

        // ---- 3. The mandate (read) ----
        MandateParams memory params = registry.mandateParamsOf(tokenId);
        uint256 positionCap = (account.balance * params.maxPositionBps) / 10_000;
        console.log("3. MANDATE");
        console.log("   max position (bps)", params.maxPositionBps);
        console.log("   = cap (units)     ", positionCap / UNIT);
        console.log("   max slippage (bps)", params.maxSlippageBps);
        console.log("");

        vm.startBroadcast();

        // Ensure the arc starts from a running account. A transaction only if
        // needed, which keeps the demo re-runnable.
        if (registry.isAutomationPaused(tokenId)) {
            console.log("   (automation was paused - starting it so the arc can run)");
            console.log("");
            registry.setAutomationPaused(tokenId, false);
        }

        // ---- 4. A valid proposal (read) ----
        uint256 validSize = positionCap / 2; // comfortably inside the cap
        TradeProposal memory valid = TradeProposal({
            asset: asset,
            side: Side.Buy,
            sizeUnits: validSize,
            slippageBps: params.maxSlippageBps / 2,
            dataTimestamp: block.timestamp
        });
        _report(engine, tokenId, valid, "4. PROPOSE - inside every limit");

        // ---- 5. An oversized proposal (read) ----
        // EXPLICIT field-by-field copy. `TradeProposal memory x = valid;` would
        // alias the same memory struct, so mutating it would also change
        // `valid` — and beat 6 would then print the oversized size, which is
        // precisely the number the whole demo depends on being unchanged.
        TradeProposal memory oversized = TradeProposal({
            asset: valid.asset,
            side: valid.side,
            sizeUnits: positionCap * 2,
            slippageBps: valid.slippageBps,
            dataTimestamp: valid.dataTimestamp
        });
        _report(engine, tokenId, oversized, "5. PROPOSE - over the position cap");

        // ---- 6. The kill switch, then beat 4's EXACT proposal (1 tx + read) ----
        registry.setAutomationPaused(tokenId, true);
        console.log("   >> holder flips the kill switch (one transaction) <<");
        console.log("");
        _report(engine, tokenId, valid, "6. RESUBMIT BEAT 4's PROPOSAL, UNCHANGED");

        vm.stopBroadcast();

        _rule();
        console.log("Beats 4 and 6 sent the identical proposal.");
        console.log("Only the holder's instruction changed in between,");
        console.log("and the agent has no way to reach that switch.");
        _rule();
    }

    /// @dev Prints the verdict with the reason as a NAME. "REJECTED:
    ///      MaxPositionExceeded" reads; "reason: 8" does not.
    function _report(
        RiskEngine engine,
        uint256 tokenId,
        TradeProposal memory proposal,
        string memory heading
    ) private view {
        (bool approved, RejectReason reason) = engine.validate(tokenId, proposal);
        console.log(heading);
        console.log("   size (units)      ", proposal.sizeUnits / UNIT);
        console.log("   slippage (bps)    ", proposal.slippageBps);
        if (approved) {
            console.log("   >> APPROVED");
        } else {
            console.log(string.concat("   >> REJECTED: ", _reasonName(reason)));
        }
        console.log("");
    }

    function _reasonName(RejectReason reason) private pure returns (string memory) {
        if (reason == RejectReason.None) return "None";
        if (reason == RejectReason.AccountDoesNotExist) return "AccountDoesNotExist";
        if (reason == RejectReason.AutomationPaused) return "AutomationPaused";
        if (reason == RejectReason.MandateNotSet) return "MandateNotSet";
        if (reason == RejectReason.InvalidSide) return "InvalidSide";
        if (reason == RejectReason.ZeroSize) return "ZeroSize";
        if (reason == RejectReason.StaleMarketData) return "StaleMarketData";
        if (reason == RejectReason.AssetNotApproved) return "AssetNotApproved";
        if (reason == RejectReason.MaxPositionExceeded) return "MaxPositionExceeded";
        return "MaxSlippageExceeded";
    }

    function _rule() private pure {
        console.log("----------------------------------------------------------");
    }
}
