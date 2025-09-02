// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "solmate/utils/FixedPointMathLib.sol";
import "@chainlink/shared/interfaces/AggregatorV3Interface.sol";
import "./PortfolioStructs.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

library PortfolioSwapLibrary {
    using FixedPointMathLib for uint256;

    error SwapFailed();

    function smartSwap(
        address _uniswapV3SwapRouter,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMinimum
    ) internal {
        ISwapRouter swapRouter = ISwapRouter(_uniswapV3SwapRouter);

        // Approve tokens
        IERC20(tokenIn).approve(address(swapRouter), amountIn);

        // Try different fee tiers - router will find best path
        uint24[3] memory feeTiers = [uint24(500), uint24(3000), uint24(10000)];

        for (uint256 i = 0; i < feeTiers.length; i++) {
            try swapRouter.exactInputSingle(
                ISwapRouter.ExactInputSingleParams({
                    tokenIn: tokenIn,
                    tokenOut: tokenOut,
                    fee: feeTiers[i],
                    recipient: address(this),
                    deadline: block.timestamp + 300,
                    amountIn: amountIn,
                    amountOutMinimum: amountOutMinimum,
                    sqrtPriceLimitX96: 0
                })
            ) {
                return; // Success!
            } catch {
                // Try next fee tier
                continue;
            }
        }

        revert SwapFailed();
    }
}
