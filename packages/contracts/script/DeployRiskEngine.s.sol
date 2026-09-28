// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {IAccountRegistry} from "../src/interfaces/IAccountRegistry.sol";
import {RiskEngine} from "../src/RiskEngine.sol";

/// @title DeployRiskEngine
/// @notice Deploys ONLY `RiskEngine`, against contracts that already exist.
///
/// @dev Nothing else is deployed. `GenesisAgent`, `AccountRegistry` and both
///      `TestAsset` tokens are live, source-verified and working; redeploying
///      any of them would orphan working contracts for no benefit and
///      invalidate the addresses recorded in
///      `deployments/robinhood-testnet.json`.
///
///      THE ALLOWLIST IS THREE NAMED CONSTANTS, NOT AN ENVIRONMENT VARIABLE.
///      That is deliberate and was the point of removing the env var earlier:
///      the allowlist is fixed at construction with no setter, so a change to
///      it is permanent for that engine. As constants, any change shows up in a
///      diff and goes through review. As an env var it could change silently
///      between a dry run and a broadcast, which is exactly the window an
///      impostor address would need.
///
///      Each address below carries a code check before deployment. A typo in a
///      permanent allowlist is unrecoverable, so it must fail loudly at deploy
///      rather than quietly succeed.
///
///      The five tokenized equities the faucet supplied are deliberately NOT
///      allowlisted — outside both asset tiers in `DECISIONS.md` D5 and against
///      `PRODUCT.md`'s "not advice on securities". Verified and recorded as
///      `INTEGRATIONS.md` I13. See D13.
///
///      NOTE ON DECIMALS: USDG is 6-decimal, the test assets are 18-decimal.
///      `RiskEngine` never reads `decimals()` — `sizeUnits` is a normalised
///      18-decimal simulated unit regardless of asset. See `DECISIONS.md` D14.
///
///      TESTNET ONLY, with the same two chain guards as `DeployTestnet`.
contract DeployRiskEngine is Script {
    /// @notice Robinhood Chain mainnet. Measured with `cast chain-id`.
    uint256 constant ROBINHOOD_MAINNET_CHAIN_ID = 4663;

    /// @notice AVTA — "AgentVault Test Asset A", 18 decimals.
    /// @dev Purpose-deployed placeholder with no market, price or value.
    ///      Deployed and source-verified 2026-09-26. `INTEGRATIONS.md` I14.
    address constant ASSET_AVTA = 0x87CEd5dc138F825B3F42924A8Bb6E15ae5EC9A7d;

    /// @notice AVTB — "AgentVault Test Asset B", 18 decimals.
    /// @dev As AVTA. Deployed and source-verified 2026-09-26.
    ///      `INTEGRATIONS.md` I14.
    address constant ASSET_AVTB = 0x9D97ebc6A395aaf981B26d952A4e22604eAFEc75;

    /// @notice USDG — Paxos "Global Dollar", **6 decimals**.
    /// @dev The only real in-tier asset in this allowlist. Verified 2026-09-28
    ///      from Paxos's own published testnet deployments, then read on chain:
    ///      symbol "USDG", name "Global Dollar", 6 decimals, EIP-1967 proxy,
    ///      3,878 holders. `INTEGRATIONS.md` I16.
    ///
    ///      The explorer lists more than fifty contracts claiming to be USDG,
    ///      five of them named "Paxos USDG", and none of those is real — the
    ///      genuine one is named plainly "Global Dollar". See
    ///      `SECURITY-ANALYSIS.md` S1. This is a TESTNET address and is
    ///      meaningless on any other chain, which is why the chain guards are
    ///      not optional.
    address constant ASSET_USDG = 0x7E955252E15c84f5768B83c41a71F9eba181802F;

    error MainnetDeploymentNotPermitted(uint256 chainId);
    error UnexpectedChain(uint256 actual, uint256 expected);

    /// @notice Thrown when an address that must be a contract holds no code.
    error NoCodeAtAddress(string what, address target);

    function run() external {
        // Guard 1: never mainnet, under any configuration. A hard constant no
        // environment variable can override.
        if (block.chainid == ROBINHOOD_MAINNET_CHAIN_ID) {
            revert MainnetDeploymentNotPermitted(block.chainid);
        }

        // Guard 2: catches pointing at the wrong RPC. Read AFTER guard 1 so the
        // mainnet refusal never depends on an environment variable being set.
        uint256 expected = vm.envUint("EXPECTED_CHAIN_ID");
        if (block.chainid != expected) {
            revert UnexpectedChain(block.chainid, expected);
        }

        address registryAddress = vm.envAddress("ACCOUNT_REGISTRY");

        // Guard 3: everything this engine will point at permanently must
        // actually be a contract on THIS chain. A mistyped or wrong-chain
        // address otherwise produces a verified, permanent engine wired to
        // nothing — and the allowlist has no setter to fix it.
        //
        // The registry is checked too: it is immutable on the engine, so a
        // typo there is equally unrecoverable.
        _requireCode("AccountRegistry", registryAddress);
        _requireCode("AVTA", ASSET_AVTA);
        _requireCode("AVTB", ASSET_AVTB);
        _requireCode("USDG", ASSET_USDG);

        address[] memory allowlist = new address[](3);
        allowlist[0] = ASSET_AVTA;
        allowlist[1] = ASSET_AVTB;
        allowlist[2] = ASSET_USDG;

        console.log("chainId          ", block.chainid);
        console.log("AccountRegistry  ", registryAddress);
        console.log("allowlist AVTA   ", ASSET_AVTA, "(18 decimals)");
        console.log("allowlist AVTB   ", ASSET_AVTB, "(18 decimals)");
        console.log("allowlist USDG   ", ASSET_USDG, "(6 decimals, Paxos)");

        vm.startBroadcast();
        RiskEngine engine = new RiskEngine(IAccountRegistry(registryAddress), allowlist);
        vm.stopBroadcast();

        console.log("RiskEngine       ", address(engine));
        console.log("approvedAssets   ", engine.approvedAssetCount());
        console.log("MAX_DATA_AGE     ", engine.MAX_DATA_AGE());
        console.log("");
        console.log("Allowlist is FIXED - no setter. These three assets, permanently.");
        console.log("No TestAsset was deployed: the existing ones are reused.");
    }

    /// @dev Reverts unless `target` holds non-empty bytecode on this chain.
    function _requireCode(string memory what, address target) private view {
        if (target.code.length == 0) {
            revert NoCodeAtAddress(what, target);
        }
    }
}
