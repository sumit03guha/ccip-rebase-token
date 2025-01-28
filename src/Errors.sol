// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

error RebaseToken__NewInterestRateCannotBeGreaterThanPrevious(
    uint256 newInterestRate, uint256 oldInterestRate
);
