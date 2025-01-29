// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

interface IRebaseToken {
    function mint(address account, uint256 value) external;
    function burn(address _from, uint256 _amount) external;
}
