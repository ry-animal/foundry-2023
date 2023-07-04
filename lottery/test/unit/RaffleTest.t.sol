// SPDX-License-Identifier: MIT

import { Test, console } from "forge-std/Test.sol";
import { DeployRaffle } from "../../script/DeployRaffle.s.sol";
import { Raffle } from "../../src/Raffle.sol";
import { HelperConfig } from "../../script/HelperConfig.s.sol";

pragma solidity ^0.8.18;

contract RaffleTest is Test {
    Raffle raffle;
    HelperConfig helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;

    address public PLAYER = makeAddr("PLAYER");
    uint256 public constant STARTING_BAL = 10 ether;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();
        (
            entranceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            callbackGasLimit
        ) = helperConfig.activeNetworkConfig();
        vm.deal(PLAYER, STARTING_BAL);
    }

    function testRaffleInitInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    /**              */
    /*  Entry Tests  */
    /**              */

    function testRaffleRevertsWhenNotEnough() public {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__Inefficient_Entrance.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayerWhenEntered() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        address playerRecorded = raffle.getPaticipants(0);
        assertEq(playerRecorded, PLAYER);
    }

    // function testEmitsEventOnEntrance() public {
    //     vm.prank(PLAYER);
    // }
}