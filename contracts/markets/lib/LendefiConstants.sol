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

    /// @notice Address of the Uniswap V3 USDC/ETH pool on Base mainnet
    address internal constant USDC_ETH_POOL = 0xb2cc224c1c9feE385f8ad6a55b4d94E92359DC59;
    // 0xd0b53D9277642d899DF5C87A3966A349A798F224;

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

    /// @notice Base chain ID
    uint256 internal constant BASE_CHAIN_ID = 8453;

    /// @notice Base sequencer uptime feed address
    address internal constant SEQUENCER_FEED = 0xBCF85224fc0756B9Fa45aA7892530B47e10b6433;

    /// @notice Grace period after sequencer restart (1 hour)
    uint256 internal constant GRACE_PERIOD = 3600;

    /// @notice Base mainnet USDC address
    address internal constant BASE_USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    /// @notice Base mainnet WETH address
    address internal constant BASE_WETH = 0x4200000000000000000000000000000000000006;
}
