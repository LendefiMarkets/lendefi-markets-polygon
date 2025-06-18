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

contract LinkForkTest is BasicDeploy {
    // Polygon mainnet addresses
    address constant WETH = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;
    address constant WBTC = 0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6;
    address constant LINK = 0x53E0bca35eC356BD5ddDFebbD1Fc0fD03FaBad39; // LINK token on Polygon
    address constant USDC_POLYGON = 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359;

    // Pools - Polygon mainnet (from networks.json)
    address constant WETH_USDC_POOL = 0xA4D8c89f0c20efbe54cBa9e7e7a7E509056228D9;
    address constant WETH_LINK_POOL = 0x3e31AB7f37c048FC6574189135D108df80F0ea26; // WETH/LINK pool
    address constant LINK_USDC_POOL = 0x94Ab9E4553fFb839431E37CC79ba8905f45BfBeA; // LINK/USDC pool
    address constant WBTC_WETH_POOL = 0x50eaEDB835021E4A108B7290636d62E9765cc6d7;

    // Polygon mainnet Chainlink oracle addresses
    address constant ETH_USD_ORACLE = 0xF9680D99D6C9589e2a93a78A04A279e509205945;
    address constant WBTC_USD_ORACLE = 0xDE31F8bFBD8c84b5360CFACCa3539B938dd78ae6;
    address constant LINK_USD_ORACLE = 0xd9FFdb71EbE7496cC440152d43986Aae0AB76665; // LINK/USD oracle
    address constant USDC_USD_ORACLE = 0xfE4A8cc5b5B2366C1B58Bea3858e81843581b2F7;

    uint256 mainnetFork;
    address testUser;

    function setUp() public {
        // Fork Polygon mainnet at a recent block
        mainnetFork = vm.createFork("mainnet", 72897316); // Polygon mainnet block
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

        // Deploy LINK market
        _deployMarket(LINK, "Lendefi Yield Token", "LYTLINK");

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

        // Configure assets - only WETH and LINK since we have pools for them
        _configureWETH();
        _configureLINK();
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
                poolConfig: IASSETS.UniswapPoolConfig({pool: WETH_USDC_POOL, twapPeriod: 600, active: 1})
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
                chainlinkConfig: IASSETS.ChainlinkOracleConfig({oracleUSD: LINK_USD_ORACLE, active: 1}),
                poolConfig: IASSETS.UniswapPoolConfig({pool: WETH_LINK_POOL, twapPeriod: 300, active: 1})
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

    function test_ChainlinkOracleLINK() public view {
        (uint80 roundId, int256 answer,, uint256 updatedAt,) =
            AggregatorV3Interface(LINK_USD_ORACLE).latestRoundData();
        console2.log("Direct LINK/USD oracle call:");
        console2.log("  RoundId:", roundId);
        console2.log("  Raw answer (8 decimals):", uint256(answer));
        console2.log("  Updated at:", updatedAt);
    }

    function test_LINKOracleProcessing() public view {
        console2.log("Testing LINK oracle processing...");

        uint256 chainlinkPrice = assetsInstance.getAssetPriceByType(LINK, IASSETS.OracleType.CHAINLINK);
        console2.log("LINK Chainlink price processed:", chainlinkPrice);

        uint256 uniswapPrice = assetsInstance.getAssetPriceByType(LINK, IASSETS.OracleType.UNISWAP_V3_TWAP);
        console2.log("LINK Uniswap price:", uniswapPrice);

        uint256 medianPrice = assetsInstance.getAssetPrice(LINK);
        console2.log("LINK median price:", medianPrice);
    }
}
