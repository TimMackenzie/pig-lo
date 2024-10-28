// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {CadenceRandomConsumer} from "./CadenceRandomConsumer.sol";
import {console} from "forge-std/Test.sol";

/**
 * @dev Demonstrate Flow EVM's native secure randomness with a simple game inspired by Hi-Lo and Pig
 * 
 *  Initial target is 5, and user guesses if next random number will be higher or lower (range [1-10]).
 *  Upon winning, user gains a point and new target is the newly generated random number.
 *  Upon losing, user score is reset and target is 5 again.
 */
contract PigLo is CadenceRandomConsumer {
    // use uint to disambiguate between false and not set
    uint8 private constant VALUE_LO = 1;
    uint8 private constant VALUE_HI = 2;

    uint8 private constant STARTING_TARGET = 5;

    // Highest score achieved by each player
    mapping(address => uint8) public userScore;
    
    // Next number to bet against
    mapping(address => uint8) public targetNumber;

    // User selection in ongoing round
    mapping(address => uint8) public userChoice;

    // Even if target is deleted due to loss, it will be stored here for diagnostics
    mapping(address => uint8) internal resultRand;

    // Store requests for random numbers
    mapping(address => uint256) internal requests;

    event PlayRound(address indexed user, uint8 indexed choice, uint8 indexed target);
    event RoundFinished(address indexed user, uint8 indexed score, uint8 target, uint8 result, bool selection);

    /**
     * User initiates bet by picking false for low or true for high
     */
    function playRound(bool choice) public {
        require(requests[msg.sender] == 0, "Round already started");

        // If this is the first round and a target hasn't been set, use the starting target
        if (targetNumber[msg.sender] == 0) {
            targetNumber[msg.sender] = STARTING_TARGET;
        }

        // request a new random
        uint256 requestId = _requestRandomness();
        requests[msg.sender] = requestId;

        uint8 choiceInt = choice ? VALUE_HI : VALUE_LO;

        userChoice[msg.sender] = choiceInt;
        
        emit PlayRound(msg.sender, choiceInt, targetNumber[msg.sender]);
    }

    function checkResults() public {
        require(requests[msg.sender] != 0, "Round not yet started");

        uint8 originalTarget = targetNumber[msg.sender];

        uint256 requestId = requests[msg.sender];
        delete requests[msg.sender];
        uint8 randResult = uint8(_fulfillRandomInRange(requestId, 1, 10));

        // Store last result independently of new target, for diagnostic purposes
        resultRand[msg.sender] = randResult;

        bool isHi = randResult >= originalTarget;

        bool win = (userChoice[msg.sender] == VALUE_HI) ? isHi : !isHi;

        if (win) {
            userScore[msg.sender]++;
            targetNumber[msg.sender] = randResult;
        } else {
            userScore[msg.sender] = 0;
            delete targetNumber[msg.sender];
        }

        emit RoundFinished(msg.sender, userScore[msg.sender], originalTarget, targetNumber[msg.sender], (userChoice[msg.sender] == VALUE_HI));
        delete userChoice[msg.sender];
    }
}