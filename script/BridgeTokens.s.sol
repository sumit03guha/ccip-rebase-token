// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import { Script, console2 } from "forge-std/Script.sol";

import { IRouterClient } from "@chainlink-contracts/ccip/interfaces/IRouterClient.sol";
import { Client } from "@chainlink-contracts/ccip/libraries/Client.sol";
import { IERC20 } from
    "@chainlink-contracts/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";

contract BridgeTokens is Script {
    function run(
        address tokenToBridge,
        uint256 amountToBridge,
        address receiver,
        uint64 destinationChainSelector,
        address routerAddress,
        address linkTokenAddress
    ) external {
        vm.startBroadcast();

        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({ token: tokenToBridge, amount: amountToBridge });

        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver), // ABI-encoded receiver address
            data: "", // No data
            tokenAmounts: tokenAmounts, // The amount and type of token being transferred
            extraArgs: Client._argsToBytes(
                // Additional arguments, setting gas limit and allowing out-of-order execution.
                // Best Practice: For simplicity, the values are hardcoded. It is advisable to use a more dynamic approach
                // where you set the extra arguments off-chain. This allows adaptation depending on the lanes, messages,
                // and ensures compatibility with future CCIP upgrades. Read more about it here: https://docs.chain.link/ccip/best-practices#using-extraargs
                Client.EVMExtraArgsV1({
                    gasLimit: 0 // Gas limit for the callback on the destination chain
                 })
            ),
            // Set the feeToken to a feeTokenAddress, indicating specific asset will be used for fees
            feeToken: linkTokenAddress
        });

        uint256 fees = IRouterClient(routerAddress).getFee(destinationChainSelector, evm2AnyMessage);

        IERC20(tokenToBridge).approve(routerAddress, amountToBridge);
        IERC20(linkTokenAddress).approve(routerAddress, fees);

        bytes32 messageId =
            IRouterClient(routerAddress).ccipSend(destinationChainSelector, evm2AnyMessage);

        console2.log("CCIP Message ID : ", vm.toString(messageId));

        vm.stopBroadcast();
    }
}
