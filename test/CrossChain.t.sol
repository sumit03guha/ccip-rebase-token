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

import { IRebaseToken } from "../src/interfaces/IRebaseToken.sol";
import { RebaseToken } from "../src/RebaseToken.sol";
import { Vault } from "../src/Vault.sol";
import { RebaseTokenPool } from "../src/RebaseTokenPool.sol";
import { Deposit, Redeem, InterestRateSet } from "../src/Events.sol";

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
        sepoliaToken = new RebaseToken();

        sepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);

        sepoliaTokenPool = new RebaseTokenPool(
            IERC20(address(sepoliaToken)),
            new address[](0),
            sepoliaNetworkDetails.rmnProxyAddress,
            sepoliaNetworkDetails.routerAddress
        );

        vault = new Vault(IRebaseToken(address(sepoliaToken)));

        sepoliaToken.grantMinterAndBurnerRole(address(sepoliaTokenPool));
        sepoliaToken.grantMinterAndBurnerRole(address(vault));

        RegistryModuleOwnerCustom(sepoliaNetworkDetails.registryModuleOwnerCustomAddress)
            .registerAdminViaOwner(address(sepoliaToken));
        TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress).acceptAdminRole(
            address(sepoliaToken)
        );
        TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress).setPool(
            address(sepoliaToken), address(sepoliaTokenPool)
        );

        vm.stopPrank();

        vm.selectFork(arbSepoliaFork);

        vm.startPrank(owner);
        arbSepoliaToken = new RebaseToken();

        arbSepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);

        arbSepoliaTokenPool = new RebaseTokenPool(
            IERC20(address(sepoliaToken)),
            new address[](0),
            arbSepoliaNetworkDetails.rmnProxyAddress,
            arbSepoliaNetworkDetails.routerAddress
        );

        arbSepoliaToken.grantMinterAndBurnerRole(address(arbSepoliaTokenPool));

        RegistryModuleOwnerCustom(arbSepoliaNetworkDetails.registryModuleOwnerCustomAddress)
            .registerAdminViaOwner(address(arbSepoliaToken));
        TokenAdminRegistry(arbSepoliaNetworkDetails.tokenAdminRegistryAddress).acceptAdminRole(
            address(arbSepoliaToken)
        );
        TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress).setPool(
            address(arbSepoliaToken), address(arbSepoliaTokenPool)
        );

        vm.stopPrank();
    }
}
