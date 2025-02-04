// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { PRECISION_FACTOR, MINTER_AND_BURNER_ROLE } from "./Constants.sol";
import { RebaseToken__NewInterestRateCannotBeGreaterThanPrevious } from "./Errors.sol";
import { InterestRateSet } from "./Events.sol";

contract RebaseToken is AccessControl, Ownable, ERC20 {
    mapping(address => uint256) private _userInterestRate;
    mapping(address => uint256) private _userLastUpdatedTimestamp;

    uint256 private _interestRate;

    constructor(uint256 interestRate) Ownable(msg.sender) ERC20("RebaseToken", "RBT") {
        _interestRate = interestRate;
    }

    function setInterestRate(uint256 newInterestRate) external onlyOwner {
        require(
            newInterestRate < _interestRate,
            RebaseToken__NewInterestRateCannotBeGreaterThanPrevious(newInterestRate, _interestRate)
        );
        _interestRate = newInterestRate;

        emit InterestRateSet(newInterestRate);
    }

    function grantMinterAndBurnerRole(address account) external onlyOwner {
        _grantRole(MINTER_AND_BURNER_ROLE, account);
    }

    function mint(address account, uint256 value, uint256 interestRate)
        external
        onlyRole(MINTER_AND_BURNER_ROLE)
    {
        _mintAccruedInterest(account);
        _userInterestRate[account] = interestRate;
        _mint(account, value);
    }

    function burn(address _from, uint256 _amount) external onlyRole(MINTER_AND_BURNER_ROLE) {
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_from);
        }
        _mintAccruedInterest(_from);
        _burn(_from, _amount);
    }

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

    function principalBalance(address _account) public view returns (uint256) {
        return super.balanceOf(_account);
    }

    function getInterestRate() public view returns (uint256) {
        return _interestRate;
    }

    function getUserInterestRate(address _user) public view returns (uint256) {
        return _userInterestRate[_user];
    }

    function balanceOf(address account) public view override returns (uint256) {
        return (super.balanceOf(account) * _calculateLinearInterest(account)) / PRECISION_FACTOR;
    }

    function _mintAccruedInterest(address account) private {
        uint256 previousBalance = super.balanceOf(account);
        uint256 currentBalance = balanceOf(account);

        uint256 amountAccruedRequiredToMint = currentBalance - previousBalance;
        _userLastUpdatedTimestamp[account] = block.timestamp;

        _mint(account, amountAccruedRequiredToMint);
    }

    function _calculateLinearInterest(address account) private view returns (uint256) {
        uint256 timeElapsed = block.timestamp - _userLastUpdatedTimestamp[account];

        return (PRECISION_FACTOR + (_userInterestRate[account] * timeElapsed));
    }
}
