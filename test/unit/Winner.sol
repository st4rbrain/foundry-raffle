// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Raffle} from "src/Raffle.sol";

contract Winner {
    uint256 private counter;

    receive() external payable {
        if (counter != 0) {
            revert Raffle.Raffle__TransferFailed();
        }
        counter += 1;
    }
}
