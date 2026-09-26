// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {GenesisAgent} from "../src/GenesisAgent.sol";
import {AccountRegistry} from "../src/AccountRegistry.sol";
import {Archetype} from "../src/Archetype.sol";
import {Mandate, MandateParams} from "../src/Mandate.sol";

/// @title SmokeTest
/// @notice Exercises the whole path against a LIVE deployment: mint, account
///         creation, mandate selection, kill switch, and withdrawal.
///
/// @dev Bytecode existing is not the same as the system working. Every step
///      asserts, so a wrong answer fails loudly instead of scrolling past.
///
///      Addresses come from the environment, never hardcoded — the same
///      discipline the deploy script follows.
///
///      TESTNET ONLY. Refuses mainnet for the same reason DeployTestnet does.
///
///      NOTE: this mints from the caller, and `GenesisAgent` allows one mint
///      per address ever. A second broadcast from the same sender reverts with
///      `AlreadyMinted`. That is the contract working, not the script failing.
contract SmokeTest is Script {
    uint256 constant ROBINHOOD_MAINNET_CHAIN_ID = 4663;

    error MainnetNotPermitted(uint256 chainId);

    function run() external {
        if (block.chainid == ROBINHOOD_MAINNET_CHAIN_ID) {
            revert MainnetNotPermitted(block.chainid);
        }

        GenesisAgent nft = GenesisAgent(vm.envAddress("GENESIS_AGENT"));
        AccountRegistry registry = AccountRegistry(vm.envAddress("ACCOUNT_REGISTRY"));

        // Sanity: the registry must actually be wired to this NFT.
        require(address(registry.agentNft()) == address(nft), "registry points elsewhere");

        vm.startBroadcast();

        // ---- 1. mint ----
        // Assert the id is the next one in sequence rather than literally 1.
        // On a fresh deployment that IS 1, which is what the spec describes,
        // but the script stays meaningful against a deployment that has
        // already minted — where the next id is 2, not a failure.
        uint256 expectedId = nft.totalMinted() + 1;
        uint256 tokenId = nft.mint(Archetype.Guardian);
        require(tokenId == expectedId, "step 1: token id was not the next in sequence");
        require(nft.totalMinted() == expectedId, "step 1: totalMinted did not advance");
        console.log("1. mint                  -> tokenId", tokenId);

        // ---- 2. archetypeOf ----
        require(nft.archetypeOf(tokenId) == Archetype.Guardian, "step 2: wrong archetype");
        console.log("2. archetypeOf           ->", nft.archetypeNameOf(tokenId));

        // ---- 3. createAccount ----
        registry.createAccount(tokenId);
        require(registry.accountExists(tokenId), "step 3: account not created");
        console.log("3. createAccount         -> created");

        // ---- 4. getAccount ----
        AccountRegistry.Account memory a = registry.getAccount(tokenId);
        uint256 seed = registry.SEED_BALANCE();
        require(a.balance == seed, "step 4: balance != SEED_BALANCE");
        require(a.depositedTotal == seed, "step 4: depositedTotal != SEED_BALANCE");
        require(a.withdrawnTotal == 0, "step 4: withdrawnTotal != 0");
        require(registry.pnlOf(tokenId) == 0, "step 4: PnL != 0");
        require(registry.isAutomationPaused(tokenId), "step 4: should start paused");
        require(a.mandate == Mandate.Unset, "step 4: mandate should be Unset");
        require(a.ownerPeriod == 1, "step 4: ownerPeriod != 1");
        console.log("4. getAccount            -> balance", a.balance);
        console.log("   depositedTotal        ->", a.depositedTotal);
        console.log("   pnl                   -> 0, paused: true, mandate: Unset");

        // ---- 4b. deposit (addition beyond the spec's eight steps) ----
        // The literal demonstration that deposit() leaves pnlOf unchanged. The
        // first run established this only adjacently: the seed appeared as
        // depositedTotal with PnL zero, and a withdrawal left PnL at zero, but
        // the deposit() entry point itself was never exercised on chain.
        int256 pnlBeforeDeposit = registry.pnlOf(tokenId);
        uint256 balanceBeforeDeposit = registry.getAccount(tokenId).balance;
        uint256 depositAmount = 2500e18;

        registry.deposit(tokenId, depositAmount);

        AccountRegistry.Account memory afterDeposit = registry.getAccount(tokenId);
        require(
            afterDeposit.balance == balanceBeforeDeposit + depositAmount,
            "step 4b: balance did not increase by the deposit"
        );
        require(
            afterDeposit.depositedTotal == seed + depositAmount,
            "step 4b: depositedTotal did not increase by the deposit"
        );
        require(registry.pnlOf(tokenId) == pnlBeforeDeposit, "step 4b: deposit moved PnL");
        require(registry.pnlOf(tokenId) == 0, "step 4b: PnL should still be exactly zero");
        console.log("4b. deposit              -> balance", afterDeposit.balance);
        console.log("    depositedTotal       ->", afterDeposit.depositedTotal);
        console.log("    pnl after deposit    -> 0 (funding is not profit)");

        // ---- 5. setMandate ----
        registry.setMandate(tokenId, Mandate.Preservation);
        require(registry.mandateOf(tokenId) == Mandate.Preservation, "step 5: mandate not set");
        console.log("5. setMandate            -> Preservation");

        // ---- 6. mandateParamsOf ----
        MandateParams memory p = registry.mandateParamsOf(tokenId);
        require(p.maxPositionBps == 1000, "step 6: maxPositionBps");
        require(p.maxSlippageBps == 50, "step 6: maxSlippageBps");
        require(p.maxDailyDrawdownBps == 300, "step 6: maxDailyDrawdownBps");
        require(p.maxOpenPositions == 5, "step 6: maxOpenPositions");
        require(p.liveEligible, "step 6: Preservation should be live-eligible");
        console.log("6. mandateParamsOf       -> 1000/50/300 bps, 5 positions");

        // ---- 7. kill switch off ----
        registry.setAutomationPaused(tokenId, false);
        require(!registry.isAutomationPaused(tokenId), "step 7: should be unpaused");
        console.log("7. setAutomationPaused   -> false");

        // ---- 8. withdraw ----
        uint256 amount = 1e18;
        uint256 before = registry.getAccount(tokenId).balance;
        registry.withdraw(tokenId, amount);
        AccountRegistry.Account memory after_ = registry.getAccount(tokenId);
        require(after_.balance == before - amount, "step 8: balance not reduced");
        require(after_.withdrawnTotal == amount, "step 8: withdrawnTotal wrong");
        require(registry.pnlOf(tokenId) == 0, "step 8: withdrawal moved PnL");
        console.log("8. withdraw              -> balance", after_.balance);
        console.log("   pnl after withdrawal  -> 0 (principal out is not a loss)");

        vm.stopBroadcast();

        console.log("");
        console.log("ALL 8 SMOKE-TEST STEPS PASSED");
    }
}
