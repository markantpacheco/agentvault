// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {DeployRiskEngine} from "../script/DeployRiskEngine.s.sol";

/// @title DeployRiskEngineTest
/// @notice Tests the RiskEngine deployment script's chain guards.
/// @dev Runs locally and deploys nothing to any network.
contract DeployRiskEngineTest is Test {
    DeployRiskEngine internal deployScript;

    function setUp() public {
        deployScript = new DeployRiskEngine();
    }

    /// WHAT: The script refuses to run on Robinhood Chain mainnet (4663).
    /// WHY: Mainnet deployment is gated on the live-capital checklist, which is
    ///      nowhere near satisfied. Every deploy script must carry this guard,
    ///      not just the first one written.
    /// FAILURE MEANS: A mistyped RPC could put the risk engine on mainnet,
    ///      which is not reversible.
    /// @dev EXPECTED_CHAIN_ID is deliberately unset: the mainnet refusal must
    ///      not depend on any environment variable being present.
    function test_ScriptRefusesMainnetChainId() public {
        vm.chainId(4663);

        vm.expectRevert(
            abi.encodeWithSelector(
                DeployRiskEngine.MainnetDeploymentNotPermitted.selector, uint256(4663)
            )
        );
        deployScript.run();
    }

    /// WHAT: The script refuses a chain that is not the intended one.
    /// WHY: Catches pointing at the wrong RPC — subtler than aiming at mainnet
    ///      and equally irreversible.
    /// FAILURE MEANS: The engine lands on whichever chain the RPC happened to
    ///      be, with no warning.
    function test_ScriptRefusesUnexpectedChain() public {
        vm.chainId(46630);
        vm.setEnv("EXPECTED_CHAIN_ID", "999");

        vm.expectRevert(
            abi.encodeWithSelector(
                DeployRiskEngine.UnexpectedChain.selector, uint256(46630), uint256(999)
            )
        );
        deployScript.run();
    }
}
