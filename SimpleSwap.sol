// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title SimpleSwap
 * @notice Enables adding liquidity, removing liquidity, and swapping ERC20 tokens via reserve pools.
 * @dev Uses ordered token pairs (tokenLower, tokenUpper) to avoid duplicate pool storage.
 */
contract SimpleSwap is ERC20 {
    /**
     * @dev Structure to store reserves for each pool of two tokens.
     * @param reserveA Reserve of the first token in the ordered pair.
     * @param reserveB Reserve of the second token in the ordered pair.
     */
    struct Reserve {
        uint256 reserveA;
        uint256 reserveB;
    }

    /// @notice Mapping to store pools by ordered token pairs.
    mapping(address => mapping(address => Reserve)) public pools;

    /**
     * @notice Constructor initializing the liquidity provider (LP) token.
     */
    constructor() ERC20("LP Token", "LPT") {}

    /**
     * @notice Adds liquidity to a pool of two tokens.
     * @param tokenA Address of the first token.
     * @param tokenB Address of the second token.
     * @param amountADesired Desired amount of tokenA to add.
     * @param amountBDesired Desired amount of tokenB to add.
     * @param amountAMin Minimum accepted amount of tokenA (slippage control).
     * @param amountBMin Minimum accepted amount of tokenB (slippage control).
     * @param to Address to receive the liquidity tokens (LPT).
     * @param deadlineSeconds Number of seconds from the current block timestamp during which the operation is valid.
     * @return amountA Final amount of tokenA added.
     * @return amountB Final amount of tokenB added.
     * @return liquidity Amount of liquidity tokens minted.
     */
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadlineSeconds
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        uint256 deadlineTimestamp = block.timestamp + deadlineSeconds;
        require(block.timestamp <= deadlineTimestamp, "Expired");

        // Orders tokens to avoid duplicate pools in the mapping
        (address tokenLower, address tokenUpper) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        Reserve storage pool = pools[tokenLower][tokenUpper];

        if (pool.reserveA == 0 && pool.reserveB == 0) {
            amountA = amountADesired;
            amountB = amountBDesired;
        } else {
            uint256 optimalB = (amountADesired * pool.reserveB) / pool.reserveA;
            if (optimalB <= amountBDesired) {
                amountA = amountADesired;
                amountB = optimalB;
            } else {
                amountB = amountBDesired;
                amountA = (amountBDesired * pool.reserveA) / pool.reserveB;
            }
        }

        require(amountA >= amountAMin && amountB >= amountBMin, "Slippage too high");

        ERC20(tokenA).transferFrom(msg.sender, address(this), amountA);
        ERC20(tokenB).transferFrom(msg.sender, address(this), amountB);

        pool.reserveA += amountA;
        pool.reserveB += amountB;

        liquidity = sqrt(amountA * amountB);
        _mint(to, liquidity);
    }

    /**
     * @notice Removes liquidity from a pool, returning the underlying tokens.
     * @param tokenA Address of the first token.
     * @param tokenB Address of the second token.
     * @param liquidityAmount Amount of liquidity tokens to burn.
     * @param amountAMin Minimum accepted amount of tokenA.
     * @param amountBMin Minimum accepted amount of tokenB.
     * @param to Address to receive the withdrawn tokens.
     * @param deadlineSeconds Number of seconds from the current block timestamp during which the operation is valid.
     * @return amountA Amount of tokenA withdrawn.
     * @return amountB Amount of tokenB withdrawn.
     */
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidityAmount,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadlineSeconds
    ) external returns (uint256 amountA, uint256 amountB) {
        uint256 deadlineTimestamp = block.timestamp + deadlineSeconds;
        require(block.timestamp <= deadlineTimestamp, "Expired");

        (address tokenLower, address tokenUpper) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        Reserve storage pool = pools[tokenLower][tokenUpper];

        uint256 totalLPSupply = totalSupply();
        require(liquidityAmount > 0 && balanceOf(msg.sender) >= liquidityAmount, "Insufficient liquidity");

        amountA = (liquidityAmount * pool.reserveA) / totalLPSupply;
        amountB = (liquidityAmount * pool.reserveB) / totalLPSupply;

        require(amountA >= amountAMin && amountB >= amountBMin, "Slippage too high");

        _burn(msg.sender, liquidityAmount);

        pool.reserveA -= amountA;
        pool.reserveB -= amountB;

        ERC20(tokenA).transfer(to, amountA);
        ERC20(tokenB).transfer(to, amountB);
    }

    /**
     * @notice Swaps an exact amount of tokenIn for tokenOut.
     * @param tokenIn Address of the token to send.
     * @param tokenOut Address of the token to receive.
     * @param amountIn Amount of tokenIn to swap.
     * @param amountOutMin Minimum amount of tokenOut accepted (slippage control).
     * @param to Address to receive tokenOut.
     * @param deadlineSeconds Number of seconds from the current block timestamp during which the operation is valid.
     * @return amountOut Amount of tokenOut received.
     */
    function swapExactTokensForTokens(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        address to,
        uint256 deadlineSeconds
    ) external returns (uint256 amountOut) {
        uint256 deadlineTimestamp = block.timestamp + deadlineSeconds;
        require(block.timestamp <= deadlineTimestamp, "Expired");
        require(tokenIn != tokenOut, "Invalid token pair");

        (address tokenLower, address tokenUpper) = tokenIn < tokenOut ? (tokenIn, tokenOut) : (tokenOut, tokenIn);
        Reserve storage pool = pools[tokenLower][tokenUpper];
        require(pool.reserveA > 0 && pool.reserveB > 0, "Empty pool");

        (uint256 reserveIn, uint256 reserveOut) = tokenIn < tokenOut
            ? (pool.reserveA, pool.reserveB)
            : (pool.reserveB, pool.reserveA);

        amountOut = (amountIn * reserveOut) / (reserveIn + amountIn);

        require(amountOut >= amountOutMin, "Insufficient output amount");

        ERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        ERC20(tokenOut).transfer(to, amountOut);

        if (tokenIn < tokenOut) {
            pool.reserveA += amountIn;
            pool.reserveB -= amountOut;
        } else {
            pool.reserveB += amountIn;
            pool.reserveA -= amountOut;
        }
    }

    /**
     * @notice Gets the relative price between two tokens in a pool.
     * @param tokenA Address of the first token.
     * @param tokenB Address of the second token.
     * @return priceAtoB Price of A in terms of B (with 18 decimals).
     * @return priceBtoA Price of B in terms of A (with 18 decimals).
     */
    function getPrice(
        address tokenA,
        address tokenB
    ) public view returns (uint256 priceAtoB, uint256 priceBtoA) {
        require(tokenA != tokenB, "Invalid pair");

        (address tokenLower, address tokenUpper) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        Reserve storage pool = pools[tokenLower][tokenUpper];
        require(pool.reserveA > 0 && pool.reserveB > 0, "Empty pool");

        if (tokenA < tokenB) {
            priceAtoB = (pool.reserveB * 1e18) / pool.reserveA;
            priceBtoA = (pool.reserveA * 1e18) / pool.reserveB;
        } else {
            priceAtoB = (pool.reserveA * 1e18) / pool.reserveB;
            priceBtoA = (pool.reserveB * 1e18) / pool.reserveA;
        }
    }

    /**
     * @notice Calculates the output amount of tokenOut given an input amount of tokenIn.
     * @param amountIn Amount of tokenIn to swap.
     * @param tokenIn Address of the token to send.
     * @param tokenOut Address of the token to receive.
     * @return amountOut Calculated amount of tokenOut.
     */
    function getAmountOut(
        uint256 amountIn,
        address tokenIn,
        address tokenOut
    ) public view returns (uint256 amountOut) {
        require(tokenIn != tokenOut, "Invalid pair");

        (address tokenLower, address tokenUpper) = tokenIn < tokenOut ? (tokenIn, tokenOut) : (tokenOut, tokenIn);
        Reserve storage pool = pools[tokenLower][tokenUpper];
        require(pool.reserveA > 0 && pool.reserveB > 0, "Empty pool");

        (uint256 reserveIn, uint256 reserveOut) = tokenIn < tokenOut
            ? (pool.reserveA, pool.reserveB)
            : (pool.reserveB, pool.reserveA);

        amountOut = (amountIn * reserveOut) / (reserveIn + amountIn);
    }

    /**
     * @notice Calculates the square root of a number.
     * @dev Uses the Newton-Raphson approximation method.
     * @param x Input number.
     * @return y Square root of x.
     */
    function sqrt(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}
