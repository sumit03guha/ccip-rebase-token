// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import { Script } from "forge-std/Script.sol";

import { IERC20 } from
    "@chainlink-contracts/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import { CCIPLocalSimulatorFork } from "@chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import { Register } from "@chainlink-local/src/ccip/Register.sol";
import { RegistryModuleOwnerCustom } from
    "@chainlink-contracts/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import { TokenAdminRegistry } from
    "@chainlink-contracts/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";

import { IRebaseToken } from "../src/interfaces/IRebaseToken.sol";
import { Vault } from "../src/Vault.sol";
import { RebaseTokenPool } from "../src/RebaseTokenPool.sol";
import { RebaseToken } from "../src/RebaseToken.sol";
import { INTEREST_RATE } from "../src/Constants.sol";

contract DeployVault is Script {
    function run(address rebaseToken) external returns (Vault vault) {
        vm.startBroadcast();

        vault = new Vault(IRebaseToken(rebaseToken));
        IRebaseToken(rebaseToken).grantMinterAndBurnerRole(address(vault));

        vm.stopBroadcast();
    }
}

contract DeployTokenAndTokenPool is Script {
    function run() external returns (RebaseToken rebaseToken, RebaseTokenPool rebaseTokenPool) {
        vm.startBroadcast();

        rebaseToken = new RebaseToken(INTEREST_RATE);

        CCIPLocalSimulatorFork ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();

        Register.NetworkDetails memory networkDetails =
            ccipLocalSimulatorFork.getNetworkDetails(block.chainid);

        rebaseTokenPool = new RebaseTokenPool(
            IERC20(address(rebaseToken)),
            new address[](0),
            networkDetails.rmnProxyAddress,
            networkDetails.routerAddress
        );

        rebaseToken.grantMinterAndBurnerRole(address(rebaseTokenPool));

        RegistryModuleOwnerCustom(networkDetails.registryModuleOwnerCustomAddress)
            .registerAdminViaOwner(address(rebaseToken));
        TokenAdminRegistry(networkDetails.tokenAdminRegistryAddress).acceptAdminRole(
            address(rebaseToken)
        );
        TokenAdminRegistry(networkDetails.tokenAdminRegistryAddress).setPool(
            address(rebaseToken), address(rebaseTokenPool)
        );

        vm.stopBroadcast();
    }
}
