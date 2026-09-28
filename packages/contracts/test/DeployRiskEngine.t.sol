// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {DeployRiskEngine} from "../script/DeployRiskEngine.s.sol";

/// @title DeployRiskEngineTest
/// @notice Tests the RiskEngine deployment script's guards.
/// @dev Runs locally and deploys nothing to any network.
///
///      IMPORTANT STRUCTURE NOTE: `vm.setEnv` mutates the PROCESS environment,
///      which is shared by every test function, whereas EVM state such as
///      `vm.etch` resets per test. Splitting the env-dependent cases across
///      several test functions therefore makes them interfere — one function's
///      `EXPECTED_CHAIN_ID` or `ACCOUNT_REGISTRY` leaks into another and the
///      failures look like guard bugs rather than test-harness bugs.
///
///      So exactly ONE function below touches env vars, and it checks each
///      configuration failure in sequence. Less granular, but correct; the
///      assertions still name the specific error and arguments.
contract DeployRiskEngineTest is Test {
    DeployRiskEngine internal deployScript;

    /// @dev Fixed so assertions never depend on env-var ordering.
    address internal constant REGISTRY = address(0x00000000000000000000000000000000000ABc01);
    address internal constant AVTA = 0x87CEd5dc138F825B3F42924A8Bb6E15ae5EC9A7d;

    function setUp() public {
        deployScript = new DeployRiskEngine();
    }

    /// WHAT: The script refuses to run on Robinhood Chain mainnet (4663).
    /// WHY: Mainnet deployment is gated on the live-capital checklist, which is
    ///      nowhere near satisfied. Every deploy script carries this guard, not
    ///      just the first one written.
    /// FAILURE MEANS: A mistyped RPC could put the risk engine on mainnet,
    ///      which is not reversible.
    /// @dev Touches no environment variable, deliberately: the mainnet refusal
    ///      must not depend on any env var being set, and this test proves it
    ///      by reading none.
    function test_ScriptRefusesMainnetChainId() public {
        vm.chainId(4663);

        vm.expectRevert(
            abi.encodeWithSelector(
                DeployRiskEngine.MainnetDeploymentNotPermitted.selector, uint256(4663)
            )
        );
        deployScript.run();
    }

    /// WHAT: Every bad deployment configuration is refused by name — wrong
    ///       chain, registry with no code, and an allowlist asset with no code.
    /// WHY: All three produce a permanently broken engine. `RiskEngine` stores
    ///      the registry as `immutable` and the allowlist has no setter, so a
    ///      mistyped or wrong-chain address cannot be repaired after
    ///      deployment — only replaced. Each must fail loudly at deploy time.
    /// FAILURE MEANS: A verified, permanent engine deploys wired to nothing, or
    ///      with a nonexistent asset allowlisted forever.
    /// @dev All three live in one function because they share process-level env
    ///      state. See the contract-level note.
    function test_ScriptRefusesBadConfiguration() public {
        // --- wrong chain -------------------------------------------------
        vm.chainId(46630);
        vm.setEnv("EXPECTED_CHAIN_ID", "999");
        vm.expectRevert(
            abi.encodeWithSelector(
                DeployRiskEngine.UnexpectedChain.selector, uint256(46630), uint256(999)
            )
        );
        deployScript.run();

        // --- registry holds no code --------------------------------------
        vm.setEnv("EXPECTED_CHAIN_ID", "46630");
        vm.setEnv("ACCOUNT_REGISTRY", vm.toString(REGISTRY));
        vm.expectRevert(
            abi.encodeWithSelector(
                DeployRiskEngine.NoCodeAtAddress.selector, "AccountRegistry", REGISTRY
            )
        );
        deployScript.run();

        // --- registry is fine, but an allowlist asset holds no code -------
        // Give the registry code so execution reaches the asset checks. The
        // allowlist constants have no code in a local test, which is exactly
        // the condition being asserted.
        vm.etch(REGISTRY, hex"600160005260206000f3");
        vm.expectRevert(
            abi.encodeWithSelector(DeployRiskEngine.NoCodeAtAddress.selector, "AVTA", AVTA)
        );
        deployScript.run();
    }
}
