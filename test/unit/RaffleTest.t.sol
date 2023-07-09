// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DeployRaffle, HelperConfig} from "script/DeployRaffle.s.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {Vm} from "forge-std/Vm.sol";
import {Winner} from "./Winner.sol";

contract RaffleTest is Test {
    /** Events */
    event EnteredRaffle(address indexed player);
    event PickedWinner(address indexed winner);

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
        console.log(PLAYER);
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
            link,
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

    function testCheckUpkeepReturnsFalseIfRaffleHasNoPlayers() external intervalPassed {
        vm.prank(PLAYER);
        address(raffle).call{value: entryFee}("");
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsTrueIfAllConditionsMet() external raffleEntered intervalPassed {
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(upkeepNeeded == true);
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
    modifier skipFork() {
        if (block.chainid != 31337) return;
        _;
    }


    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomRequestId
    ) external skipFork raffleEntered intervalPassed {
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    function testfulfillRandomWordsPickAWinnerResetsAndSendsMoney(
    ) external skipFork raffleEntered intervalPassed {
        // Arrange
        uint160 additionalEntrants = 5;
        uint160 startingIndex = 1;
        for (uint160 i=startingIndex; i<additionalEntrants+startingIndex; i++) {
            address player = address(i);
            hoax(player, STARTING_PLAYER_BALANCE);
            raffle.enterRaffle{value: entryFee}();
        }

        uint256 prizeMoney = entryFee * (additionalEntrants + 1);

        // Pretent to be vrf coordinator to get a random number and pick a winner
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();

        bytes32 requestId = entries[1].topics[1];

        uint256 previousTimeStamp = raffle.getLastTimeStamp();
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));
        Vm.Log[] memory newEntries = vm.getRecordedLogs();

        bytes32 winner = newEntries[0].topics[1];

        // Assert
        uint256 endingRaffleBalance = address(raffle).balance;

        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
        assert(address(uint160(uint256(winner))) != address(0));
        assert(raffle.getRecentWinner() != address(0));
        assert(raffle.getNumberOfPlayers() == 0);
        assert(raffle.getLastTimeStamp() > previousTimeStamp);
        assert(endingRaffleBalance == 0);
        assert(raffle.getRecentWinner().balance == prizeMoney - entryFee + STARTING_PLAYER_BALANCE);
    }

    function testFulfillRandomWordsRevertsIfTransferFailed() external skipFork {
        // Winner is a contract as a player that will reject second call value
        vm.startBroadcast();
        Winner winner = new Winner();
        vm.stopBroadcast();

        (bool success,) = address(winner).call{value: STARTING_PLAYER_BALANCE}("");
        console.log("Winner Balance:",address(winner).balance);
        vm.prank(address(winner));
        raffle.enterRaffle{value: entryFee}();

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        assert(raffle.getRecentWinner() == address(0));
    }

    function testReturnsTheCorrectEntryFee() external {
        assert(raffle.getEntryFee() == entryFee);
    }
}