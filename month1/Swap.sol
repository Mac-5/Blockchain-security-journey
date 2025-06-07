// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Swap {
    uint256 public tokenBalance = 10000 * 10 ** 18; // 10,000 tokens
    uint256 public ethBalance = 100 ether;

    function swapETHForTokens(uint256 minTokens) external payable {
        require(msg.value > 0, "Must send ETH");
        // Dynamic price: tokens = (msg.value * tokenBalance) / ethBalance
        uint256 tokensToSend = (msg.value * tokenBalance) / ethBalance;
        require(tokensToSend >= minTokens, "Insufficient tokens received");
        require(tokenBalance >= tokensToSend, "Insufficient tokens");

        tokenBalance -= tokensToSend;
        ethBalance += msg.value;
        // Assume tokens are transferred (simplified for demo)
    }

    function getTokensForETH(
        uint256 ethAmount
    ) external view returns (uint256) {
        return (ethAmount * tokenBalance) / ethBalance;
    }
}
