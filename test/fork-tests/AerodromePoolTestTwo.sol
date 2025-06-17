// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {IUniswapV3Pool} from "../../contracts/interfaces/IUniswapV3Pool.sol";
import {UniswapTickMath} from "../../contracts/markets/lib/UniswapTickMath.sol";

contract AerodromeTWAPTestTwo is Test {
    // WETH/USDC pool address on Base Mainnet from networks.json
    address public constant POOL_ADDRESS = 0xb2cc224c1c9feE385f8ad6a55b4d94E92359DC59;
    // WETH and USDC addresses
    address public constant WETH = 0x4200000000000000000000000000000000000006;
    address public constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    // TWAP interval in seconds (e.g., 2 minutes)
    uint32 public constant TWAP_PERIOD = 120;

    uint256 mainnetFork;

    function setUp() public {
        mainnetFork = vm.createFork("mainnet", 31574198);
        vm.selectFork(mainnetFork);
        vm.warp(1732792829 + 3600);
    }

    // Fetches TWAP price of token0 in terms of token1 (e.g., WETH in USDC)
    function test_getTWAPPrice() public view {
        console2.log("=== TWAP Price Calculation ===");

        IUniswapV3Pool pool = IUniswapV3Pool(POOL_ADDRESS);

        // Check token order (WETH/USDC or USDC/WETH)
        address token0 = pool.token0();
        console2.log("Token0:", token0);
        console2.log("Token1:", pool.token1());

        // Call observe to get cumulative tick data
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = TWAP_PERIOD; // Start of interval
        secondsAgos[1] = 0; // Current block

        (int56[] memory tickCumulatives,) = pool.observe(secondsAgos);

        // Calculate average tick
        int56 tickCumulativesDelta = tickCumulatives[1] - tickCumulatives[0];
        int24 timeWeightedAverageTick = int24(tickCumulativesDelta / int56(uint56(TWAP_PERIOD)));
        console2.log("Average tick:", int256(timeWeightedAverageTick));

        // Convert tick to sqrtPriceX96
        uint160 sqrtPriceX96 = UniswapTickMath.getSqrtPriceAtTick(timeWeightedAverageTick);
        console2.log("Sqrt price X96:", sqrtPriceX96);

        // Using the UniswapTickMath library to get the price
        // For WETH/USDC pool where WETH is token0:
        // - sqrtPriceX96 represents sqrt(price) where price = token1/token0 = USDC/WETH
        // - To get WETH price in USDC, we need the token1/token0 ratio with decimal adjustment

        // Method 1: Using the library directly
        // Get raw price with full precision (1e18)
        uint256 rawPrice = UniswapTickMath.getRawPrice(pool, true, 1e18, TWAP_PERIOD);
        console2.log("Raw price from library (token0, 1e18):", rawPrice);

        // Since the raw price is token1/token0 (USDC/WETH) with 1e18 precision
        // and we need to account for decimal differences (WETH=18, USDC=6)
        // The actual WETH price in USDC = rawPrice * 10^(18-6) / 1e18
        uint256 wethPriceInUSDC = (rawPrice * 1e12) / 1e18;
        console2.log("WETH price in USDC:", wethPriceInUSDC);

        // Method 2: Direct calculation
        // When isToken0=true, getPriceFromSqrtPrice returns token1/token0 ratio
        uint256 priceRatio = UniswapTickMath.getPriceFromSqrtPrice(sqrtPriceX96, true, 1e18);
        console2.log("Price ratio (USDC/WETH with 1e18):", priceRatio);

        // Adjust for decimals: multiply by 10^(decimals0 - decimals1) = 10^(18-6) = 10^12
        uint256 adjustedPrice = (priceRatio * 1e12) / 1e18;
        console2.log("Adjusted WETH price in USDC:", adjustedPrice);

        // Method 3: Get price with USDC precision directly
        uint256 priceWithUSDCPrecision = UniswapTickMath.getPriceFromSqrtPrice(sqrtPriceX96, true, 1e6);
        console2.log("Price with USDC precision (raw):", priceWithUSDCPrecision);

        // The raw result is too small due to precision issues, so this approach doesn't work well
        console2.log("Method 3 doesn't work due to precision underflow");

        // Method 4: The correct approach that works
        // Use the same calculation as Method 1 and 2: (rawPrice * 1e12) / 1e18
        uint256 correctPrice = UniswapTickMath.getPriceFromSqrtPrice(sqrtPriceX96, true, 1e18);
        console2.log("Price with 1e18 precision (same as raw price):", correctPrice);

        // Apply the working formula: multiply by decimal difference, then divide by precision
        uint256 finalWorkingPrice = (correctPrice * 1e12) / 1e18;
        console2.log("Final WETH price using working formula:", finalWorkingPrice);

        // This should match our Method 1 result: 2528
        console2.log("All working methods show WETH price:", finalWorkingPrice, "USDC = $", finalWorkingPrice);
    }
}
