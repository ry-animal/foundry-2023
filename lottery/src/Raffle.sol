// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import { VRFCoordinatorV2Interface } from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import { VRFConsumerBaseV2 } from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import { AutomationCompatibleInterface } from "@chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";

/**
 * @title A sample Raffle Contract
 * @author ry-animal
 * @notice This contract is for creating sample raffle
 * @dev Implementing a raffle contract with Chainlink VRFv2
 */
contract Raffle is VRFConsumerBaseV2, AutomationCompatibleInterface {
    error Raffle__Inefficient_Entrance();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(
        uint256 balance,
        uint256 raffleState,
        uint256 participantsLength
    );

    /** Type Declarations */
    enum RaffleState {
        OPEN,
        CALCULATING_WINNER
    }

    /** State Variables */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    uint256 private immutable i_entranceFee;
    /**@dev Duration of the lottery in seconds */
    uint256 private immutable i_interval;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;

    address payable[] private s_participants;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    /** Events */
    event EnteredRaffle(address indexed participant);
    event PickedWinner(address indexed winner);
    
    constructor(
        uint256 entranceFee, 
        uint256 interval, 
        address vrfCoordinator, 
        bytes32 gasLane, 
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinator){
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_lastTimeStamp = block.timestamp;
    }

    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) revert Raffle__Inefficient_Entrance();
        if (s_raffleState != RaffleState.OPEN) revert Raffle__RaffleNotOpen();

        s_participants.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

/**
 * @dev This function is called by the Chainlink Keeper Network to determine if upkeep is needed
 * The time has passed between interval runs, raffle is in OPEN state, has ETH, sub is funded with LINK
 */
    function checkUpkeep(
        bytes memory /** checkData */
    ) public view returns(
        bool upkeepNeeded, bytes memory /** performData */
    ) {
        /**@dev block.timestamp vulnerabiltity? */
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasETH = address(this).balance > 0;
        bool hasPlayers = s_participants.length > 0;
        upkeepNeeded = timeHasPassed && isOpen && hasETH && hasPlayers;
        return (upkeepNeeded, "0x0");
    }

    function performUpkeep(bytes calldata /** performData */) public {
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded) revert Raffle__UpkeepNotNeeded(
            address(this).balance,
            uint256(s_raffleState),
            s_participants.length
        );
        s_raffleState = RaffleState.CALCULATING_WINNER;
        i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
    }

    function  fulfillRandomWords (
        uint256 /** requestId */,
        uint256[] memory randomWords
    ) internal override {
        uint256 winnerIndex = randomWords[0] % s_participants.length;
        address payable winner = s_participants[winnerIndex];
        s_recentWinner = winner;
        s_raffleState = RaffleState.OPEN;

        /** Reset Lottery */
        s_participants = new address payable[](0);
        s_lastTimeStamp = block.timestamp;

        (bool success,) = winner.call{value: address(this).balance}("");
        if(!success) revert Raffle__TransferFailed();
        emit PickedWinner(winner);
    }

    /** Getters */

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPaticipants(uint256 indexOfParticipant) external view returns (address) {
        return s_participants[indexOfParticipant];
    }
}