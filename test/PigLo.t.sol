// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {PigLo} from "../src/PigLo.sol";
import {CadenceRandomConsumer} from "../src/CadenceRandomConsumer.sol";

// Harness contract to expose internal functions for testing
contract PigLoHarness is PigLo {
    function getRequest(address user) public view returns (uint256) {
        return requests[user];
    }

    function clearRequest(address user) public {
        requests[user] = 0;
    }

    function getLastRand(address user) public view returns (uint8) {
        return resultRand[user];
    }

    function requestRandomness() public {
        _requestRandomness();
    }

    // Note that this consumes the request, which cannot be used again
    function fulfillRandomInRange(
        uint256 requestId,
        uint64 min,
        uint64 max
    ) public returns (uint64) {
        return _fulfillRandomInRange(requestId, min, max);
    }
}

contract PigLoTest is Test {
    PigLoHarness public pigLo;

    // address payable user1 = payable(address(100));
    address user1 = makeAddr("user");

    address private cadenceArch = 0x0000000000000000000000010000000000000001;
    uint64 mockFlowBlockHeight = 12345;
    bytes32 randSeed = 0xff00000000000000000000002200000000000000000000000000000000000001;

    function nextBlock(bytes32 seed) private {
        vm.mockCall(
            cadenceArch, 
            abi.encodeWithSignature("flowBlockHeight()"), 
            abi.encode(++mockFlowBlockHeight)
        );

        // update rand
        vm.mockCall(
            cadenceArch,
            abi.encodeWithSignature(
                "getRandomSource(uint64)",
                mockFlowBlockHeight
            ),
            abi.encode(
                seed
            )
        );
    }

    function setUp() public {
        pigLo = new PigLoHarness();

        nextBlock(randSeed);
    }

    function test_initial_state () public view {
        assertEq(pigLo.userScore(user1), 0, "incorrect initial score");
        assertEq(pigLo.targetNumber(user1), 0, "incorrect initial target");
        assertEq(pigLo.userChoice(user1), 0, "incorrect initial choice");        
    }

    function test_playRound () public {
        vm.prank(user1);
        pigLo.playRound(false);

        assertEq(pigLo.userChoice(user1), 1, "user selection not saved correctly");
        assertEq(pigLo.getRequest(user1), 1, "Wrong request ID"); // requests are sequential
    }

    /**
     * Verify expected "random" values in test.  These appear to be determined by calling sequence when using the same seed
     *  1, 7, 7, 1
     */
    function test_rand () public {
        vm.prank(user1);
        pigLo.playRound(false);

        nextBlock(randSeed);

        uint8 randResult = uint8(pigLo.fulfillRandomInRange(1, 1, 10)); // request ID 1, range [1-10]
        assertEq(randResult, 1, "Unexpected value for first rand request");///

        pigLo.clearRequest(user1);

        vm.prank(user1);
        pigLo.playRound(false);

        nextBlock(randSeed);

        randResult = uint8(pigLo.fulfillRandomInRange(2, 1, 10)); // request ID 2, range [1-10]
        assertEq(randResult, 7, "Unexpected value for second rand request");

        pigLo.clearRequest(user1);

        vm.prank(user1);
        pigLo.playRound(false);

        nextBlock(randSeed);

        randResult = uint8(pigLo.fulfillRandomInRange(3, 1, 10)); // request ID 3, range [1-10]
        assertEq(randResult, 8, "Unexpected value for third rand request");

        pigLo.clearRequest(user1);

        vm.prank(user1);
        pigLo.playRound(false);

        nextBlock(randSeed);

        randResult = uint8(pigLo.fulfillRandomInRange(4, 1, 10)); // request ID 4, range [1-10]
        assertEq(randResult, 1, "Unexpected value for fourth rand request");
    }


    function test_checkResults () public {
        vm.prank(user1);
        vm.expectEmit();
        emit PigLo.PlayRound(user1, 1, 5);/// 1 = low, 5 is starting target
        pigLo.playRound(false); // guess low

        assertEq(pigLo.targetNumber(user1), 5, "Unexpected starting target");
        assertEq(pigLo.getRequest(user1), 1, "Wrong request ID"); // requests are sequential

        nextBlock(randSeed); // results in rand value of 1

        vm.prank(user1);
        vm.expectEmit();
        emit PigLo.RoundFinished(user1, 1, 5, 1, false); // Score 1, target 5, new target 1, guessed lo
        pigLo.checkResults();

        assertEq(pigLo.targetNumber(user1), 1, "Unexpected new target");
        assertEq(pigLo.userScore(user1), 1, "user score incorrect, should be 1 now");

        // Second round
        vm.prank(user1);
        pigLo.playRound(true);

        assertEq(pigLo.userChoice(user1), 2, "user selection not saved correctly for second round");///

        // Use seed 2 to get a different result
        nextBlock(randSeed);  // results in rand value of 7

        vm.prank(user1);
        vm.expectEmit();
        emit PigLo.RoundFinished(user1, 2, 1, 7, true); // score 2, target 1, new target 7, guessed hi
        pigLo.checkResults();

        // Second round is a win, guessed Hi with 7 > 1
        assertEq(pigLo.userScore(user1), 2, "user score incorrect, should be 2 now");
    }

    function test_checkResults_failFirstGame () public {
        assertEq(pigLo.targetNumber(user1), 0, "Unexpected target");

        vm.prank(user1);
        pigLo.playRound(true);

        nextBlock(randSeed); // rand value 1 on first call

        vm.prank(user1);
        vm.expectEmit();
        emit PigLo.RoundFinished(user1, 0, 5, 0, true); // score 0, target 5, new target [deleted due to loss], selected lo
        pigLo.checkResults();

        // Failed first game, guessed Hi but 1 < 5
        assertEq(pigLo.userScore(user1), 0, "user score incorrect, should be 0 now");
    }


    function testFuzz_playGame (uint8 randPreSpin, bool guess) public {
        // Cycle through a number of previous requests to randomize our next one
        for(uint8 i; i < randPreSpin; i++) {
            pigLo.requestRandomness();
        }

        vm.prank(user1);
        pigLo.playRound(guess);

        nextBlock(randSeed);

        assertEq(pigLo.targetNumber(user1), 5, "Error, initial target not as expected");

        vm.prank(user1);
        pigLo.checkResults();

        uint8 lastRand = pigLo.getLastRand(user1);

        if (guess) {
             assertEq((lastRand >= 5 || pigLo.userScore(user1) == 0), true, "Failed fuzzy test when guessing hi");
        } else {
            assertEq((lastRand < 5 || pigLo.userScore(user1) == 0), true, "Failed fuzzy test when guessing lo");
        }
    }
}
