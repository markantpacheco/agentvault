// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {GenesisAgent} from "../src/GenesisAgent.sol";
import {AccountRegistry} from "../src/AccountRegistry.sol";

/// @title DeployTestnet
/// @notice Deploys `GenesisAgent` and `AccountRegistry` to a TESTNET.
///
/// @dev TESTNET ONLY. Deploying to Robinhood Chain mainnet is gated on the
///      live-capital checklist in docs/ROADMAP.md, which is nowhere near
///      satisfied. The first guard below makes that structural rather than a
///      matter of care.
///
///      Only two contracts are deployed. `ArchetypeLib` and `MandateLib`
///      contain only `internal` functions, so the compiler inlines them into
///      their callers — they are never deployed and need no library linking.
///      Worth knowing up front, because library linking is a classic
///      deploy-time surprise; confirm by checking that neither appears in the
///      broadcast artifact.
contract DeployTestnet is Script {
    /// @notice Supply cap passed to `GenesisAgent`.
    /// @dev PROTOTYPE. Not audited, not final. The roadmap commits to sizing
    ///      real supply to actual user count when the real mint is designed.
    ///
    ///      `GenesisAgent`'s constructor takes ONLY this. The ERC-721 name and
    ///      symbol are fixed inside the contract as
    ///      ("AgentVault Genesis Agent", "AGENT") and are not constructor
    ///      arguments — which matters when ABI-encoding args for verification.
    uint256 constant MAX_SUPPLY = 10_000;

    /// @notice Robinhood Chain mainnet. Measured with `cast chain-id`, not
    ///         remembered.
    uint256 constant ROBINHOOD_MAINNET_CHAIN_ID = 4663;

    /// @notice Thrown when the target chain is Robinhood Chain mainnet.
    error MainnetDeploymentNotPermitted(uint256 chainId);

    /// @notice Thrown when the live chain is not the one the operator intended.
    error UnexpectedChain(uint256 actual, uint256 expected);

    function run() external {
        // Guard 1: never mainnet, under any configuration. A hard constant
        // that no environment variable can override or relax.
        if (block.chainid == ROBINHOOD_MAINNET_CHAIN_ID) {
            revert MainnetDeploymentNotPermitted(block.chainid);
        }

        // Guard 2: catches the subtler mistake of pointing at the wrong RPC.
        // A wrong-network deploy is not reversible — you simply have a contract
        // somewhere you did not mean to put one.
        //
        // Deliberately read AFTER guard 1, so the mainnet refusal does not
        // depend on any environment variable being set.
        uint256 expected = vm.envUint("EXPECTED_CHAIN_ID");
        if (block.chainid != expected) {
            revert UnexpectedChain(block.chainid, expected);
        }

        vm.startBroadcast();

        GenesisAgent nft = new GenesisAgent(MAX_SUPPLY);
        AccountRegistry registry = new AccountRegistry(IERC721(address(nft)));

        vm.stopBroadcast();

        // No address is hardcoded anywhere: AccountRegistry takes the
        // GenesisAgent produced in this same run.
        console.log("chainId        ", block.chainid);
        console.log("GenesisAgent   ", address(nft));
        console.log("AccountRegistry", address(registry));
    }
}
