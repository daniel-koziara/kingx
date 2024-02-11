// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

contract SwapHelper {
    IUniswapV2Router02 public immutable uniswapRouter;
    address public immutable WETH;
    address public constant TITANX = 0xF19308F923582A6f7c465e5CE7a9Dc1BEC6665B1;


    constructor(address _uniswapRouter, address _WETH) {
        uniswapRouter = IUniswapV2Router02(_uniswapRouter);
        WETH = _WETH;
    }

    function swapETHForTITANX() external payable {
        uint deadline = block.timestamp + 10 * 60;
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = TITANX;

        uniswapRouter.swapExactETHForTokens{value: msg.value}(
            0,
            path,
            msg.sender,
            deadline
        );
    }
}
