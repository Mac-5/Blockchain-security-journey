// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Swap} from "../src/Swap.sol";

contract SwapTest is Test {
    Swap public swap;
    address user = makeAddr("userA");
    address attacker = makeAddr("userB");

    function setUp() public {
        swap = new Swap();
        vm.deal(user, 10 ether); // Give userA 10 ETH
        vm.deal(attacker, 10 ether); // Give userB 10 ETH
    }

    function testFrontrunningCausesSlippage() public {
        uint amountToSwap = 1 ether;
        uint expectedTokensBefore = (amountToSwap * swap.tokenBalance()) /
            swap.ethBalance();
        vm.prank(attacker);
        swap.swapETHForTokens{value: 0.1 ether}(0);

        vm.startPrank(user);
        vm.expectRevert("Insufficient tokens received");
        swap.swapETHForTokens{value: amountToSwap}(expectedTokensBefore);
        vm.stopPrank();
    }
}
