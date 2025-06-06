// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import {Auction} from "../src/Auction.sol";

import {Test} from "forge-std/Test.sol";

contract AuctionTest is Test {
    Auction public auction;
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        auction = new Auction(86400);

        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
    }

    function testFrontrunningAttack() public {
        // Simulate Alice placing a legitimate bid of 1 ETH
        vm.prank(alice);
        auction.bid{value: 1 ether}();

        // Simulate Bob front-running with a higher bid of 2 ETH
        vm.prank(bob);
        auction.bid{value: 1.1 ether}();

        // Assertions
        assertEq(
            auction.highestBidder(),
            bob,
            "Bob should be the highest bidder"
        );
        assertEq(
            auction.highestBid(),
            1.1 ether,
            "Highest bid should be 1.1 ETH"
        );
    }
}
