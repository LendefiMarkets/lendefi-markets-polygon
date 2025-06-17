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

contract AeroForkTest is BasicDeploy {
    // Base mainnet addresses
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant CBBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf; // cbBTC on Base
    address constant AERO = 0x940181a94A35A4569E4529A3CDfB74e38FD98631; // AERO token on Base

    // Pools - Base mainnet (using actual working pools from networks.json)
    address constant WETH_USDC_POOL = 0xb2cc224c1c9feE385f8ad6a55b4d94E92359DC59; // Working WETH/USDC pool
    address constant WETH_AERO_POOL = 0x82321f3BEB69f503380D6B233857d5C43562e2D0; // Working WETH/AERO pool
    address constant AERO_USDC_POOL = 0x6cDcb1C4A4D1C3C6d054b27AC5B77e89eAFb971d; // USDC/AERO pool (no data)
    address constant CBBTC_USDC_POOL = 0xfBB6Eed8e7aa03B138556eeDaF5D271A5E1e43ef; // cbBTC/USDC pool
    address constant WETH_CBBTC_POOL = 0x70aCDF2Ad0bf2402C957154f944c19Ef4e1cbAE1; // WETH/cbBTC pool

    // Base mainnet Chainlink oracle addresses
    address constant WETH_CHAINLINK_ORACLE = 0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70;
    address constant CBBTC_CHAINLINK_ORACLE = 0xCCADC697c55bbB68dc5bCdf8d3CBe83CdD4E071E;
    address constant AERO_CHAINLINK_ORACLE = 0x4EC5970fC728C5f65ba413992CD5fF6FD70fcfF0; // AERO/USD oracle

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

        // Deploy AERO market
        _deployMarket(AERO, "Lendefi Yield Token", "LYTAERO");

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

        // Configure assets - only WETH and AERO since we have pools for them
        _configureWETH();
        _configureAERO();
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
                chainlinkConfig: IASSETS.ChainlinkOracleConfig({oracleUSD: WETH_CHAINLINK_ORACLE, active: 1}),
                poolConfig: IASSETS.UniswapPoolConfig({pool: WETH_USDC_POOL, twapPeriod: 600, active: 1})
            })
        );

        vm.stopPrank();
    }

    function _configureAERO() internal {
        vm.startPrank(address(timelockInstance));

        // Configure AERO with updated struct format
        assetsInstance.updateAssetConfig(
            AERO,
            IASSETS.Asset({
                active: 1,
                decimals: 18, // AERO has 18 decimals
                borrowThreshold: 650,
                liquidationThreshold: 700,
                maxSupplyThreshold: 50_000 * 1e18,
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

    function test_ChainlinkOracleETH() public view {
        (uint80 roundId, int256 answer,, uint256 updatedAt,) =
            AggregatorV3Interface(WETH_CHAINLINK_ORACLE).latestRoundData();

        console2.log("Direct ETH/USD oracle call:");
        console2.log("  RoundId:", roundId);
        console2.log("  Price:", uint256(answer) / 1e8);
        console2.log("  Updated at:", updatedAt);
    }

    function test_ChainlinkOracleAERO() public view {
        (uint80 roundId, int256 answer,, uint256 updatedAt,) =
            AggregatorV3Interface(AERO_CHAINLINK_ORACLE).latestRoundData();
        console2.log("Direct AERO/USD oracle call:");
        console2.log("  RoundId:", roundId);
        console2.log("  Raw answer (8 decimals):", uint256(answer));
        console2.log("  Updated at:", updatedAt);
    }

    function test_AEROOracleProcessing() public view {
        console2.log("Testing AERO oracle processing...");

        uint256 chainlinkPrice = assetsInstance.getAssetPriceByType(AERO, IASSETS.OracleType.CHAINLINK);
        console2.log("AERO Chainlink price processed:", chainlinkPrice);

        uint256 uniswapPrice = assetsInstance.getAssetPriceByType(AERO, IASSETS.OracleType.UNISWAP_V3_TWAP);
        console2.log("AERO Uniswap price:", uniswapPrice);

        uint256 medianPrice = assetsInstance.getAssetPrice(AERO);
        console2.log("AERO median price:", medianPrice);
    }
}
