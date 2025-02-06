// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import { Test, console2 } from "forge-std/Test.sol";

import { CCIPLocalSimulatorFork } from "@chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import { Register } from "@chainlink-local/src/ccip/Register.sol";

import { IERC20 } from
    "@chainlink-contracts/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import { RegistryModuleOwnerCustom } from
    "@chainlink-contracts/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import { TokenAdminRegistry } from
    "@chainlink-contracts/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";
import { TokenPool } from "@chainlink-contracts/ccip/pools/TokenPool.sol";
import { RateLimiter } from "@chainlink-contracts/ccip/libraries/RateLimiter.sol";

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

        // sepoliaToken.grantMinterAndBurnerRole(address(sepoliaTokenPool));

        // RegistryModuleOwnerCustom(sepoliaNetworkDetails.registryModuleOwnerCustomAddress)
        //     .registerAdminViaOwner(address(sepoliaToken));
        // TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress).acceptAdminRole(
        //     address(sepoliaToken)
        // );
        // TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress).setPool(
        //     address(sepoliaToken), address(sepoliaTokenPool)
        // );

        vm.stopPrank();

        vm.selectFork(arbSepoliaFork);

        vm.startPrank(owner);
        arbSepoliaToken = new RebaseToken(INTEREST_RATE);

        arbSepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);

        arbSepoliaTokenPool = new RebaseTokenPool(
            IERC20(address(sepoliaToken)),
            new address[](0),
            arbSepoliaNetworkDetails.rmnProxyAddress,
            arbSepoliaNetworkDetails.routerAddress
        );

        _setupRoles(
            address(arbSepoliaToken), address(arbSepoliaTokenPool), arbSepoliaNetworkDetails
        );

        // arbSepoliaToken.grantMinterAndBurnerRole(address(arbSepoliaTokenPool));

        // RegistryModuleOwnerCustom(arbSepoliaNetworkDetails.registryModuleOwnerCustomAddress)
        //     .registerAdminViaOwner(address(arbSepoliaToken));
        // TokenAdminRegistry(arbSepoliaNetworkDetails.tokenAdminRegistryAddress).acceptAdminRole(
        //     address(arbSepoliaToken)
        // );
        // TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress).setPool(
        //     address(arbSepoliaToken), address(arbSepoliaTokenPool)
        // );
        vm.stopPrank();

        _applyChainUpdates(
            sepoliaFork,
            address(sepoliaTokenPool),
            sepoliaNetworkDetails.chainSelector,
            address(arbSepoliaTokenPool),
            address(arbSepoliaToken)
        );
        _applyChainUpdates(
            arbSepoliaFork,
            address(arbSepoliaTokenPool),
            arbSepoliaNetworkDetails.chainSelector,
            address(sepoliaTokenPool),
            address(sepoliaToken)
        );
    }

    function _setupRoles(
        address token,
        address tokenPool,
        Register.NetworkDetails memory networkDetails
    ) private {
        RebaseToken(token).grantMinterAndBurnerRole(tokenPool);

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
}
