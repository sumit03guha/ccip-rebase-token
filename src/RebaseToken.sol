// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { PRECISION_FACTOR } from "./Constants.sol";
import { RebaseToken__NewInterestRateCannotBeGreaterThanPrevious } from "./Errors.sol";

contract RebaseToken is Ownable, ERC20 {
    mapping(address => uint256) private _userInterestRate;
    mapping(address => uint256) private _userLastUpdatedTimestamp;

    uint256 private _interestRate;

    constructor(uint256 interestRate) Ownable(msg.sender) ERC20("RebaseToken", "RBT") {
        _interestRate = interestRate;
    }

    function setInterestRate(uint256 newInterestRate) external onlyOwner {
        if (newInterestRate >= _interestRate) {
            revert RebaseToken__NewInterestRateCannotBeGreaterThanPrevious(
                newInterestRate, _interestRate
            );
        }
        _interestRate = newInterestRate;
    }

    function mint(address account, uint256 value) external {
        _mintAccruedInterest(account);
        _userInterestRate[account] = _interestRate;
        _mint(account, value);
    }

    function burn(address _from, uint256 _amount) external {
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_from);
        }
        _mintAccruedInterest(_from);
        _burn(_from, _amount);
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
