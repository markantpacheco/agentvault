// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {TestAsset} from "../src/mocks/TestAsset.sol";

/// @title TestAssetTest
/// @notice Tests the placeholder ERC-20 the risk engine allowlists on testnet.
contract TestAssetTest is Test {
    TestAsset internal asset;

    function setUp() public {
        asset = new TestAsset("AgentVault Test Asset A", "AVTA");
    }

    /// WHAT: Name, symbol and decimals are as constructed.
    /// WHY: These are what appear in the explorer and in the demo. A wrong
    ///      symbol makes the allowlist unreadable to anyone checking it.
    /// FAILURE MEANS: The allowlisted asset is not identifiable.
    function test_MetadataIsAsConstructed() public view {
        assertEq(asset.name(), "AgentVault Test Asset A", "name");
        assertEq(asset.symbol(), "AVTA", "symbol");
        assertEq(asset.decimals(), 18, "decimals");
    }

    /// WHAT: The whole fixed supply goes to the deployer and nothing more
    ///       exists.
    /// WHY: Supply must never constrain a test position, so that the risk
    ///      engine is the only thing that can ever reject a proposal.
    /// FAILURE MEANS: A rejection could be caused by token supply rather than
    ///      by a risk rule, making test results misleading.
    function test_FixedSupplyGoesEntirelyToDeployer() public view {
        assertEq(asset.totalSupply(), asset.FIXED_SUPPLY(), "totalSupply");
        assertEq(asset.balanceOf(address(this)), asset.FIXED_SUPPLY(), "deployer balance");
    }

    /// WHAT: There is no way to create more tokens after deployment.
    /// WHY: A mint function would need an owner, and this project has shipped
    ///      every contract without a privileged role.
    /// FAILURE MEANS: The supply is not actually fixed.
    /// @dev Proven structurally: `TestAsset` declares no mint, and OpenZeppelin's
    ///      `_mint` is `internal`, so no external caller can reach it. This test
    ///      pins the observable consequence — supply is unchanged after
    ///      ordinary use.
    function test_SupplyIsUnchangedByTransfers() public {
        address recipient = makeAddr("recipient");
        asset.transfer(recipient, 1000e18);

        assertEq(asset.totalSupply(), asset.FIXED_SUPPLY(), "supply moved");
        assertEq(asset.balanceOf(recipient), 1000e18, "recipient balance");
    }
}
