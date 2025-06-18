// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

/**
 * @title Lendefi Constants
 * @notice Shared constants for Lendefi and LendefiAssets contracts
 * @author alexei@lendefimarkets(dot)xyz
 * @custom:copyright Copyright (c) 2025 Nebula Holding Inc. All rights reserved.
 */
library LendefiConstants {
    /// @notice Standard decimals for percentage calculations (1e6 = 100%)
    // uint256 internal constant WAD = 1e6;

    /// @notice Address of the Uniswap V3 USDT/ETH pool on Polygon mainnet
    address internal constant USDT_ETH_POOL = 0x4CcD010148379ea531D6C587CfDd60180196F9b1;
    
    /// @notice Address of the Uniswap V3 USDC/ETH pool on Polygon mainnet
    address internal constant USDC_ETH_POOL = 0xA4D8c89f0c20efbe54cBa9e7e7a7E509056228D9;

    /// @notice Role identifier for users authorized to pause/unpause the protocol
    bytes32 internal constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @notice Role identifier for users authorized to manage protocol parameters
    bytes32 internal constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    /// @notice Role identifier for users authorized to upgrade the contract
    bytes32 internal constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    /// @notice Role identifier for users authorized to access borrow/repay functions in the LendefiMarketVault
    bytes32 internal constant PROTOCOL_ROLE = keccak256("PROTOCOL_ROLE");

    /// @notice Role identifier for addresses that can create new markets
    bytes32 internal constant MARKET_OWNER_ROLE = keccak256("MARKET_OWNER_ROLE");

    /// @notice Duration of the timelock for upgrade operations (3 days)
    uint256 internal constant UPGRADE_TIMELOCK_DURATION = 3 days;

    /// @notice Max liquidation threshold, percentage on a 1000 scale
    uint16 internal constant MAX_LIQUIDATION_THRESHOLD = 990;

    /// @notice Min liquidation threshold, percentage on a 1000 scale
    uint16 internal constant MIN_THRESHOLD_SPREAD = 10;

    /// @notice Max assets supported by platform
    uint32 internal constant MAX_ASSETS = 3000;

    /// @notice Polygon chain ID
    uint256 internal constant POLYGON_CHAIN_ID = 137;

    /// @notice Polygon does not have a sequencer feed (not an L2)
    address internal constant SEQUENCER_FEED = address(0);

    /// @notice Grace period after sequencer restart (1 hour) - not applicable for Polygon
    uint256 internal constant GRACE_PERIOD = 3600;

    /// @notice Polygon mainnet USDC address
    address internal constant POLYGON_USDC = 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359;

    /// @notice Polygon mainnet USDT address
    address internal constant POLYGON_USDT = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;

    /// @notice Polygon mainnet WETH address
    address internal constant POLYGON_WETH = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;

    /// @notice Polygon mainnet WBTC address
    address internal constant POLYGON_WBTC = 0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6;

    /// @notice Polygon mainnet LINK address
    address internal constant POLYGON_LINK = 0x53E0bca35eC356BD5ddDFebbD1Fc0fD03FaBad39;

    /// @notice Polygon mainnet WPOL address
    address internal constant POLYGON_WPOL = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
}
