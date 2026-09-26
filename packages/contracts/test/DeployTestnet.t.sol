// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {DeployTestnet} from "../script/DeployTestnet.s.sol";

/// @title DeployTestnetTest
/// @notice Tests the deployment script's chain guards.
/// @dev These run locally and deploy nothing to any network.
contract DeployTestnetTest is Test {
    DeployTestnet internal deployScript;

    function setUp() public {
        deployScript = new DeployTestnet();
    }

    /// WHAT: The script refuses to run on Robinhood Chain mainnet (4663).
    /// WHY: Mainnet deployment is gated on the live-capital checklist in
    ///      ROADMAP.md, which is nowhere near satisfied. A guard enforced by a
    ///      test cannot be forgotten under deadline pressure the way a note in
    ///      a runbook can.
    /// FAILURE MEANS: A mistyped RPC URL could put these contracts on mainnet,
    ///      which is not reversible.
    /// @dev EXPECTED_CHAIN_ID is deliberately NOT set here. The mainnet guard
    ///      is read before it, so the refusal must not depend on any
    ///      environment variable being present.
    function test_ScriptRefusesMainnetChainId() public {
        vm.chainId(4663);

        vm.expectRevert(
            abi.encodeWithSelector(
                DeployTestnet.MainnetDeploymentNotPermitted.selector, uint256(4663)
            )
        );
        deployScript.run();
    }

    /// WHAT: The script refuses a chain that is not the intended one.
    /// WHY: The second guard catches pointing at the wrong RPC — a subtler
    ///      mistake than aiming at mainnet, and equally irreversible.
    /// FAILURE MEANS: Contracts land on whichever chain the RPC happened to
    ///      be, with no warning.
    function test_ScriptRefusesUnexpectedChain() public {
        vm.chainId(46630);
        vm.setEnv("EXPECTED_CHAIN_ID", "999");

        vm.expectRevert(
            abi.encodeWithSelector(
                DeployTestnet.UnexpectedChain.selector, uint256(46630), uint256(999)
            )
        );
        deployScript.run();
    }
}
