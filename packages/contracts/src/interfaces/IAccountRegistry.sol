// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Mandate, MandateParams} from "../Mandate.sol";

/// @title IAccountRegistry
/// @notice The subset of `AccountRegistry` that `RiskEngine` depends on.
///
/// @dev Declared as an interface so the engine depends on a shape rather than
///      on a deployment — the same reasoning that kept `AccountRegistry` on
///      `IERC721`. Tests can then use a mock and stay unaffected by registry
///      changes.
///
///      RECONCILED AGAINST THE COMMITTED `AccountRegistry`, not against prose.
///      Three consequences worth stating, because they constrain the engine:
///
///      1. There is NO standalone balance getter. Balance is reachable only
///         through `getAccount(...).balance`, so `Account` below must stay
///         byte-identical to `AccountRegistry.Account` — same fields, same
///         order, same types — or ABI decoding silently misreads it. A
///         `balanceOf` was deliberately NOT added to the registry: it is
///         already deployed and source-verified on testnet, and adding a
///         function would desync the verified source from the live bytecode.
///
///      2. `getAccount`, `mandateOf` and `mandateParamsOf` all REVERT for an
///         account that does not exist. `RiskEngine.validate` must never
///         revert, so it checks `accountExists` before touching any of them.
///         That ordering is load-bearing, not cosmetic.
///
///      3. `mandateParamsOf` REVERTS with `InvalidMandate(0)` when the mandate
///         is `Unset`. So the mandate check must run before it.
///
///      `isAutomationPaused` and `mandateOf` return EFFECTIVE state: the
///      registry applies pending-transfer transformations in memory. The engine
///      must use these rather than reaching around them, or a sold account
///      could be validated against the previous holder's risk appetite during
///      the window before sync.
interface IAccountRegistry {
    /// @dev Must mirror `AccountRegistry.Account` exactly.
    struct Account {
        bool exists;
        address lastKnownOwner;
        uint256 depositedTotal;
        uint256 withdrawnTotal;
        uint256 balance;
        bool automationPaused;
        uint32 ownerPeriod;
        uint64 createdAt;
        Mandate mandate;
    }

    /// @notice Whether an account has been created. Does not revert.
    function accountExists(uint256 tokenId) external view returns (bool);

    /// @notice Full account state, effective. Reverts if no account exists.
    function getAccount(uint256 tokenId) external view returns (Account memory);

    /// @notice Effective automation-paused state: true while a transfer is
    ///         pending, even if the stored flag says otherwise.
    function isAutomationPaused(uint256 tokenId) external view returns (bool);

    /// @notice Effective selected mandate. Reverts if no account exists.
    function mandateOf(uint256 tokenId) external view returns (Mandate);

    /// @notice Risk limits for the selected mandate. Reverts if no account
    ///         exists, and reverts `InvalidMandate(0)` if the mandate is
    ///         `Unset`.
    function mandateParamsOf(uint256 tokenId) external view returns (MandateParams memory);
}
