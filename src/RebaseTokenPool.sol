// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import { IERC20 } from
    "@chainlink-contracts/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import { Pool } from "@chainlink-contracts/ccip/libraries/Pool.sol";
import { TokenPool } from "@chainlink-contracts/ccip/pools/TokenPool.sol";

import { IRebaseToken } from "./interfaces/IRebaseToken.sol";

/**
 * @title RebaseTokenPool
 * @author sumit03guha
 * @notice Pool contract for RebaseTokens supporting cross-chain operations.
 * @dev Inherits from TokenPool and provides functionality to lock, burn, release, or mint tokens
 * based on cross-chain messages.
 */
contract RebaseTokenPool is TokenPool {
    /**
     * @notice Initializes the RebaseTokenPool.
     * @param token The ERC20 token managed by the pool.
     * @param allowlist List of addresses allowed to interact with the pool.
     * @param rmnProxy The address of the proxy for remote management.
     * @param router The router address used for cross-chain transfers.
     */
    constructor(IERC20 token, address[] memory allowlist, address rmnProxy, address router)
        TokenPool(token, 18, allowlist, rmnProxy, router)
    { }

    /**
     * @notice Locks or burns tokens as part of a cross-chain operation.
     * @param lockOrBurnIn The input parameters for locking or burning tokens.
     * @return lockOrBurnOut The output parameters including destination token address and pool data.
     * @dev Validates the operation, burns tokens from the pool, retrieves the user interest rate,
     * and encodes it for use in cross-chain communication.
     */
    function lockOrBurn(Pool.LockOrBurnInV1 calldata lockOrBurnIn)
        external
        returns (Pool.LockOrBurnOutV1 memory lockOrBurnOut)
    {
        _validateLockOrBurn(lockOrBurnIn);
        IRebaseToken(lockOrBurnIn.localToken).burn(address(this), lockOrBurnIn.amount);

        uint256 userInterestRate =
            IRebaseToken(lockOrBurnIn.localToken).getUserInterestRate(lockOrBurnIn.originalSender);

        lockOrBurnOut = Pool.LockOrBurnOutV1({
            destTokenAddress: getRemoteToken(lockOrBurnIn.remoteChainSelector),
            destPoolData: abi.encode(userInterestRate)
        });
    }

    /**
     * @notice Releases or mints tokens on the destination chain as part of a cross-chain operation.
     * @param releaseOrMintIn The input parameters for the release or mint operation.
     * @return The output parameters including the destination amount.
     * @dev Validates the operation, decodes the source pool data to retrieve the user interest rate,
     * and mints tokens to the receiver.
     */
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
