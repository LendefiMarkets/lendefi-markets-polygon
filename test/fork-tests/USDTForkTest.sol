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

contract USDTForkTest is BasicDeploy {
    // Polygon mainnet addresses (from networks.json)
    address constant WETH = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;
    address constant WBTC = 0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6;
    address constant USDT_POLYGON = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;

    // Pools - Polygon mainnet (from networks.json)
    address constant WETH_USDT_POOL = 0x4CcD010148379ea531D6C587CfDd60180196F9b1;
    address constant WETH_USDC_POOL = 0xA4D8c89f0c20efbe54cBa9e7e7a7E509056228D9;
    address constant USDC_USDT_POOL = 0xDaC8A8E6DBf8c690ec6815e0fF03491B2770255D;
    address constant WBTC_WETH_POOL = 0x50eaEDB835021E4A108B7290636d62E9765cc6d7;

    // Polygon mainnet Chainlink oracle addresses (from networks.json)
    address constant ETH_USD_ORACLE = 0xF9680D99D6C9589e2a93a78A04A279e509205945; // eth-usd
    address constant WBTC_USD_ORACLE = 0xDE31F8bFBD8c84b5360CFACCa3539B938dd78ae6; // wbtc-usd
    address constant USDT_USD_ORACLE = 0x0A6513e40db6EB1b165753AD52E80663aeA50545; // usdt-usd

    uint256 mainnetFork;
    address testUser;

    function setUp() public {
        // Fork Polygon mainnet at a recent block
        mainnetFork = vm.createFork("mainnet", 72897316); // Polygon mainnet block
        vm.selectFork(mainnetFork);

        // Deploy base contracts
        _deployTimelock();
        _deployToken();
        _deployEcosystem();
        _deployTreasury();
        _deployGovernor();
        _deployMarketFactory();

        // Deploy USDT market
        _deployMarket(USDT_POLYGON, "Lendefi Yield Token", "LYTUSDT");

        // Now warp to current time to match oracle data
        vm.warp(1750201920 + 3600); // After latest oracle update + 1 hour

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

        // Configure assets
        console2.log("=== Starting asset configuration ===");
        console2.log("WETH address:", WETH);
        console2.log("WETH_USDT_POOL address:", WETH_USDT_POOL);
        console2.log("About to configure WETH...");
        _configureWETH();
        console2.log("WETH configured successfully");

        console2.log("WBTC address:", WBTC);
        console2.log("WBTC_WETH_POOL address:", WBTC_WETH_POOL);
        console2.log("About to configure WBTC...");
        _configureWBTC();
        console2.log("WBTC configured successfully");

        console2.log("USDT_POLYGON address:", USDT_POLYGON);
        console2.log("USDC_USDT_POOL address:", USDC_USDT_POOL);
        console2.log("About to configure USDT...");
        _configureUSDT();
        console2.log("USDT configured successfully");
    }

    function _configureWETH() internal {
        vm.startPrank(address(timelockInstance));

        // Configure WETH with updated struct format
        assetsInstance.updateAssetConfig(
            WETH,
            IASSETS.Asset({
                active: 1,
                decimals: 18,
                borrowThreshold: 800,
                liquidationThreshold: 850,
                maxSupplyThreshold: 1_000_000 ether,
                isolationDebtCap: 0,
                assetMinimumOracles: 1,
                porFeed: address(0),
                primaryOracleType: IASSETS.OracleType.CHAINLINK,
                tier: IASSETS.CollateralTier.CROSS_A,
                chainlinkConfig: IASSETS.ChainlinkOracleConfig({oracleUSD: ETH_USD_ORACLE, active: 1}),
                poolConfig: IASSETS.UniswapPoolConfig({pool: WETH_USDT_POOL, twapPeriod: 300, active: 1})
            })
        );

        vm.stopPrank();
    }

    function _configureWBTC() internal {
        vm.startPrank(address(timelockInstance));

        // Configure WBTC with updated struct format
        assetsInstance.updateAssetConfig(
            WBTC,
            IASSETS.Asset({
                active: 1,
                decimals: 8, // WBTC has 8 decimals
                borrowThreshold: 700,
                liquidationThreshold: 750,
                maxSupplyThreshold: 500 * 1e8,
                isolationDebtCap: 0,
                assetMinimumOracles: 1,
                porFeed: address(0),
                primaryOracleType: IASSETS.OracleType.CHAINLINK,
                tier: IASSETS.CollateralTier.CROSS_A,
                chainlinkConfig: IASSETS.ChainlinkOracleConfig({oracleUSD: WBTC_USD_ORACLE, active: 1}),
                poolConfig: IASSETS.UniswapPoolConfig({pool: WBTC_WETH_POOL, twapPeriod: 300, active: 1})
            })
        );

        vm.stopPrank();
    }

    function _configureUSDT() internal {
        vm.startPrank(address(timelockInstance));

        // Configure USDT with proper Chainlink oracle
        assetsInstance.updateAssetConfig(
            USDT_POLYGON,
            IASSETS.Asset({
                active: 1,
                decimals: 6,
                borrowThreshold: 950, // 95% - very safe for stablecoin
                liquidationThreshold: 980, // 98% - very safe for stablecoin
                maxSupplyThreshold: 1_000_000_000e6, // 1B USDT
                isolationDebtCap: 0,
                assetMinimumOracles: 1,
                porFeed: address(0),
                primaryOracleType: IASSETS.OracleType.CHAINLINK,
                tier: IASSETS.CollateralTier.STABLE,
                chainlinkConfig: IASSETS.ChainlinkOracleConfig({
                    oracleUSD: USDT_USD_ORACLE, // Use actual USDT oracle
                    active: 1
                }),
                poolConfig: IASSETS.UniswapPoolConfig({pool: USDC_USDT_POOL, twapPeriod: 300, active: 1})
            })
        );

        vm.stopPrank();
    }

    function test_ChainlinkOracleETH() public view {
        (uint80 roundId, int256 answer,, uint256 updatedAt,) =
            AggregatorV3Interface(ETH_USD_ORACLE).latestRoundData();

        console2.log("Direct ETH/USD oracle call:");
        console2.log("  RoundId:", roundId);
        console2.log("  Price:", uint256(answer) / 1e8);
        console2.log("  Updated at:", updatedAt);
    }

    function test_ChainLinkOracleBTC() public view {
        (uint80 roundId, int256 answer,, uint256 updatedAt,) =
            AggregatorV3Interface(WBTC_USD_ORACLE).latestRoundData();
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
        uint256 actualPrice = assetsInstance.getAssetPrice(WETH);
        console2.log("WETH median price:", actualPrice);

        assertEq(actualPrice, expectedMedian, "Median calculation should be correct");
    }

    function test_RealMedianPriceBTC() public {
        // Get prices from both oracles
        uint256 chainlinkPrice = assetsInstance.getAssetPriceByType(WBTC, IASSETS.OracleType.CHAINLINK);
        uint256 uniswapPrice = assetsInstance.getAssetPriceByType(WBTC, IASSETS.OracleType.UNISWAP_V3_TWAP);

        console2.log("WBTC Chainlink price:", chainlinkPrice);
        console2.log("WBTC Uniswap price:", uniswapPrice);

        // Calculate expected median
        uint256 expectedMedian = (chainlinkPrice + uniswapPrice) / 2;

        // Get actual median
        uint256 actualPrice = assetsInstance.getAssetPrice(WBTC);
        console2.log("WBTC median price:", actualPrice);

        assertEq(actualPrice, expectedMedian, "Median calculation should be correct");
    }

    function test_OracleTypeSwitch() public view {
        // Test oracle pricing for all assets with both Chainlink and Uniswap

        uint256 chainlinkPrice = assetsInstance.getAssetPriceByType(WETH, IASSETS.OracleType.CHAINLINK);
        console2.log("Chainlink ETH price:", chainlinkPrice);

        uint256 uniswapPrice = assetsInstance.getAssetPriceByType(WETH, IASSETS.OracleType.UNISWAP_V3_TWAP);
        console2.log("Uniswap ETH price:", uniswapPrice);

        uint256 chainlinkBTCPrice = assetsInstance.getAssetPriceByType(WBTC, IASSETS.OracleType.CHAINLINK);
        console2.log("Chainlink BTC price:", chainlinkBTCPrice);

        uint256 uniswapBTCPrice = assetsInstance.getAssetPriceByType(WBTC, IASSETS.OracleType.UNISWAP_V3_TWAP);
        console2.log("Uniswap BTC price:", uniswapBTCPrice);

        uint256 chainlinkUSDTPrice = assetsInstance.getAssetPriceByType(USDT_POLYGON, IASSETS.OracleType.CHAINLINK);
        console2.log("Chainlink USDT price:", chainlinkUSDTPrice);

        uint256 uniswapUSDTPrice = assetsInstance.getAssetPriceByType(USDT_POLYGON, IASSETS.OracleType.UNISWAP_V3_TWAP);
        console2.log("Uniswap USDT price:", uniswapUSDTPrice);
    }

    function testRevert_PoolLiquidityLimitReached() public {
        // On Polygon, impersonate a WETH holder instead of minting WETH from native currency
        address wethHolder = 0x1eED63EfBA5f81D95bfe37d82C8E736b974F477b; // Large WETH holder on Polygon
        vm.startPrank(wethHolder);
        IERC20(WETH).transfer(testUser, 5000 ether); // Reduced from 10000 to 5000
        vm.stopPrank();

        // Create a user with WETH
        vm.startPrank(testUser);

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
        uint256 poolWethBalance = IERC20(WETH).balanceOf(WETH_USDT_POOL);
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
        // On Polygon, impersonate a WETH holder instead of minting WETH from native currency
        address wethHolder = 0x1eED63EfBA5f81D95bfe37d82C8E736b974F477b; // Large WETH holder on Polygon
        vm.startPrank(wethHolder);
        IERC20(WETH).transfer(testUser, 50 ether);
        vm.stopPrank();
        
        // Create a user with WETH
        vm.startPrank(testUser);

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

    function test_getAnyPoolTokenPriceInUSD_USDT() public {
        uint256 usdtPriceInUSD = assetsInstance.getAssetPrice(USDT_POLYGON);
        console2.log("USDT price in USD:", usdtPriceInUSD);

        // USDT should be close to $1.00
        assertTrue(usdtPriceInUSD > 0.98 * 1e6, "USDT price should be greater than $0.98");
        assertTrue(usdtPriceInUSD < 1.02 * 1e6, "USDT price should be less than $1.02");
    }

    function test_getAnyPoolTokenPriceInUSD_WBTC() public {
        uint256 cbbtcPriceInUSD = assetsInstance.getAssetPrice(WBTC);
        console2.log("WBTC price in USD (median):", cbbtcPriceInUSD);

        // WBTC uses median of Chainlink and Uniswap prices
        assertTrue(cbbtcPriceInUSD > 90000 * 1e6, "WBTC price should be greater than $90,000");
        assertTrue(cbbtcPriceInUSD < 120000 * 1e6, "WBTC price should be less than $120,000");
    }
}
