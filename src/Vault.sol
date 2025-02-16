// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import { IRebaseToken } from "./interfaces/IRebaseToken.sol";
import { Vault__RedeemFailed } from "./Errors.sol";
import { Deposit, Redeem } from "./Events.sol";

/**
 * @title Vault
 * @author sumit03guha
 * @notice A vault contract that interacts with a RebaseToken to enable deposits and redemptions.
 * @dev The vault mints tokens on deposit and burns them on redemption, handling ETH transfers accordingly.
 */
contract Vault {
    IRebaseToken private immutable _rebaseToken;

    /**
     * @notice Initializes the Vault with the specified RebaseToken.
     * @param rebaseToken The RebaseToken contract used for minting and burning tokens.
     */
    constructor(IRebaseToken rebaseToken) {
        _rebaseToken = rebaseToken;
    }

    /**
     * @notice Accepts ETH sent directly to the contract.
     */
    receive() external payable { }

    /**
     * @notice Deposits ETH into the vault and mints corresponding RebaseTokens.
     * @dev Retrieves the current global interest rate from the RebaseToken, mints tokens for the sender,
     * and emits a {Deposit} event.
     */
    function deposit() external payable {
        uint256 interestRate = _rebaseToken.getInterestRate();
        _rebaseToken.mint(msg.sender, msg.value, interestRate);

        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @notice Redeems tokens for ETH by burning the caller's RebaseTokens.
     * @param amount The amount of tokens to redeem.
     * @dev Burns tokens from the caller, attempts to transfer ETH back via a low-level call, and emits a {Redeem} event.
     * Reverts if the ETH transfer fails.
     */
    function redeem(uint256 amount) external {
        _rebaseToken.burn(msg.sender, amount);

        (bool success,) = msg.sender.call{ value: amount }("");
        require(success, Vault__RedeemFailed());

        emit Redeem(msg.sender, amount);
    }

    /**
     * @notice Returns the associated RebaseToken contract.
     * @return The IRebaseToken instance used by the vault.
     */
    function getRebaseToken() external view returns (IRebaseToken) {
        return _rebaseToken;
    }
}
