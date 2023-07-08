// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {Raffle} from "../src/Raffle.sol";
import {DevOpsTools} from "foundry-devops/DevOpsTools.sol";

contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint64) {
        HelperConfig helperConfig = new HelperConfig();
        (, , address vrfCoordinator, , , , ) = helperConfig.activeNetworkConfig();
        return createSubscription(vrfCoordinator);
    }

    function createSubscription(address vrfCoordinator) public returns (uint64) {
        console.log("Creating a subscription on chainid", block.chainid);
        vm.startBroadcast();
        uint64 subId = VRFCoordinatorV2Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();
        return subId;
    }

    function run() external returns (uint64) {
        return createSubscriptionUsingConfig();
    }

}


contract FundSubscription is Script {
    uint96 public constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        (, , address vrfCoordinator, ,uint64 subId, , address link) = helperConfig.activeNetworkConfig();
        fundSubscription(vrfCoordinator, subId, link);
    }

    function fundSubscription(address vrfCoordinator, uint64 subId, address link) public {
        console.log("Funding subscription:", subId);
        console.log("VRF Coordinator:", vrfCoordinator);
        console.log("ChainId:", block.chainid);

        if (block.chainid == 31337) {
            vm.startBroadcast();
            VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(subId, FUND_AMOUNT);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast();
            LinkToken(link).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subId));
            vm.stopBroadcast();
        }
    }

    function run() external {
        fundSubscriptionUsingConfig();
    }
}


contract AddConsumer is Script {
    function addConsumerUsingConfig(address raffle) public {
        HelperConfig helperConfig = new HelperConfig();
        (, , address vrfCoordinator, ,uint64 subId, , ) = helperConfig.activeNetworkConfig();
        addConsumer(vrfCoordinator, subId, raffle);
    }

    function addConsumer(address vrfCoordinator, uint64 subId, address raffle) public {
        console.log("Adding consumer:", raffle);
        console.log("SubId:", subId);
        console.log("vrfCoordinator:", vrfCoordinator);
        console.log("chainId:", block.chainid);

        vm.startBroadcast();
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(subId, raffle);
        vm.stopBroadcast();
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingConfig(mostRecentlyDeployed);
    }
}