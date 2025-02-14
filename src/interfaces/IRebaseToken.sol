// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

interface IRebaseToken {
    function mint(address account, uint256 value, uint256 interestRate) external;
    function burn(address _from, uint256 _amount) external;
    function getInterestRate() external view returns (uint256);
    function getUserInterestRate(address _user) external view returns (uint256);
    function grantMinterAndBurnerRole(address account) external;
}
