// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {IUniswapV3Pool} from "../../contracts/interfaces/IUniswapV3Pool.sol";
import {UniswapTickMath} from "../../contracts/markets/lib/UniswapTickMath.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract AEROPoolDebug is Test {
    // AERO/WETH pool address from networks.json 0x6cDcb1C4A4D1C3C6d054b27AC5B77e89eAFb971d
    address public constant AERO_WETH_POOL = 0x82321f3BEB69f503380D6B233857d5C43562e2D0;
    // Token addresses
    address public constant AERO = 0x940181a94A35A4569E4529A3CDfB74e38FD98631;
    address public constant WETH = 0x4200000000000000000000000000000000000006;

    uint32 public constant TWAP_PERIOD = 120; // 2 minute

    uint256 mainnetFork;

    function setUp() public {
        mainnetFork = vm.createFork("mainnet", 31574198);
        vm.selectFork(mainnetFork);
        vm.warp(1732792829 + 3600);
    }

    function test_AEROPriceInWETH() public view {
        console2.log("=== AERO Price in WETH Debug ===");

        IUniswapV3Pool pool = IUniswapV3Pool(AERO_WETH_POOL);

        // Get pool tokens
        address token0 = pool.token0();
        address token1 = pool.token1();
        console2.log("Pool token0:", token0);
        console2.log("Pool token1:", token1);
        console2.log("AERO address:", AERO);
        console2.log("WETH address:", WETH);

        // Determine if AERO is token0
        bool isAEROToken0 = (token0 == AERO);
        console2.log("Is AERO token0:", isAEROToken0);

        // Check decimals
        uint8 aeroDecimals = IERC20Metadata(AERO).decimals();
        uint8 WETHDecimals = IERC20Metadata(WETH).decimals();
        console2.log("AERO decimals:", aeroDecimals);
        console2.log("WETH decimals:", WETHDecimals);

        // This is a stable pool since WETH has 6 decimals
        bool isStablePool = (aeroDecimals == 6 || WETHDecimals == 6);
        console2.log("Is stable pool:", isStablePool);

        // Get AERO price using AERO's decimals (18) as precision
        uint256 aeroPriceRaw = UniswapTickMath.getRawPrice(pool, isAEROToken0, 10 ** aeroDecimals, TWAP_PERIOD);
        console2.log("Raw AERO price (using AERO decimals):", aeroPriceRaw);

        // Since this is NOT a stable pool (both tokens have 18 decimals), we need to convert AERO/WETH to USD
        // The raw price represents AERO per WETH with 1e18 precision
        console2.log("Raw price represents AERO per WETH with 1e18 precision");

        // For actual calculation, we need the WETH/USD price from our working pool
        // We know WETH = $2528 from our previous test
        uint256 wethPriceUSD = 2528; // From our WETH/USDC test

        // AERO price in USD = (AERO/WETH ratio) * (WETH price in USD)
        // aeroPriceRaw = 279141756523329 means 279141756523329/1e18 = 0.000279141756523329 AERO per WETH
        // So 1 AERO = 1 / 0.000279141756523329 WETH = 3582.7 WETH
        // That's clearly wrong - let me recalculate

        // Actually: if AERO is token1 and we call getRawPrice(pool, false, 1e18, period)
        // This should give us token0/token1 = WETH/AERO price
        // Let's check what we actually get
        if (isAEROToken0) {
            console2.log("Getting AERO/WETH price (AERO is token0)");
            // This would be WETH per AERO
        } else {
            console2.log("Getting WETH/AERO price (AERO is token1)");
            // This gives us WETH per AERO with 1e18 precision
            if (aeroPriceRaw > 0) {
                // aeroPriceRaw = 279141756523329 means 279141756523329/1e18 = 0.000279141756523329 WETH per AERO
                // So 1 AERO = 0.000279141756523329 WETH
                // In USD: 1 AERO = 0.000279141756523329 * $2528 = $0.7056...

                // Calculate: AERO price = (WETH per AERO) * (WETH price in USD)
                // But we need to handle decimals correctly
                uint256 aeroPriceUSD = (aeroPriceRaw * wethPriceUSD) / 1e18;
                console2.log("AERO price in USD (raw calculation):", aeroPriceUSD);

                // Convert to cents for better display
                uint256 aeroPriceCents = (aeroPriceRaw * wethPriceUSD * 100) / 1e18;
                console2.log("AERO price in cents:", aeroPriceCents);
                console2.log("AERO price in dollars: $", aeroPriceCents / 100, ".", (aeroPriceCents % 100));
            }
        }
    }
}
