// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

error Raffle__NotEnoughEthSent();
error Raffle__NotOwner();

contract Raffle {
    uint256 private immutable i_entryFee;
    //@dev duration of the lottery in seconds
    uint256 private immutable i_interval;
    uint256 private s_lastTimeStamp;
    address private immutable i_owner;

    /**
     * Events
     */
    event EnteredRaffle(address indexed player);

    constructor(uint256 entryFee, uint256 interval) {
        i_entryFee = entryFee;
        i_interval = interval;
        i_owner = msg.sender;
        s_lastTimeStamp = block.timestamp;
    }

    /**
     * Modifiers
     */
    modifier onlyOwner() {
        if (msg.sender != i_owner) {
            revert Raffle__NotOwner();
        }
        _;
    }


    function enterRaffle() external payable {
        if (msg.value < i_entryFee) {
            revert Raffle__NotEnoughEthSent();
        }

        emit EnteredRaffle(msg.sender);
    }

    // @dev Use a random number to pick the winner
    function pickWinner() external view {
        if ((block.timestamp - s_lastTimeStamp) < i_interval) {
            revert();
        }
    }

    /**
     * Getter Functions
     */
    function getEntryFee() external view returns (uint256) {
        return i_entryFee;
    }
}
