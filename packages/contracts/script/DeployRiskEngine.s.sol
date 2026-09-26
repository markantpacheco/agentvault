// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {IAccountRegistry} from "../src/interfaces/IAccountRegistry.sol";
import {RiskEngine} from "../src/RiskEngine.sol";
import {TestAsset} from "../src/mocks/TestAsset.sol";

/// @title DeployRiskEngine
/// @notice Deploys ONLY `RiskEngine`, pointing at an already-deployed
///         `AccountRegistry`.
///
/// @dev `GenesisAgent` and `AccountRegistry` are deliberately NOT redeployed:
///      they are live, source-verified, and hold token 1's account which the
///      live demo uses. Redeploying would orphan that state and invalidate the
///      addresses recorded in `deployments/robinhood-testnet.json`.
///
///      The registry address comes from the environment. The ALLOWLIST DOES
///      NOT: this script deploys two purpose-built `TestAsset` ERC-20s and
///      allowlists exactly those, so what ends up in the allowlist cannot be
///      supplied by accident.
///
///      It deliberately does NOT allowlist the five tokenized equities the
///      faucet supplied (TSLA, AMD, AMZN, NFLX, PLTR — all verified and
///      recorded as I13 in `INTEGRATIONS.md`). Those are outside both asset
///      tiers in `DECISIONS.md` D5 and sit against `PRODUCT.md`'s "not advice
///      on securities". The allowlist has no setter, so whatever the first
///      deployment contains is a permanent positioning statement. See D13.
///
///      Three contracts are deployed, in this order: TestAsset A, TestAsset B,
///      then the engine allowlisting both.
///
///      TESTNET ONLY, with the same two guards as `DeployTestnet`.
contract DeployRiskEngine is Script {
    /// @notice Robinhood Chain mainnet. Measured with `cast chain-id`.
    uint256 constant ROBINHOOD_MAINNET_CHAIN_ID = 4663;

    error MainnetDeploymentNotPermitted(uint256 chainId);
    error UnexpectedChain(uint256 actual, uint256 expected);

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

        console.log("chainId          ", block.chainid);
        console.log("AccountRegistry  ", registryAddress);

        vm.startBroadcast();

        // Purpose-deployed test assets. Not real assets, no market, no value.
        TestAsset assetA = new TestAsset("AgentVault Test Asset A", "AVTA");
        TestAsset assetB = new TestAsset("AgentVault Test Asset B", "AVTB");

        address[] memory allowlist = new address[](2);
        allowlist[0] = address(assetA);
        allowlist[1] = address(assetB);

        RiskEngine engine = new RiskEngine(IAccountRegistry(registryAddress), allowlist);

        vm.stopBroadcast();

        console.log("TestAsset AVTA   ", address(assetA));
        console.log("TestAsset AVTB   ", address(assetB));
        console.log("RiskEngine       ", address(engine));
        console.log("approvedAssets   ", engine.approvedAssetCount());
        console.log("MAX_DATA_AGE     ", engine.MAX_DATA_AGE());
        console.log("");
        console.log("Allowlist is FIXED - no setter. These two assets, permanently.");
    }
}
