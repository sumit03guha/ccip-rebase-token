// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import { IERC20 } from
    "@chainlink/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import { Pool } from "@chainlink/ccip/libraries/Pool.sol";
import { TokenPool } from "@chainlink/ccip/pools/TokenPool.sol";

import { IRebaseToken } from "./interfaces/IRebaseToken.sol";

contract RebaseTokenPool is TokenPool {
    constructor(IERC20 token, address[] memory allowlist, address rmnProxy, address router)
        TokenPool(token, 18, allowlist, rmnProxy, router)
    { }

    function lockOrBurn(Pool.LockOrBurnInV1 calldata lockOrBurnIn)
        external
        returns (Pool.LockOrBurnOutV1 memory lockOrBurnOut)
    {
        _validateLockOrBurn(lockOrBurnIn);
        IRebaseToken(lockOrBurnIn.localToken).burn(address(this), lockOrBurnIn.amount);

        // address receiver = abi.decode(lockOrBurnIn.receiver, (address));
        uint256 userInterestRate =
            IRebaseToken(lockOrBurnIn.localToken).getUserInterestRate(lockOrBurnIn.originalSender);

        lockOrBurnOut = Pool.LockOrBurnOutV1({
            destTokenAddress: getRemoteToken(lockOrBurnIn.remoteChainSelector),
            destPoolData: abi.encode(userInterestRate)
        });
    }

    function releaseOrMint(Pool.ReleaseOrMintInV1 calldata releaseOrMintIn)
        external
        returns (Pool.ReleaseOrMintOutV1 memory)
    {
        _validateReleaseOrMint(releaseOrMintIn);
        uint256 userInterestRate = abi.decode(releaseOrMintIn.sourcePoolData, (uint256));
        IRebaseToken(releaseOrMintIn.localToken).mint(
            releaseOrMintIn.receiver, releaseOrMintIn.amount, userInterestRate
        );

        return Pool.ReleaseOrMintOutV1({ destinationAmount: releaseOrMintIn.amount });
    }
}
