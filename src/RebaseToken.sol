// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { PRECISION_FACTOR, MINTER_AND_BURNER_ROLE } from "./Constants.sol";
import { RebaseToken__NewInterestRateCannotBeGreaterThanPrevious } from "./Errors.sol";
import { InterestRateSet } from "./Events.sol";

/**
 * @title RebaseToken
 * @author sumit03guha
 * @notice ERC20 token that accrues interest linearly over time.
 * @dev This contract extends ERC20, Ownable, and AccessControl to allow for controlled token minting, burning,
 * and transfers that include a mechanism for accruing interest over time based on user-specific parameters.
 */
contract RebaseToken is AccessControl, Ownable, ERC20 {
    mapping(address => uint256) private _userInterestRate;
    mapping(address => uint256) private _userLastUpdatedTimestamp;

    uint256 private _interestRate;

    /**
     * @notice Initializes the RebaseToken with an initial interest rate.
     * @param interestRate The starting interest rate applied to the token.
     */
    constructor(uint256 interestRate) Ownable(msg.sender) ERC20("RebaseToken", "RBT") {
        _interestRate = interestRate;
    }

    /**
     * @notice Sets a new global interest rate.
     * @param newInterestRate The new interest rate, which must be lower than the current rate.
     * @dev Reverts with RebaseToken__NewInterestRateCannotBeGreaterThanPrevious if newInterestRate is not lower.
     * Emits an {InterestRateSet} event on successful update.
     */
    function setInterestRate(uint256 newInterestRate) external onlyOwner {
        require(
            newInterestRate < _interestRate,
            RebaseToken__NewInterestRateCannotBeGreaterThanPrevious(newInterestRate, _interestRate)
        );
        _interestRate = newInterestRate;

        emit InterestRateSet(newInterestRate);
    }

    /**
     * @notice Grants the MINTER_AND_BURNER_ROLE to a specific account.
     * @param account The address that will be granted the role.
     */
    function grantMinterAndBurnerRole(address account) external onlyOwner {
        _grantRole(MINTER_AND_BURNER_ROLE, account);
    }

    /**
     * @notice Mints tokens to an account, while accounting for accrued interest.
     * @param account The beneficiary address to receive tokens.
     * @param value The number of tokens to be minted.
     * @param interestRate The interest rate to set for the account.
     * @dev Calls _mintAccruedInterest to update interest before minting new tokens.
     */
    function mint(address account, uint256 value, uint256 interestRate)
        external
        onlyRole(MINTER_AND_BURNER_ROLE)
    {
        _mintAccruedInterest(account);
        _userInterestRate[account] = interestRate;
        _mint(account, value);
    }

    /**
     * @notice Burns tokens from an account, updating accrued interest before burning.
     * @param _from The address from which tokens will be burned.
     * @param _amount The amount of tokens to burn. If _amount equals maximum uint256, burns the entire balance.
     * @dev Calls _mintAccruedInterest to update interest, then proceeds with burning.
     */
    function burn(address _from, uint256 _amount) external onlyRole(MINTER_AND_BURNER_ROLE) {
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_from);
        }
        _mintAccruedInterest(_from);
        _burn(_from, _amount);
    }

    /**
     * @notice Transfers tokens from the sender to a recipient, updating accrued interest for both parties.
     * @param to The recipient address.
     * @param value The amount of tokens to transfer. If value equals maximum uint256, transfers the sender's full balance.
     * @return A boolean indicating success.
     * @dev Overrides ERC20.transfer to include interest accrual updates.
     */
    function transfer(address to, uint256 value) public override returns (bool) {
        _mintAccruedInterest(msg.sender);
        _mintAccruedInterest(to);

        if (value == type(uint256).max) {
            value = balanceOf(msg.sender);
        }

        if (balanceOf(to) == 0) {
            _userInterestRate[to] = _userInterestRate[msg.sender];
        }

        return super.transfer(to, value);
    }

    /**
     * @notice Transfers tokens on behalf of another account, updating accrued interest.
     * @param from The sender's address.
     * @param to The recipient's address.
     * @param value The amount of tokens to transfer. If value equals maximum uint256, transfers the sender's full balance.
     * @return A boolean indicating success.
     * @dev Overrides ERC20.transferFrom to add interest accrual updates.
     */
    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        _mintAccruedInterest(from);
        _mintAccruedInterest(to);

        if (value == type(uint256).max) {
            value = balanceOf(from);
        }

        if (balanceOf(to) == 0) {
            _userInterestRate[to] = _userInterestRate[from];
        }

        return super.transferFrom(from, to, value);
    }

    /**
     * @notice Returns the principal balance of an account, excluding any accrued interest.
     * @param _account The address of the account.
     * @return The basic ERC20 balance without interest adjustments.
     */
    function principalBalance(address _account) public view returns (uint256) {
        return super.balanceOf(_account);
    }

    /**
     * @notice Retrieves the current global interest rate.
     * @return The contract-wide interest rate used for interest calculations.
     */
    function getInterestRate() public view returns (uint256) {
        return _interestRate;
    }

    /**
     * @notice Retrieves the specific interest rate assigned to a user.
     * @param _user The address of the user.
     * @return The interest rate for the specified user.
     */
    function getUserInterestRate(address _user) public view returns (uint256) {
        return _userInterestRate[_user];
    }

    /**
     * @notice Returns the token balance of an account including accrued interest.
     * @param account The address of the account.
     * @return The current balance with interest applied.
     * @dev Overrides ERC20.balanceOf to calculate balance based on accrued interest.
     */
    function balanceOf(address account) public view override returns (uint256) {
        return (super.balanceOf(account) * _calculateLinearInterest(account)) / PRECISION_FACTOR;
    }

    /**
     * @dev Mints any accrued interest to the account by comparing the current calculated balance
     *      with the stored principal balance, then updates the last updated timestamp.
     * @param account The address to update with accrued interest.
     */
    function _mintAccruedInterest(address account) private {
        uint256 previousBalance = super.balanceOf(account);
        uint256 currentBalance = balanceOf(account);

        uint256 amountAccruedRequiredToMint = currentBalance - previousBalance;
        _userLastUpdatedTimestamp[account] = block.timestamp;

        _mint(account, amountAccruedRequiredToMint);
    }

    /**
     * @dev Calculates the linear interest multiplier for an account based on time elapsed since the last update.
     * @param account The address for which to calculate the multiplier.
     * @return A multiplier (scaled by PRECISION_FACTOR) representing the accrued interest factor.
     */
    function _calculateLinearInterest(address account) private view returns (uint256) {
        uint256 timeElapsed = block.timestamp - _userLastUpdatedTimestamp[account];

        return (PRECISION_FACTOR + (_userInterestRate[account] * timeElapsed));
    }
}
