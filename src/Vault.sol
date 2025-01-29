// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import { IRebaseToken } from "./interfaces/IRebaseToken.sol";
import { Vault__RedeemFailed } from "./Errors.sol";
import { Deposit, Redeem } from "./Events.sol";

contract Vault {
    IRebaseToken private immutable _rebaseToken;

    constructor(IRebaseToken rebaseToken) {
        _rebaseToken = rebaseToken;
    }

    receive() external payable { }

    function deposit() external payable {
        _rebaseToken.mint(msg.sender, msg.value);

        emit Deposit(msg.sender, msg.value);
    }

    function redeem(uint256 amount) external {
        _rebaseToken.burn(msg.sender, amount);

        (bool success,) = msg.sender.call{ value: amount }("");
        require(success, Vault__RedeemFailed());

        emit Redeem(msg.sender, amount);
    }

    function getRebaseToken() external view returns (IRebaseToken) {
        return _rebaseToken;
    }
}
