// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title TestAsset
/// @notice A minimal fixed-supply ERC-20 deployed purely so the risk engine has
///         something to allowlist on testnet.
///
/// @dev IT LIVES UNDER `src/mocks/` SO ITS STATUS IS UNAMBIGUOUS FROM THE PATH.
///      This is not a real asset, has no market, no price, no liquidity, and no
///      value. It exists because `RiskEngine` needs a non-empty asset allowlist
///      and the testnet faucet supplied no in-tier asset to use — see
///      `DECISIONS.md` D13.
///
///      Deliberately boring: no mint function, no owner, no pause, no hooks.
///      The entire supply is minted to the deployer at construction and the
///      total can never change. There is nothing here to configure and nothing
///      to compromise.
///
///      PROTOTYPE / TESTNET ONLY. Never deploy this to mainnet, and never treat
///      a balance of it as representing anything.
contract TestAsset is ERC20 {
    /// @notice Entire supply, minted once to the deployer.
    /// @dev PROTOTYPE value. Large enough that test positions are never
    ///      supply-constrained, which keeps the risk engine the only thing that
    ///      ever rejects a proposal.
    uint256 public constant FIXED_SUPPLY = 1_000_000e18;

    /// @param name_ ERC-20 name.
    /// @param symbol_ ERC-20 symbol.
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {
        _mint(msg.sender, FIXED_SUPPLY);
    }
}
