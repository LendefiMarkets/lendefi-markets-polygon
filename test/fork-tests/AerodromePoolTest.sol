// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {IUniswapV3Pool} from "../../contracts/interfaces/IUniswapV3Pool.sol";
import {UniswapTickMath} from "../../contracts/markets/lib/UniswapTickMath.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@uniswap/v4-core/src/libraries/FixedPoint96.sol";

contract AerodromeTWAP is Test {
    // WETH/USDC pool address on Base Mainnet from networks.json
    address public constant POOL_ADDRESS = 0xb2cc224c1c9feE385f8ad6a55b4d94E92359DC59;
    // WETH and USDC addresses
    address public constant WETH = 0x4200000000000000000000000000000000000006;
    address public constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    // TWAP interval in seconds (e.g., 1 minute)
    uint32 public constant TWAP_PERIOD = 120;

    uint256 mainnetFork;

    function setUp() public {
        mainnetFork = vm.createFork("mainnet", 31574198);
        vm.selectFork(mainnetFork);
        vm.warp(1732792829 + 3600);
    }

    function test_getTWAPPrice() public view {
        console2.log("=== TWAP Price Calculation Debug ===");

        IUniswapV3Pool pool = IUniswapV3Pool(POOL_ADDRESS);

        // Get pool tokens
        address token0 = pool.token0();
        address token1 = pool.token1();
        console2.log("Token0:", token0);
        console2.log("Token1:", token1);
        console2.log("WETH:", WETH);
        console2.log("USDC:", USDC);

        // Determine if WETH is token0
        bool isWETHToken0 = (token0 == WETH);
        console2.log("Is WETH token0:", isWETHToken0);

        // Check decimals
        uint8 token0Decimals = IERC20Metadata(token0).decimals();
        uint8 token1Decimals = IERC20Metadata(token1).decimals();
        console2.log("Token0 decimals:", token0Decimals);
        console2.log("Token1 decimals:", token1Decimals);

        // This is a stable pool since USDC has 6 decimals
        bool isStablePool = (token0Decimals == 6 || token1Decimals == 6);
        console2.log("Is stable pool (has 6-decimal token):", isStablePool);

        // Test using the same logic as getAnyPoolTokenPriceInUSD
        if (isStablePool) {
            console2.log("--- Processing as stable pool (has USDC) ---");

            // For WETH in this stable pool, get direct price using WETH's decimals (18)
            uint256 precision = 10 ** 18; // WETH decimals
            uint256 wethPriceRaw = UniswapTickMath.getRawPrice(pool, isWETHToken0, precision, TWAP_PERIOD);
            console2.log("Raw price (USDC per WETH with 18 decimals):", wethPriceRaw);

            // This gives us USDC per WETH. To get WETH price in USD, we need to INVERT!
            // Raw price: 2528574236 (with 18 decimals precision)
            // This means: 2528574236 / 1e18 = 0.000000002528574236 USDC per 1 unit of WETH
            // But WETH has 18 decimals, so 1 WETH = 1e18 units
            // So actual USDC per 1 WETH = (2528574236 / 1e18) * 1e18 = 2528574236 / 1e12 = 0.002528574236 USDC
            // Therefore: 1 WETH = 0.002528574236 USDC = $0.002528574236
            // Wait, that's wrong. Let me recalculate...

            // Actually: the precision 1e18 means we get price with 18 decimal places
            // So wethPriceRaw = 2528574236 means 2.528574236 USDC per WETH (since USDC has 6 decimals)
            // NO! Let me think step by step:

            if (wethPriceRaw > 0) {
                // wethPriceRaw = 2528574236 is the raw result from getRawPrice(pool, true, 1e18, period)
                // This represents token1/token0 = USDC/WETH ratio with 1e18 precision
                // So: 2528574236 / 1e18 = 0.000000002528574236 USDC per WETH
                // But that's wrong! Let me think again...

                // Actually: wethPriceRaw = 2528574236 with 1e18 precision means
                // the price ratio scaled by 1e18, accounting for decimal differences
                // Since WETH has 18 decimals and USDC has 6 decimals:
                // The raw ratio needs to be adjusted for the 12-decimal difference

                // The correct way: multiply by decimal difference, then divide by precision
                // This is the same calculation working in AerodromeTWAPTestTwo
                uint256 usdcPerWETH = (wethPriceRaw * 1e12) / 1e18;
                console2.log("USDC per WETH (using working formula):", usdcPerWETH);

                // This should give us around 2528 USDC per WETH = $2528
                console2.log("WETH price in USD:", usdcPerWETH);
            }
        } else {
            console2.log("--- Processing as non-stable pool (no USDC) ---");

            // Get raw price in the other token first
            uint256 rawPrice = UniswapTickMath.getRawPrice(pool, isWETHToken0, 10 ** 18, TWAP_PERIOD);
            console2.log("Raw price in other token:", rawPrice);

            // Would need ETH/USDC pool to convert to USD
            console2.log("Would need ETH/USDC conversion for final USD price");
        }

        // Also test manual calculations for comparison
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = TWAP_PERIOD;
        secondsAgos[1] = 0;

        (int56[] memory tickCumulatives,) = pool.observe(secondsAgos);
        int56 tickCumulativesDelta = tickCumulatives[1] - tickCumulatives[0];
        int24 timeWeightedAverageTick = int24(tickCumulativesDelta / int56(uint56(TWAP_PERIOD)));

        console2.log("Average tick:", int256(timeWeightedAverageTick));

        uint160 sqrtPriceX96 = UniswapTickMath.getSqrtPriceAtTick(timeWeightedAverageTick);
        console2.log("Sqrt price X96:", sqrtPriceX96);

        // Manual calculation - price of token0 in terms of token1
        uint256 numerator = uint256(sqrtPriceX96) * uint256(sqrtPriceX96);
        uint256 denominator = 1 << 192; // 2^192

        if (isWETHToken0) {
            // WETH is token0, USDC is token1 - price is WETH/USDC
            uint256 rawPriceWETHinUSDC = (numerator * 1e6) / denominator; // USDC has 6 decimals
            console2.log("Raw WETH price in USDC:", rawPriceWETHinUSDC);

            // Convert to proper USD format (WETH has 18 decimals, USDC has 6)
            uint256 wethUSDPrice = rawPriceWETHinUSDC * 1e12; // Scale up to 18 decimals
            console2.log("Final WETH USD price (18 decimals):", wethUSDPrice);
        } else {
            // USDC is token0, WETH is token1 - price is USDC/WETH, need to invert
            uint256 rawPriceUSDCinWETH = (numerator * 1e18) / denominator; // WETH has 18 decimals
            console2.log("Raw USDC price in WETH:", rawPriceUSDCinWETH);

            // Invert to get WETH price in USDC
            if (rawPriceUSDCinWETH > 0) {
                uint256 wethPriceInUSDC = (1e18 * 1e6) / rawPriceUSDCinWETH;
                console2.log("Inverted WETH price in USDC:", wethPriceInUSDC);

                uint256 wethUSDPrice = wethPriceInUSDC * 1e12;
                console2.log("Final WETH USD price (18 decimals):", wethUSDPrice);
            }
        }
    }
}
