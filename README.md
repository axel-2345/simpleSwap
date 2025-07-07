# simpleSwap

A minimalistic Solidity smart contract for swapping ERC20 tokens and providing liquidity, inspired by automated market makers (AMMs) like Uniswap V2. `SimpleSwap` allows users to add liquidity, remove liquidity, and swap tokens between any two ERC20 tokens using a shared reserve pool. Liquidity providers receive an LP (Liquidity Provider) token representing their share in the pool.

## Features

- **Add Liquidity**: Supply two ERC20 tokens to create or grow a pool, and receive LP tokens.
- **Remove Liquidity**: Burn LP tokens to redeem the underlying ERC20 assets from a pool.
- **Swap Tokens**: Swap an exact amount of one ERC20 token for another using the pool reserves.
- **View Prices & Quotes**: Query current pool prices and estimate swap outcomes before executing them.
- **Slippage Control**: All operations accept minimum output parameters to protect against price slippage.
- **Order-Invariant Pools**: Pools are indexed by ordered token pairs to avoid duplicate storage.

## How It Works

- Pools are created and managed for each unique pair of ERC20 tokens.
- Liquidity providers receive LP tokens (ERC20) in proportion to their contribution.
- Swaps are priced using the constant-product formula: `output = (input * reserveOut) / (reserveIn + input)`
- All transfers use the standard ERC20 interface.
- No fees or advanced routing — this is a minimal example for educational or prototyping purposes.

## Contract Overview

### Constructor

```solidity
constructor() ERC20("LP Token", "LPT")
```

Initializes the contract and the LP token (ERC20 with symbol "LPT").

---

### `addLiquidity`

Adds liquidity to a pool of two ERC20 tokens.

```solidity
function addLiquidity(
    address tokenA,
    address tokenB,
    uint256 amountADesired,
    uint256 amountBDesired,
    uint256 amountAMin,
    uint256 amountBMin,
    address to,
    uint256 deadlineSeconds
) external returns (uint256 amountA, uint256 amountB, uint256 liquidity)
```

- **Parameters**:
  - `tokenA`, `tokenB`: ERC20 token addresses.
  - `amountADesired`, `amountBDesired`: Amounts to add.
  - `amountAMin`, `amountBMin`: Minimum accepted amounts (slippage control).
  - `to`: Recipient of LP tokens.
  - `deadlineSeconds`: Operation expiry in seconds from the current block time.

---

### `removeLiquidity`

Removes liquidity from a pool and returns underlying tokens.

```solidity
function removeLiquidity(
    address tokenA,
    address tokenB,
    uint256 liquidityAmount,
    uint256 amountAMin,
    uint256 amountBMin,
    address to,
    uint256 deadlineSeconds
) external returns (uint256 amountA, uint256 amountB)
```

- **Parameters**:
  - `liquidityAmount`: Amount of LP tokens to burn.
  - Tokens and slippage controls as in `addLiquidity`.

---

### `swapExactTokensForTokens`

Swaps an exact amount of one token for another.

```solidity
function swapExactTokensForTokens(
    address tokenIn,
    address tokenOut,
    uint256 amountIn,
    uint256 amountOutMin,
    address to,
    uint256 deadlineSeconds
) external returns (uint256 amountOut)
```

- **Parameters**:
  - `tokenIn`, `tokenOut`: ERC20 token addresses.
  - `amountIn`: Amount of input tokens to swap.
  - `amountOutMin`: Minimum output tokens acceptable.
  - `to`: Recipient of output tokens.
  - `deadlineSeconds`: Operation expiry.

---

### `getPrice`

Returns the price ratio between two tokens in the pool.

```solidity
function getPrice(address tokenA, address tokenB) public view returns (uint256 priceAtoB, uint256 priceBtoA)
```

- **Returns**: Prices with 18 decimals precision.

---

### `getAmountOut`

Calculates expected output tokens for a given input.

```solidity
function getAmountOut(uint256 amountIn, address tokenIn, address tokenOut) public view returns (uint256 amountOut)
```

---

## Internal Math

- Uses a `sqrt` function (Newton-Raphson) for calculating pool shares.

---


## Example Usage

1. **Add Liquidity**:  
   Call `addLiquidity` with approved tokens to receive LP tokens.
2. **Swap Tokens**:  
   Call `swapExactTokensForTokens` with the token you want to exchange.
3. **Remove Liquidity**:  
   Call `removeLiquidity` and provide LP tokens to redeem your share.

## Requirements

- Solidity >=0.8.2 <0.9.0
- OpenZeppelin Contracts (ERC20)

## License

MIT
