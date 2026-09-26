// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {GenesisAgent} from "../src/GenesisAgent.sol";
import {AccountRegistry} from "../src/AccountRegistry.sol";
import {IAccountRegistry} from "../src/interfaces/IAccountRegistry.sol";
import {Archetype} from "../src/Archetype.sol";
import {Mandate, MandateParams} from "../src/Mandate.sol";
import {RiskEngine, TradeProposal, Side, RejectReason} from "../src/RiskEngine.sol";

/// @title Demo
/// @notice The ninety-second story, as a runnable script: a valid trade is
///         approved, an oversized one is rejected BY NAME, and then the SAME
///         valid trade is rejected because the holder flipped a switch the
///         agent cannot reach.
///
/// @dev Self-contained: deploys its own instances so it can be run repeatedly
///      for free with no chain and no funded wallet:
///
///          forge script script/Demo.s.sol:Demo -vv
///
///      Numbers are deliberately round against a 10,000-unit balance — a
///      500-unit position approves comfortably, a 2,000-unit one exceeds
///      Preservation's 1,000-unit cap. Numbers a viewer can check in their head
///      beat numbers that require trust.
contract Demo is Script {
    /// @dev Demo fixture, NOT a real token address. This repo does not
    ///      fabricate verified addresses (rule 2).
    address constant DEMO_ASSET = address(0x1000000000000000000000000000000000000001);

    uint256 constant UNIT = 1e18;

    function run() external {
        vm.startBroadcast();

        GenesisAgent nft = new GenesisAgent(10_000);
        AccountRegistry registry = new AccountRegistry(IERC721(address(nft)));
        address[] memory assets = new address[](1);
        assets[0] = DEMO_ASSET;
        RiskEngine engine = new RiskEngine(IAccountRegistry(address(registry)), assets);

        _rule();
        console.log("AgentVault - the AI proposes, deterministic code decides");
        _rule();

        // ---- 1. Mint ----
        uint256 tokenId = nft.mint(Archetype.Guardian);
        console.log("1. MINT");
        console.log("   token id          ", tokenId);
        console.log("   archetype         ", nft.archetypeNameOf(tokenId));
        console.log("   (permanent - collectible identity, never a risk limit)");
        console.log("");

        // ---- 2. Create account ----
        registry.createAccount(tokenId);
        AccountRegistry.Account memory account = registry.getAccount(tokenId);
        console.log("2. CREATE ACCOUNT");
        console.log("   balance (units)   ", account.balance / UNIT);
        console.log("   deposited (units) ", account.depositedTotal / UNIT);
        console.log("   profit and loss   ", registry.pnlOf(tokenId));
        console.log("   automation paused  true   (accounts start stopped)");
        console.log("   mandate            Unset  (the holder chooses, nothing defaults)");
        console.log("");

        // ---- 3. Select a mandate ----
        registry.setMandate(tokenId, Mandate.Preservation);
        MandateParams memory params = registry.mandateParamsOf(tokenId);
        uint256 positionCap = (account.balance * params.maxPositionBps) / 10_000;
        console.log("3. SELECT MANDATE: Preservation");
        console.log("   max position       ", params.maxPositionBps, "bps");
        console.log("   = units            ", positionCap / UNIT);
        console.log("   max slippage       ", params.maxSlippageBps, "bps");
        console.log("");

        // ---- 4. A valid proposal ----
        registry.setAutomationPaused(tokenId, false);
        TradeProposal memory valid = TradeProposal({
            asset: DEMO_ASSET,
            side: Side.Buy,
            sizeUnits: 500 * UNIT,
            slippageBps: 25,
            dataTimestamp: block.timestamp
        });
        _report(engine, tokenId, valid, "4. PROPOSE 500 units, 25 bps slippage");

        // ---- 5. An oversized proposal ----
        // EXPLICIT COPY, field by field. `TradeProposal memory oversized =
        // valid;` would alias the same memory struct, so mutating one mutates
        // both — and step 6 would then print the oversized size instead of
        // step 4's, destroying the entire point of the demo.
        TradeProposal memory oversized = TradeProposal({
            asset: valid.asset,
            side: valid.side,
            sizeUnits: 2000 * UNIT,
            slippageBps: valid.slippageBps,
            dataTimestamp: valid.dataTimestamp
        });
        _report(engine, tokenId, oversized, "5. PROPOSE 2000 units - over the 1000 cap");

        // ---- 6. The kill switch, with step 4's EXACT proposal ----
        registry.setAutomationPaused(tokenId, true);
        console.log("   >> holder flips the kill switch <<");
        _report(engine, tokenId, valid, "6. RESUBMIT THE STEP 4 PROPOSAL, UNCHANGED");

        _rule();
        console.log("Nothing about the trade changed between 4 and 6.");
        console.log("Only the holder's instruction did - and the agent");
        console.log("has no way to reach that switch.");
        _rule();

        vm.stopBroadcast();
    }

    /// @dev Prints a proposal's verdict with the reason as a NAME. "REJECTED:
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
