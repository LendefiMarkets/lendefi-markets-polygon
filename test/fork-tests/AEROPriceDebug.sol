// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {IUniswapV3Pool} from "../../contracts/interfaces/IUniswapV3Pool.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {UniswapTickMath} from "../../contracts/markets/lib/UniswapTickMath.sol";
import {FullMath} from "@uniswap/v4-core/src/libraries/FullMath.sol";

contract AEROPriceDebug is Test {
    // Base mainnet addresses
    address constant AERO = 0x940181a94A35A4569E4529A3CDfB74e38FD98631;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    address constant WETH_AERO_POOL = 0x82321f3BEB69f503380D6B233857d5C43562e2D0;
    address constant WETH_USDC_POOL = 0xb2cc224c1c9feE385f8ad6a55b4d94E92359DC59;

    uint256 mainnetFork;

    function setUp() public {
        mainnetFork = vm.createFork("mainnet", 31574198);
        vm.selectFork(mainnetFork);
        vm.warp(1732792829 + 3600);
    }

    function test_DebugAEROPriceCalculation() public view {
        IUniswapV3Pool aeroPool = IUniswapV3Pool(WETH_AERO_POOL);
        IUniswapV3Pool ethUsdcPool = IUniswapV3Pool(WETH_USDC_POOL);

        console2.log("=== AERO/WETH Pool Debug ===");
        console2.log("Pool address:", address(aeroPool));
        console2.log("Token0:", aeroPool.token0());
        console2.log("Token1:", aeroPool.token1());
        console2.log("AERO address:", AERO);
        console2.log("WETH address:", WETH);

        bool isToken0 = (AERO == aeroPool.token0());
        console2.log("AERO is token0:", isToken0);

        uint8 aeroDecimals = IERC20Metadata(AERO).decimals();
        console2.log("AERO decimals:", aeroDecimals);

        // Get raw AERO/WETH price
        uint256 rawAeroPrice = UniswapTickMath.getRawPrice(aeroPool, isToken0, 10 ** aeroDecimals, 120);
        console2.log("Raw AERO/WETH price:", rawAeroPrice);

        console2.log("\n=== WETH/USDC Pool Debug ===");
        console2.log("Pool address:", address(ethUsdcPool));
        console2.log("Token0:", ethUsdcPool.token0());
        console2.log("Token1:", ethUsdcPool.token1());

        // Check which is WETH
        bool wethIsToken0 = (WETH == ethUsdcPool.token0());
        console2.log("WETH is token0:", wethIsToken0);

        uint8 usdcDecimals = IERC20Metadata(USDC).decimals();
        console2.log("USDC decimals:", usdcDecimals);

        // Get ETH/USDC price (ETH is token0, not token1!)
        uint256 ethPriceInUSD = UniswapTickMath.getRawPrice(ethUsdcPool, wethIsToken0, 1e18, 120);
        console2.log("ETH price in USD (raw):", ethPriceInUSD);

        // The stable pool formula should be: (rawPrice * 1e12) / 1e18
        uint256 ethPriceCorrect = (ethPriceInUSD * 1e12) / 1e18;
        console2.log("ETH price corrected:", ethPriceCorrect);

        console2.log("\n=== Current Broken Calculation ===");
        uint256 adjustedPrice = rawAeroPrice / (10 ** (18 - aeroDecimals));
        console2.log("Adjusted price:", adjustedPrice);

        uint256 normalizationFactor = 10 ** aeroDecimals;
        console2.log("Normalization factor:", normalizationFactor);

        uint256 brokenResult = FullMath.mulDiv(adjustedPrice, ethPriceInUSD, normalizationFactor);
        console2.log("Broken result:", brokenResult);

        console2.log("\n=== Corrected Calculation ===");
        // AERO price should be: rawAeroPrice * ethPriceInUSD / 1e18
        // But we need to account for decimals properly
        uint256 correctResult = FullMath.mulDiv(rawAeroPrice, ethPriceInUSD, 1e18);
        console2.log("Correct result:", correctResult);
        console2.log("Correct result (dollars):", correctResult / 1e6);
        console2.log("Correct result (cents):", (correctResult % 1e6) / 1e4);
    }
}
