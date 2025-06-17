// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "./BasicDeploy.sol";
import {console2} from "forge-std/console2.sol";
import {IASSETS} from "../../contracts/interfaces/IASSETS.sol";
import {IPROTOCOL} from "../../contracts/interfaces/IProtocol.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from
    "../../contracts/vendor/@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {IUniswapV3Pool} from "../../contracts/interfaces/IUniswapV3Pool.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract WETHForkTest is BasicDeploy {
    // Base mainnet addresses (from networks.json)
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant CBBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address constant USDC_BASE = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant LINK = 0x88Fb150BDc53A65fe94Dea0c9BA0a6dAf8C6e196;
    address constant AERO = 0x940181a94A35A4569E4529A3CDfB74e38FD98631;

    // Pools - Base mainnet (from networks.json)
    address constant WETH_USDC_POOL = 0xb2cc224c1c9feE385f8ad6a55b4d94E92359DC59;
    address constant WETH_CBBTC_POOL = 0x70aCDF2Ad0bf2402C957154f944c19Ef4e1cbAE1;
    address constant WETH_AERO_POOL = 0x82321f3BEB69f503380D6B233857d5C43562e2D0;
    address constant CBBTC_USDC_POOL = 0xfBB6Eed8e7aa03B138556eeDaF5D271A5E1e43ef;

    // Base mainnet Chainlink oracle addresses (from networks.json)
    address constant WETH_CHAINLINK_ORACLE = 0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70; // eth-usd
    address constant CBBTC_CHAINLINK_ORACLE = 0xCCADC697c55bbB68dc5bCdf8d3CBe83CdD4E071E; // wbtc-usd
    address constant LINK_CHAINLINK_ORACLE = 0x17CAb8FE31E32f08326e5E27412894e49B0f9D65; // link-usd
    address constant AERO_CHAINLINK_ORACLE = 0x4EC5970fC728C5f65ba413992CD5fF6FD70fcfF0; // aero-usd

    uint256 mainnetFork;
    address testUser;

    function setUp() public {
        // Fork Base mainnet at a specific block
        mainnetFork = vm.createFork("mainnet", 31574198); // Base mainnet block
        vm.selectFork(mainnetFork);

        // Deploy protocol normally
        // First warp to a reasonable time for treasury deployment
        vm.warp(365 days);

        // Deploy base contracts
        _deployTimelock();
        _deployToken();
        _deployEcosystem();
        _deployTreasury();
        _deployGovernor();
        _deployMarketFactory();

        // Deploy WETH market instead of USDC market
        _deployMarket(WETH, "Lendefi Yield Token WETH", "LYTWETH");

        // Now warp to current time to match oracle data
        vm.warp(1749937669 + 3600); // Oracle timestamp + 1 hour

        // Create test user
        testUser = makeAddr("testUser");
        vm.deal(testUser, 100 ether);

        // Setup roles
        vm.startPrank(guardian);
        timelockInstance.revokeRole(PROPOSER_ROLE, ethereum);
        timelockInstance.revokeRole(EXECUTOR_ROLE, ethereum);
        timelockInstance.revokeRole(CANCELLER_ROLE, ethereum);
        timelockInstance.grantRole(PROPOSER_ROLE, address(govInstance));
        timelockInstance.grantRole(EXECUTOR_ROLE, address(govInstance));
        timelockInstance.grantRole(CANCELLER_ROLE, address(govInstance));
        vm.stopPrank();

        // TGE setup - but DON'T warp time
        vm.prank(guardian);
        tokenInstance.initializeTGE(address(ecoInstance), address(treasuryInstance));

        // Configure assets - WETH is now base asset, others are collateral
        _configureWETH();
        _configureCBBTC();
        _configureLINK();
        _configureAERO();
        _configureUSDC();
    }

    function _configureWETH() internal {
        vm.startPrank(address(timelockInstance));

        // Configure WETH as base asset - adjusted for base asset use
        assetsInstance.updateAssetConfig(
            WETH,
            IASSETS.Asset({
                active: 1,
                decimals: 18,
                borrowThreshold: 950, // Base asset still needs thresholds
                liquidationThreshold: 980,
                maxSupplyThreshold: 1_000_000 ether,
                isolationDebtCap: 0,
                assetMinimumOracles: 1,
                porFeed: address(0),
                primaryOracleType: IASSETS.OracleType.CHAINLINK,
                tier: IASSETS.CollateralTier.CROSS_A,
                chainlinkConfig: IASSETS.ChainlinkOracleConfig({oracleUSD: WETH_CHAINLINK_ORACLE, active: 1}),
                poolConfig: IASSETS.UniswapPoolConfig({pool: WETH_USDC_POOL, twapPeriod: 300, active: 1})
            })
        );

        vm.stopPrank();
    }

    function _configureCBBTC() internal {
        vm.startPrank(address(timelockInstance));

        // Configure CBBTC with updated struct format
        assetsInstance.updateAssetConfig(
            CBBTC,
            IASSETS.Asset({
                active: 1,
                decimals: 8, // CBBTC has 8 decimals
                borrowThreshold: 700,
                liquidationThreshold: 750,
                maxSupplyThreshold: 500 * 1e8,
                isolationDebtCap: 0,
                assetMinimumOracles: 1,
                porFeed: address(0),
                primaryOracleType: IASSETS.OracleType.CHAINLINK,
                tier: IASSETS.CollateralTier.CROSS_A,
                chainlinkConfig: IASSETS.ChainlinkOracleConfig({oracleUSD: CBBTC_CHAINLINK_ORACLE, active: 1}),
                poolConfig: IASSETS.UniswapPoolConfig({pool: WETH_CBBTC_POOL, twapPeriod: 300, active: 1})
            })
        );

        vm.stopPrank();
    }

    function _configureLINK() internal {
        vm.startPrank(address(timelockInstance));

        // Configure LINK with updated struct format
        assetsInstance.updateAssetConfig(
            LINK,
            IASSETS.Asset({
                active: 1,
                decimals: 18, // LINK has 18 decimals
                borrowThreshold: 650,
                liquidationThreshold: 700,
                maxSupplyThreshold: 50_000 * 1e18,
                isolationDebtCap: 0,
                assetMinimumOracles: 1,
                porFeed: address(0),
                primaryOracleType: IASSETS.OracleType.CHAINLINK,
                tier: IASSETS.CollateralTier.CROSS_A,
                chainlinkConfig: IASSETS.ChainlinkOracleConfig({oracleUSD: LINK_CHAINLINK_ORACLE, active: 1}),
                poolConfig: IASSETS.UniswapPoolConfig({pool: address(0), twapPeriod: 300, active: 0}) // No direct pool available
            })
        );

        vm.stopPrank();
    }

    function _configureAERO() internal {
        vm.startPrank(address(timelockInstance));

        // Configure AERO with WETH pool
        assetsInstance.updateAssetConfig(
            AERO,
            IASSETS.Asset({
                active: 1,
                decimals: 18, // AERO has 18 decimals
                borrowThreshold: 650,
                liquidationThreshold: 700,
                maxSupplyThreshold: 100_000 * 1e18,
                isolationDebtCap: 0,
                assetMinimumOracles: 1,
                porFeed: address(0),
                primaryOracleType: IASSETS.OracleType.CHAINLINK,
                tier: IASSETS.CollateralTier.CROSS_A,
                chainlinkConfig: IASSETS.ChainlinkOracleConfig({oracleUSD: AERO_CHAINLINK_ORACLE, active: 1}),
                poolConfig: IASSETS.UniswapPoolConfig({pool: WETH_AERO_POOL, twapPeriod: 300, active: 1})
            })
        );

        vm.stopPrank();
    }

    function _configureUSDC() internal {
        vm.startPrank(address(timelockInstance));

        // Configure USDC - since it's handled specially in getAssetPrice, we just need minimal config
        // Use a dummy oracle address since the price will be overridden to 1e6
        assetsInstance.updateAssetConfig(
            USDC_BASE,
            IASSETS.Asset({
                active: 1,
                decimals: 6,
                borrowThreshold: 950, // 95% - very safe for stablecoin
                liquidationThreshold: 980, // 98% - very safe for stablecoin
                maxSupplyThreshold: 1_000_000_000e6, // 1B USDC
                isolationDebtCap: 0,
                assetMinimumOracles: 1,
                porFeed: address(0),
                primaryOracleType: IASSETS.OracleType.CHAINLINK,
                tier: IASSETS.CollateralTier.STABLE,
                chainlinkConfig: IASSETS.ChainlinkOracleConfig({
                    oracleUSD: WETH_CHAINLINK_ORACLE, // Dummy address - won't be used due to special handling
                    active: 1
                }),
                poolConfig: IASSETS.UniswapPoolConfig({pool: WETH_USDC_POOL, twapPeriod: 300, active: 1})
            })
        );

        vm.stopPrank();
    }

    function test_ChainlinkOracleETH() public view {
        (uint80 roundId, int256 answer,, uint256 updatedAt,) =
            AggregatorV3Interface(WETH_CHAINLINK_ORACLE).latestRoundData();

        console2.log("Direct ETH/USD oracle call:");
        console2.log("  RoundId:", roundId);
        console2.log("  Price:", uint256(answer) / 1e8);
        console2.log("  Updated at:", updatedAt);
    }

    function test_ChainLinkOracleBTC() public view {
        (uint80 roundId, int256 answer,, uint256 updatedAt,) =
            AggregatorV3Interface(CBBTC_CHAINLINK_ORACLE).latestRoundData();
        console2.log("Direct BTC/USD oracle call:");
        console2.log("  RoundId:", roundId);
        console2.log("  Price:", uint256(answer) / 1e8);
        console2.log("  Updated at:", updatedAt);
    }

    function test_RealMedianPriceETH() public {
        // Get prices from both oracles
        uint256 chainlinkPrice = assetsInstance.getAssetPriceByType(WETH, IASSETS.OracleType.CHAINLINK);
        uint256 uniswapPrice = assetsInstance.getAssetPriceByType(WETH, IASSETS.OracleType.UNISWAP_V3_TWAP);

        console2.log("WETH Chainlink price:", chainlinkPrice);
        console2.log("WETH Uniswap price:", uniswapPrice);

        // Calculate expected median
        uint256 expectedMedian = (chainlinkPrice + uniswapPrice) / 2;

        // Get actual median
        uint256 actualMedian = assetsInstance.getAssetPrice(WETH);
        console2.log("WETH median price:", actualMedian);

        assertEq(actualMedian, expectedMedian, "Median calculation should be correct");
    }

    function test_RealMedianPriceBTC() public {
        // Get prices from both oracles
        uint256 chainlinkPrice = assetsInstance.getAssetPriceByType(CBBTC, IASSETS.OracleType.CHAINLINK);
        uint256 uniswapPrice = assetsInstance.getAssetPriceByType(CBBTC, IASSETS.OracleType.UNISWAP_V3_TWAP);

        console2.log("CBBTC Chainlink price:", chainlinkPrice);
        console2.log("CBBTC Uniswap price:", uniswapPrice);
        console2.log("CBBTC Chainlink price in USD:", chainlinkPrice / 1e6);
        console2.log("CBBTC Uniswap price in massive units:", uniswapPrice);

        // This shows the scale difference
        console2.log("Chainlink vs Uniswap ratio:", uniswapPrice / chainlinkPrice);

        // Calculate expected median
        uint256 expectedMedian = (chainlinkPrice + uniswapPrice) / 2;

        // Get actual median
        uint256 actualMedian = assetsInstance.getAssetPrice(CBBTC);
        console2.log("CBBTC median price:", actualMedian);

        assertEq(actualMedian, expectedMedian, "Median calculation should be correct");
    }

    function test_OracleTypeSwitch() public view {
        // Initially both oracles are active
        // Now price should come directly from Chainlink

        uint256 chainlinkPrice = assetsInstance.getAssetPriceByType(WETH, IASSETS.OracleType.CHAINLINK);
        console2.log("Chainlink-only ETH price:", chainlinkPrice);

        uint256 uniswapPrice = assetsInstance.getAssetPriceByType(WETH, IASSETS.OracleType.UNISWAP_V3_TWAP);
        console2.log("Uniswap-only ETH price:", uniswapPrice);

        uint256 chainlinkBTCPrice = assetsInstance.getAssetPriceByType(CBBTC, IASSETS.OracleType.CHAINLINK);
        console2.log("Chainlink-only BTC price:", chainlinkBTCPrice);

        uint256 uniswapBTCPrice = assetsInstance.getAssetPriceByType(CBBTC, IASSETS.OracleType.UNISWAP_V3_TWAP);
        console2.log("Uniswap-only BTC price:", uniswapBTCPrice);
    }

    function testRevert_PoolLiquidityLimitReached() public {
        // Give test user more ETH
        vm.deal(testUser, 15000 ether); // Increase from 100 ETH to 15000 ETH

        // Create a user with WETH
        vm.startPrank(testUser);
        (bool success,) = WETH.call{value: 10000 ether}("");
        require(success, "ETH to WETH conversion failed");

        // Create a position
        uint256 positionId = marketCoreInstance.createPosition(WETH, false);
        console2.log("Created position ID:", positionId);
        vm.stopPrank();

        // Set maxSupplyThreshold high (100,000 ETH) to avoid hitting AssetCapacityReached
        vm.startPrank(address(timelockInstance));
        IASSETS.Asset memory wethConfig = assetsInstance.getAssetInfo(WETH);
        wethConfig.maxSupplyThreshold = 100_000 ether;
        assetsInstance.updateAssetConfig(WETH, wethConfig);
        vm.stopPrank();

        // Get actual WETH balance in the pool
        uint256 poolWethBalance = IERC20(WETH).balanceOf(WETH_USDC_POOL);
        console2.log("WETH balance in pool:", poolWethBalance / 1e18, "ETH");

        // Calculate 3% of pool balance
        uint256 threePercentOfPool = (poolWethBalance * 3) / 100;
        console2.log("3% of pool WETH:", threePercentOfPool / 1e18, "ETH");

        // Add a little extra to ensure we exceed the limit
        uint256 supplyAmount = threePercentOfPool + 1 ether;
        console2.log("Amount to supply:", supplyAmount / 1e18, "ETH");

        // Verify directly that this will trigger the limit
        bool willHitLimit = assetsInstance.poolLiquidityLimit(WETH, supplyAmount);
        console2.log("Will hit pool liquidity limit:", willHitLimit);
        assertTrue(willHitLimit, "Our calculated amount should trigger pool liquidity limit");

        // Supply amount exceeding 3% of pool balance
        vm.startPrank(testUser);
        IERC20(WETH).approve(address(marketCoreInstance), supplyAmount);
        vm.expectRevert(IPROTOCOL.PoolLiquidityLimitReached.selector);
        marketCoreInstance.supplyCollateral(WETH, supplyAmount, positionId);
        vm.stopPrank();

        console2.log("Successfully tested PoolLiquidityLimitReached error");
    }

    function testRevert_AssetLiquidityLimitReached() public {
        // Create a user with WETH
        vm.startPrank(testUser);
        (bool success,) = WETH.call{value: 50 ether}("");
        require(success, "ETH to WETH conversion failed");

        // Create a position
        marketCoreInstance.createPosition(WETH, false); // false = cross-collateral position
        uint256 positionId = marketCoreInstance.getUserPositionsCount(testUser) - 1;
        console2.log("Created position ID:", positionId);

        vm.stopPrank();

        // Update WETH config with a very small limit
        vm.startPrank(address(timelockInstance));
        IASSETS.Asset memory wethConfig = assetsInstance.getAssetInfo(WETH);
        wethConfig.maxSupplyThreshold = 1 ether; // Very small limit
        assetsInstance.updateAssetConfig(WETH, wethConfig);
        vm.stopPrank();

        // Supply within limit
        vm.startPrank(testUser);
        IERC20(WETH).approve(address(marketCoreInstance), 0.5 ether);
        marketCoreInstance.supplyCollateral(WETH, 0.5 ether, positionId);
        console2.log("Supplied 0.5 WETH");

        // Try to exceed the limit
        IERC20(WETH).approve(address(marketCoreInstance), 1 ether);
        vm.expectRevert(IPROTOCOL.AssetCapacityReached.selector);
        marketCoreInstance.supplyCollateral(WETH, 1 ether, positionId);
        vm.stopPrank();

        console2.log("Successfully tested PoolLiquidityLimitReached error");
    }

    function test_RealMedianPriceLINK() public {
        // Get prices from Chainlink only (no Uniswap pool for LINK)
        uint256 chainlinkPrice = assetsInstance.getAssetPriceByType(LINK, IASSETS.OracleType.CHAINLINK);

        console2.log("LINK Chainlink price:", chainlinkPrice);

        // Get actual price (should just be Chainlink since no Uniswap pool)
        uint256 actualPrice = assetsInstance.getAssetPrice(LINK);
        console2.log("LINK price:", actualPrice);

        // Also log direct Chainlink data for reference
        (uint80 roundId, int256 answer,, uint256 updatedAt,) =
            AggregatorV3Interface(LINK_CHAINLINK_ORACLE).latestRoundData();
        console2.log("Direct LINK/USD oracle call:");
        console2.log("  RoundId:", roundId);
        console2.log("  Price:", uint256(answer) / 1e8);
        console2.log("  Updated at:", updatedAt);

        assertEq(actualPrice, chainlinkPrice, "Price should match Chainlink when no Uniswap pool");
    }

    function test_RealMedianPriceAERO() public {
        // Get prices from both oracles
        uint256 chainlinkPrice = assetsInstance.getAssetPriceByType(AERO, IASSETS.OracleType.CHAINLINK);
        uint256 uniswapPrice = assetsInstance.getAssetPriceByType(AERO, IASSETS.OracleType.UNISWAP_V3_TWAP);

        console2.log("AERO Chainlink price:", chainlinkPrice);
        console2.log("AERO Uniswap price:", uniswapPrice);

        // Calculate expected median
        uint256 expectedMedian = (chainlinkPrice + uniswapPrice) / 2;

        // Get actual median
        uint256 actualMedian = assetsInstance.getAssetPrice(AERO);
        console2.log("AERO median price:", actualMedian);

        assertEq(actualMedian, expectedMedian, "Median calculation should be correct");
    }

    /**
     * @notice Get optimal Uniswap V3 pool configuration for price oracle
     * @param asset The asset to get USD price for
     * @param pool The Uniswap V3 pool address
     * @return A properly configured UniswapPoolConfig struct
     */
    function getOptimalUniswapConfig(address asset, address pool)
        public
        view
        returns (IASSETS.UniswapPoolConfig memory)
    {
        // Get pool tokens
        address token0 = IUniswapV3Pool(pool).token0();
        address token1 = IUniswapV3Pool(pool).token1();

        // Verify the asset is in the pool
        require(asset == token0 || asset == token1, "Asset not in pool");

        // Determine if asset is token0
        bool isToken0 = (asset == token0);

        // Identify other token in the pool
        address otherToken = isToken0 ? token1 : token0;

        // Always use WETH as quote token if it's in the pool (since WETH is our base asset)
        address quoteToken;
        if (otherToken == WETH) {
            quoteToken = WETH;
        } else {
            // If not a WETH pair, use the other token as quote
            quoteToken = otherToken;
        }

        // Get decimals
        uint8 assetDecimals = IERC20Metadata(asset).decimals();

        // Calculate optimal decimalsUniswap based on asset decimals
        uint8 decimalsUniswap;
        if (quoteToken == WETH) {
            // For WETH-quoted prices, use 8 decimals (standard)
            decimalsUniswap = 8;
        } else {
            // For non-WETH quotes, add 2 extra precision digits to asset decimals
            decimalsUniswap = uint8(assetDecimals) + 2;
        }

        return IASSETS.UniswapPoolConfig({
            pool: pool,
            twapPeriod: 1800, // Default 30 min TWAP
            active: 1
        });
    }

    function test_getAnyPoolTokenPriceInUSD_ETHUSDC() public {
        uint256 ethPriceInUSD = assetsInstance.getAssetPrice(WETH);
        console2.log("ETH price in USD (from ETH/USDC pool):", ethPriceInUSD);

        // Assert that the price is within a reasonable range (e.g., $1000 to $5000)
        assertTrue(ethPriceInUSD > 1700 * 1e6, "ETH price should be greater than $1700");
        assertTrue(ethPriceInUSD < 5000 * 1e6, "ETH price should be less than $5000");
    }

    function test_getAnyPoolTokenPriceInUSD_CBBTCETH() public {
        uint256 cbbtcPriceInUSD = assetsInstance.getAssetPrice(CBBTC);
        // Log the CBBTC price in USD
        console2.log("CBBTC price in USD (from CBBTC/ETH pool):", cbbtcPriceInUSD);

        // Assert that the price is within a reasonable range (e.g., $90,000 to $120,000)
        assertTrue(cbbtcPriceInUSD > 90000 * 1e6, "CBBTC price should be greater than $90,000");
        assertTrue(cbbtcPriceInUSD < 120000 * 1e6, "CBBTC price should be less than $120,000");
    }

    function test_getAnyPoolTokenPriceInUSD_LINK() public {
        uint256 linkPriceInUSD = assetsInstance.getAssetPrice(LINK);
        // Log the LINK price in USD
        console2.log("LINK price in USD (Chainlink only):", linkPriceInUSD);

        // Assert that the price is within a reasonable range (e.g., $10 to $30)
        assertTrue(linkPriceInUSD > 10 * 1e6, "LINK price should be greater than $10");
        assertTrue(linkPriceInUSD < 30 * 1e6, "LINK price should be less than $30");
    }

    function test_getAnyPoolTokenPriceInUSD_AERO() public {
        uint256 aeroPriceInUSD = assetsInstance.getAssetPrice(AERO);
        // Log the AERO price in USD
        console2.log("AERO price in USD (median):", aeroPriceInUSD);

        // Assert that the price is within a reasonable range (e.g., $0.5 to $5)
        assertTrue(aeroPriceInUSD > 0.5 * 1e6, "AERO price should be greater than $0.5");
        assertTrue(aeroPriceInUSD < 5 * 1e6, "AERO price should be less than $5");
    }

    function test_getAnyPoolTokenPriceInUSD_CBBTCWETH() public {
        uint256 cbbtcPriceInUSD = assetsInstance.getAssetPrice(CBBTC);
        // Log the CBBTC price in USD
        console2.log("CBBTC price in USD (median):", cbbtcPriceInUSD);

        // Assert that the price is within a reasonable range (e.g., $90,000 to $120,000)
        assertTrue(cbbtcPriceInUSD > 90000 * 1e6, "CBBTC price should be greater than $90,000");
        assertTrue(cbbtcPriceInUSD < 120000 * 1e6, "CBBTC price should be less than $120,000");
    }
}
