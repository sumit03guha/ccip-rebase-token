// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import { Test, console2 } from "forge-std/Test.sol";

import { CCIPLocalSimulatorFork } from "@chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import { Register } from "@chainlink-local/src/ccip/Register.sol";

import { IERC20 } from
    "@chainlink-contracts/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import { IRouterClient } from "@chainlink-contracts/ccip/interfaces/IRouterClient.sol";
import { RegistryModuleOwnerCustom } from
    "@chainlink-contracts/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import { TokenAdminRegistry } from
    "@chainlink-contracts/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";
import { TokenPool } from "@chainlink-contracts/ccip/pools/TokenPool.sol";
import { RateLimiter } from "@chainlink-contracts/ccip/libraries/RateLimiter.sol";
import { Client } from "@chainlink-contracts/ccip/libraries/Client.sol";

import { IRebaseToken } from "../src/interfaces/IRebaseToken.sol";
import { RebaseToken } from "../src/RebaseToken.sol";
import { Vault } from "../src/Vault.sol";
import { RebaseTokenPool } from "../src/RebaseTokenPool.sol";
import { Deposit, Redeem, InterestRateSet } from "../src/Events.sol";
import { INTEREST_RATE } from "../src/Constants.sol";

contract CrossChainTest is Test {
    RebaseToken sepoliaToken;
    RebaseToken arbSepoliaToken;

    RebaseTokenPool sepoliaTokenPool;
    RebaseTokenPool arbSepoliaTokenPool;

    Vault vault;

    uint256 sepoliaFork;
    uint256 arbSepoliaFork;

    address owner = makeAddr("owner");
    address user = makeAddr("user");
    address recevier = makeAddr("receiver");

    CCIPLocalSimulatorFork ccipLocalSimulatorFork;

    Register.NetworkDetails sepoliaNetworkDetails;
    Register.NetworkDetails arbSepoliaNetworkDetails;

    function setUp() external {
        sepoliaFork = vm.createSelectFork("sepolia");
        arbSepoliaFork = vm.createFork("arb-sepolia");

        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulatorFork));

        vm.startPrank(owner);
        sepoliaToken = new RebaseToken(INTEREST_RATE);

        sepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);

        sepoliaTokenPool = new RebaseTokenPool(
            IERC20(address(sepoliaToken)),
            new address[](0),
            sepoliaNetworkDetails.rmnProxyAddress,
            sepoliaNetworkDetails.routerAddress
        );

        vault = new Vault(IRebaseToken(address(sepoliaToken)));
        sepoliaToken.grantMinterAndBurnerRole(address(vault));

        _setupRoles(address(sepoliaToken), address(sepoliaTokenPool), sepoliaNetworkDetails);

        vm.stopPrank();

        vm.selectFork(arbSepoliaFork);

        vm.startPrank(owner);
        arbSepoliaToken = new RebaseToken(INTEREST_RATE);

        arbSepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);

        arbSepoliaTokenPool = new RebaseTokenPool(
            IERC20(address(arbSepoliaToken)),
            new address[](0),
            arbSepoliaNetworkDetails.rmnProxyAddress,
            arbSepoliaNetworkDetails.routerAddress
        );

        _setupRoles(
            address(arbSepoliaToken), address(arbSepoliaTokenPool), arbSepoliaNetworkDetails
        );

        vm.stopPrank();

        _applyChainUpdates(
            sepoliaFork,
            address(sepoliaTokenPool),
            arbSepoliaNetworkDetails.chainSelector,
            address(arbSepoliaTokenPool),
            address(arbSepoliaToken)
        );
        _applyChainUpdates(
            arbSepoliaFork,
            address(arbSepoliaTokenPool),
            sepoliaNetworkDetails.chainSelector,
            address(sepoliaTokenPool),
            address(sepoliaToken)
        );
    }

    function testCrossChain() external {
        vm.selectFork(sepoliaFork);
        vm.deal(user, 100 ether);

        vm.prank(user);
        vault.deposit{ value: 20 ether }();

        _bridgeTokens(
            sepoliaFork,
            arbSepoliaFork,
            address(sepoliaToken),
            address(arbSepoliaToken),
            user,
            recevier,
            10 ether,
            sepoliaNetworkDetails,
            arbSepoliaNetworkDetails
        );
    }

    function _setupRoles(
        address token,
        address tokenPool,
        Register.NetworkDetails memory networkDetails
    ) private {
        IRebaseToken(token).grantMinterAndBurnerRole(tokenPool);

        RegistryModuleOwnerCustom(networkDetails.registryModuleOwnerCustomAddress)
            .registerAdminViaOwner(token);
        TokenAdminRegistry(networkDetails.tokenAdminRegistryAddress).acceptAdminRole(token);
        TokenAdminRegistry(networkDetails.tokenAdminRegistryAddress).setPool(token, tokenPool);
    }

    function _applyChainUpdates(
        uint256 fork,
        address tokenPool,
        uint64 remoteChainSelector,
        address remotePoolAddress,
        address remoteTokenAddress
    ) private {
        vm.selectFork(fork);

        bytes[] memory remotePoolAddresses = new bytes[](1);
        remotePoolAddresses[0] = abi.encode(remotePoolAddress);

        TokenPool.ChainUpdate[] memory chainsToAdd = new TokenPool.ChainUpdate[](1);

        chainsToAdd[0] = TokenPool.ChainUpdate({
            remoteChainSelector: remoteChainSelector,
            remotePoolAddresses: remotePoolAddresses,
            remoteTokenAddress: abi.encode(remoteTokenAddress),
            outboundRateLimiterConfig: RateLimiter.Config({ isEnabled: false, capacity: 0, rate: 0 }),
            inboundRateLimiterConfig: RateLimiter.Config({ isEnabled: false, capacity: 0, rate: 0 })
        });

        vm.prank(owner);
        RebaseTokenPool(tokenPool).applyChainUpdates(new uint64[](0), chainsToAdd);
    }

    function _bridgeTokens(
        uint256 localFork,
        uint256 remoteFork,
        address localToken,
        address remoteToken,
        address sender,
        address receiver,
        uint256 amountToBridge,
        Register.NetworkDetails memory localNetworkDetails,
        Register.NetworkDetails memory remoteNetworkDetails
    ) private {
        vm.selectFork(localFork);

        Client.EVM2AnyMessage memory evm2AnyMessage =
            _buildCCIPMessage(receiver, localToken, amountToBridge, localNetworkDetails.linkAddress);

        uint256 fees = IRouterClient(localNetworkDetails.routerAddress).getFee(
            remoteNetworkDetails.chainSelector, evm2AnyMessage
        );
        bool success = ccipLocalSimulatorFork.requestLinkFromFaucet(sender, fees);
        assert(success);

        vm.startPrank(sender);

        IERC20(localToken).approve(localNetworkDetails.routerAddress, amountToBridge);
        IERC20(localNetworkDetails.linkAddress).approve(
            localNetworkDetails.routerAddress, amountToBridge
        );

        vm.stopPrank();

        uint256 localTokenBalanceBefore = IERC20(localToken).balanceOf(sender);
        vm.prank(sender);
        bytes32 messageId = IRouterClient(localNetworkDetails.routerAddress).ccipSend(
            remoteNetworkDetails.chainSelector, evm2AnyMessage
        );
        uint256 localTokenBalanceAfter = IERC20(localToken).balanceOf(sender);

        assertEq(localTokenBalanceBefore - localTokenBalanceAfter, amountToBridge);

        vm.stopPrank();

        uint256 localInterestRate = IRebaseToken(localToken).getInterestRate();

        vm.selectFork(remoteFork);
        vm.warp(block.timestamp + 20 minutes);

        uint256 remoteBalanceBefore = IERC20(remoteToken).balanceOf(receiver);
        ccipLocalSimulatorFork.switchChainAndRouteMessage(remoteFork);
        uint256 remoteInterestRate = IRebaseToken(remoteToken).getInterestRate();
        uint256 remoteBalanceAfter = IERC20(remoteToken).balanceOf(receiver);

        assertEq(remoteBalanceAfter - remoteBalanceBefore, amountToBridge);
        assertEq(localInterestRate, remoteInterestRate);
    }

    function _buildCCIPMessage(
        address _receiver,
        address _token,
        uint256 _amount,
        address _feeTokenAddress
    ) private pure returns (Client.EVM2AnyMessage memory) {
        // Set the token amounts
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({ token: _token, amount: _amount });

        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        return Client.EVM2AnyMessage({
            receiver: abi.encode(_receiver), // ABI-encoded receiver address
            data: "", // No data
            tokenAmounts: tokenAmounts, // The amount and type of token being transferred
            extraArgs: Client._argsToBytes(
                // Additional arguments, setting gas limit and allowing out-of-order execution.
                // Best Practice: For simplicity, the values are hardcoded. It is advisable to use a more dynamic approach
                // where you set the extra arguments off-chain. This allows adaptation depending on the lanes, messages,
                // and ensures compatibility with future CCIP upgrades. Read more about it here: https://docs.chain.link/ccip/best-practices#using-extraargs
                Client.EVMExtraArgsV1({
                    gasLimit: 1_000_000 // Gas limit for the callback on the destination chain
                 })
            ),
            // Set the feeToken to a feeTokenAddress, indicating specific asset will be used for fees
            feeToken: _feeTokenAddress
        });
    }
}
