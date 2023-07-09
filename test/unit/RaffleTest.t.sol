// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DeployRaffle, HelperConfig} from "script/DeployRaffle.s.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {Vm} from "forge-std/Vm.sol";

contract RaffleTest is Test {
    /** Events */
    event EnteredRaffle(address indexed player);

    Raffle raffle;
    HelperConfig raffleConfig;
    VRFCoordinatorV2Mock vrfCoordinatorMock;

    address private PLAYER = makeAddr("player");
    uint256 private constant STARTING_PLAYER_BALANCE = 10 ether;

    uint256 entryFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address link;

    modifier raffleEntered() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entryFee}();
        _;
    }

    modifier intervalPassed() {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, raffleConfig) = deployRaffle.run();

        (   
            entryFee,
            interval,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            callbackGasLimit,
            link
        ) = raffleConfig.activeNetworkConfig();
        vrfCoordinatorMock = VRFCoordinatorV2Mock(vrfCoordinator);
        // Transfer some eth to the player
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
    }

    function testRaffleInitializedInOpenState() external view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    //////////////////
    // Enter Raffle //
    /////////////////
    function testRaffleEntryRevertsOnNotPayingEntryFee() external {
        vm.startPrank(PLAYER);
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);
        raffle.enterRaffle();
        vm.stopPrank();
    }

    function testRaffleRecordsPlayersWhenTheyEnter() external raffleEntered {
        assertEq(PLAYER, raffle.getPlayer(0));
    }

    function testEmitsEventOnPlayerEntrance() external {
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffle));

        emit EnteredRaffle(PLAYER);
        raffle.enterRaffle{value: entryFee}();
    }

    function testCantEnterWhenRaffleIsCalculating() external raffleEntered intervalPassed {
        uint64 subId = vrfCoordinatorMock.createSubscription();
        vrfCoordinatorMock.addConsumer(subId, address(raffle));

        raffle.performUpkeep("");
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        raffle.enterRaffle{value: entryFee}();
    }

    //////////////////
    // Check Upkeep //
    //////////////////
    function testCheckUpkeepReturnsFalseIfItHasNoBalance() external intervalPassed {
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleNotOpen() external raffleEntered intervalPassed {
        raffle.performUpkeep("");
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfIntervalNotComplete() external raffleEntered {
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }


    ////////////////////
    // Perform Upkeep //
    ////////////////////
    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() external {
        uint256 currentBalance = 0;
        uint256 numberOfPlayers = 0;
        uint256 raffleState = 0;
        vm.prank(PLAYER);
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                raffleState,
                currentBalance,
                numberOfPlayers
            )
        );
        raffle.performUpkeep("");
    }
    
    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId() external raffleEntered intervalPassed {
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();

        bytes32 requestId = entries[1].topics[1];

        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256(raffleState) == 1);
        assert(uint256(requestId) > 0);
    }

    /////////////////////////
    // fulfillRandomWords //
    ////////////////////////
    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomRequestId
    ) external raffleEntered intervalPassed {
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }


}