// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/* =========================================================
                    MOCK PANCAKE ROUTER
   =========================================================
   - Accepts ETH
   - Emits event instead of real swap
   - Used ONLY for testing buyback success path
   ========================================================= */

contract MockRouter {
    event SwapExecuted(
        uint256 amountIn,
        address[] path,
        address to
    );

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable {
        // silence unused warnings
        amountOutMin;
        deadline;

        emit SwapExecuted(msg.value, path, to);
    }
}
