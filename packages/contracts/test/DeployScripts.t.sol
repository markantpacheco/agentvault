// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {DeployTestnet} from "../script/DeployTestnet.s.sol";
import {DeployRiskEngine} from "../script/DeployRiskEngine.s.sol";

/// @title DeployScriptsTest
/// @notice Guards for BOTH deployment scripts, deliberately in one contract.
///
/// @dev WHY BOTH SCRIPTS SHARE ONE TEST CONTRACT, AND ONE TEST FUNCTION:
///
///      `vm.setEnv` mutates the PROCESS environment, which every test in the
///      run shares, and Foundry executes test CONTRACTS IN PARALLEL. Two
///      contracts that both set `EXPECTED_CHAIN_ID` will therefore clobber each
///      other mid-test, non-deterministically.
///
///      That is not hypothetical: these guards previously lived in
///      `DeployTestnet.t.sol` and `DeployRiskEngine.t.sol`, both setting
///      `EXPECTED_CHAIN_ID=999`. The suite failed roughly three runs in five,
///      with the wrong guard firing — a test asserting `NoCodeAtAddress`
///      receiving `UnexpectedChain` instead, because the other file had reset
///      the variable between two calls in this one.
///
///      Splitting env-dependent cases across FUNCTIONS is not sufficient
///      either, since functions within a contract are not guaranteed to be
///      sequential relative to other contracts' functions. The only reliable
///      arrangement is: every env-dependent assertion in a SINGLE function, in
///      a SINGLE contract, with the variables set immediately before each call.
///
///      Tests that must read NO environment variable are kept separate and
///      touch none — that absence is part of what they prove.
contract DeployScriptsTest is Test {
    DeployTestnet internal deployTestnet;
    DeployRiskEngine internal deployRiskEngine;

    /// @dev Fixed, so assertions never depend on env-var ordering.
    address internal constant REGISTRY = address(0x00000000000000000000000000000000000ABc01);
    address internal constant AVTA = 0x87CEd5dc138F825B3F42924A8Bb6E15ae5EC9A7d;

    function setUp() public {
        deployTestnet = new DeployTestnet();
        deployRiskEngine = new DeployRiskEngine();
    }

    /// WHAT: Both deploy scripts refuse Robinhood Chain mainnet (4663).
    /// WHY: Mainnet deployment is gated on the live-capital checklist, which is
    ///      nowhere near satisfied. Every deploy script must carry this guard,
    ///      not just the first one written.
    /// FAILURE MEANS: A mistyped RPC could put these contracts on mainnet,
    ///      which is not reversible.
    /// @dev Reads NO environment variable, deliberately: the mainnet refusal
    ///      must not depend on any env var being set, and this test proves that
    ///      by setting none. It is therefore also immune to the parallelism
    ///      problem described at the contract level.
    function test_BothScriptsRefuseMainnetChainId() public {
        vm.chainId(4663);

        vm.expectRevert(
            abi.encodeWithSelector(
                DeployTestnet.MainnetDeploymentNotPermitted.selector, uint256(4663)
            )
        );
        deployTestnet.run();

        vm.expectRevert(
            abi.encodeWithSelector(
                DeployRiskEngine.MainnetDeploymentNotPermitted.selector, uint256(4663)
            )
        );
        deployRiskEngine.run();
    }

    /// WHAT: Every environment-dependent guard in both scripts, in order —
    ///       wrong chain for each script, then a registry with no code, then an
    ///       allowlist asset with no code.
    /// WHY: All of these produce a permanently broken deployment. `RiskEngine`
    ///      holds its registry `immutable` and its allowlist has no setter, so a
    ///      mistyped or wrong-chain address cannot be repaired afterwards, only
    ///      replaced. Each must fail loudly at deploy time.
    /// FAILURE MEANS: A verified, permanent engine deploys wired to nothing, or
    ///      with a nonexistent asset allowlisted forever.
    /// @dev Single function on purpose. See the contract-level note: this is the
    ///      only arrangement that is not racy.
    function test_AllEnvDependentGuards() public {
        vm.chainId(46630);

        // --- DeployTestnet: wrong chain ----------------------------------
        vm.setEnv("EXPECTED_CHAIN_ID", "999");
        vm.expectRevert(
            abi.encodeWithSelector(
                DeployTestnet.UnexpectedChain.selector, uint256(46630), uint256(999)
            )
        );
        deployTestnet.run();

        // --- DeployRiskEngine: wrong chain ------------------------------
        vm.setEnv("EXPECTED_CHAIN_ID", "999");
        vm.expectRevert(
            abi.encodeWithSelector(
                DeployRiskEngine.UnexpectedChain.selector, uint256(46630), uint256(999)
            )
        );
        deployRiskEngine.run();

        // --- DeployRiskEngine: registry holds no code --------------------
        vm.setEnv("EXPECTED_CHAIN_ID", "46630");
        vm.setEnv("ACCOUNT_REGISTRY", vm.toString(REGISTRY));
        vm.expectRevert(
            abi.encodeWithSelector(
                DeployRiskEngine.NoCodeAtAddress.selector, "AccountRegistry", REGISTRY
            )
        );
        deployRiskEngine.run();

        // --- DeployRiskEngine: registry fine, allowlist asset has no code -
        // Give the registry code so execution reaches the asset checks. The
        // allowlist constants have no code in a local test, which is exactly
        // the condition being asserted.
        vm.etch(REGISTRY, hex"600160005260206000f3");
        vm.setEnv("EXPECTED_CHAIN_ID", "46630");
        vm.expectRevert(
            abi.encodeWithSelector(DeployRiskEngine.NoCodeAtAddress.selector, "AVTA", AVTA)
        );
        deployRiskEngine.run();
    }
}
