// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {IPROTOCOL} from "./IProtocol.sol";

/**
 * @title ILendefiMarketFactory
 * @notice Interface for the Lendefi Market Factory contract
 * @dev Factory interface for creating and managing LendefiCore + ERC4626 vault pairs
 *      with multi-tenant support where each market owner can create isolated markets
 * @custom:security-contact security@lendefimarkets.com
 */
interface ILendefiMarketFactory {
    // ========== EVENTS ==========

    /**
     * @notice Emitted when a new lending market is successfully created
     * @param marketOwner The address that owns this market instance
     * @param baseAsset The base asset address for the new market
     * @param core The deployed LendefiCore contract address for this market
     * @param baseVault The deployed LendefiMarketVault contract address for this market
     * @param name The name of the ERC20 yield token for this market
     * @param symbol The symbol of the ERC20 yield token for this market
     * @param porFeed The deployed Proof of Reserves feed address for this market
     */
    event MarketCreated(
        address indexed marketOwner,
        address indexed baseAsset,
        address core,
        address baseVault,
        string name,
        string symbol,
        address porFeed
    );

    /**
     * @notice Emitted when market information is updated
     * @param marketOwner The address that owns the market being updated
     * @param baseAsset The base asset address of the updated market
     * @param marketInfo The updated market configuration data
     */
    event MarketUpdated(address indexed marketOwner, address indexed baseAsset, IPROTOCOL.Market marketInfo);

    /**
     * @notice Emitted when a market is removed or deactivated
     * @param marketOwner The address that owns the market being removed
     * @param baseAsset The base asset address of the removed market
     */
    event MarketRemoved(address indexed marketOwner, address indexed baseAsset);

    /**
     * @notice Emitted when implementation contracts are updated by admin
     * @param coreImplementation The new core implementation contract address
     * @param vaultImplementation The new vault implementation contract address
     * @param positionVaultImplementation The new position vault implementation contract address
     */
    event ImplementationsSet(
        address indexed coreImplementation,
        address indexed vaultImplementation,
        address indexed positionVaultImplementation
    );

    /**
     * @notice Emitted when implementation contract is upgraded
     * @param admin Address of the admin who performed the upgrade
     * @param implementation Address of the new implementation
     */
    event Upgrade(address indexed admin, address indexed implementation);

    /**
     * @notice Emitted when an upgrade is scheduled
     * @param scheduler The address scheduling the upgrade
     * @param implementation The new implementation contract address
     * @param scheduledTime The timestamp when the upgrade was scheduled
     * @param effectiveTime The timestamp when the upgrade can be executed
     */
    event UpgradeScheduled(
        address indexed scheduler, address indexed implementation, uint64 scheduledTime, uint64 effectiveTime
    );

    /**
     * @notice Emitted when a scheduled upgrade is cancelled
     * @param canceller The address that cancelled the upgrade
     * @param implementation The implementation address that was cancelled
     */
    event UpgradeCancelled(address indexed canceller, address indexed implementation);

    /**
     * @notice Emitted when a base asset is added to the allowlist
     * @param baseAsset The base asset address that was added
     * @param admin The address that performed the addition
     */
    event BaseAssetAdded(address indexed baseAsset, address indexed admin);

    /**
     * @notice Emitted when a base asset is removed from the allowlist
     * @param baseAsset The base asset address that was removed
     * @param admin The address that performed the removal
     */
    event BaseAssetRemoved(address indexed baseAsset, address indexed admin);

    /**
     * @notice Emitted with comprehensive market details for off-chain indexing
     * @param marketOwner The address that owns this market instance
     * @param baseAsset The base asset address for the new market
     * @param core The deployed LendefiCore contract address
     * @param vault The deployed LendefiMarketVault contract address
     * @param assetsModule The deployed LendefiAssets contract address
     * @param porFeed The deployed PoR feed address
     * @param name The name of the ERC20 yield token
     * @param symbol The symbol of the ERC20 yield token
     * @param decimals The decimals of the base asset
     * @param createdAt The timestamp when market was created
     */
    event MarketCreatedDetailed(
        address indexed marketOwner,
        address indexed baseAsset,
        address core,
        address vault,
        address assetsModule,
        address porFeed,
        string name,
        string symbol,
        uint8 decimals,
        uint256 createdAt
    );

    /**
     * @notice Emitted when max markets per address is updated
     * @param oldMax The previous maximum
     * @param newMax The new maximum
     * @param admin The address that updated the maximum
     */
    event MaxMarketsPerAddressUpdated(uint256 oldMax, uint256 newMax, address indexed admin);

    /**
     * @notice Emitted when governance tokens are withdrawn
     * @param to The address tokens were sent to
     * @param amount The amount of governance tokens withdrawn
     */
    event GovTokensWithdrawn(address indexed to, uint256 amount);

    /**
     * @notice Emitted when required governance balance is updated
     * @param oldBalance The previous required balance
     * @param newBalance The new required balance
     * @param admin The address that updated the balance
     */
    event RequiredGovBalanceUpdated(uint256 oldBalance, uint256 newBalance, address indexed admin);

    /**
     * @notice Emitted when new market fee is updated
     * @param oldAmount The previous required transfer amount
     * @param newAmount The new required transfer amount
     * @param admin The address that updated the amount
     */
    event NewMarketFeeUpdated(uint256 oldAmount, uint256 newAmount, address indexed admin);

    // ========== ERRORS ==========

    /// @notice Thrown when attempting to create a market for an owner/asset pair that already exists
    error MarketAlreadyExists();

    /// @notice Thrown when a required address parameter is the zero address
    error ZeroAddress();

    /// @notice Thrown when trying to access a market that doesn't exist
    error MarketNotFound();

    /// @notice Thrown when clone deployment fails during market creation
    error CloneDeploymentFailed();

    /// @notice Thrown when an invalid contract address is provided
    error InvalidContract();

    /// @notice Thrown when attempting to execute an upgrade before timelock expires
    /// @param timeRemaining The time remaining until the upgrade can be executed
    error UpgradeTimelockActive(uint256 timeRemaining);

    /// @notice Thrown when attempting to execute an upgrade that wasn't scheduled
    error UpgradeNotScheduled();

    /// @notice Thrown when implementation address doesn't match scheduled upgrade
    /// @param scheduledImpl The address that was scheduled for upgrade
    /// @param attemptedImpl The address that was attempted to be used
    error ImplementationMismatch(address scheduledImpl, address attemptedImpl);

    /// @notice Thrown when attempting to create a market with a base asset that is not on the allowlist
    error BaseAssetNotAllowed();

    /// @notice Thrown when an invalid index is provided for array access
    error InvalidIndex();

    /// @notice Thrown when insufficient governance token balance for market creation
    error InsufficientGovTokenBalance();

    /// @notice Thrown when maximum markets per address limit is reached
    error MaxMarketsReached();

    /// @notice Thrown when a parameter value is zero when it should be greater than zero
    error InvalidZeroValue();

    /// @notice Thrown when no governance tokens are available to withdraw
    error NoTokensToWithdraw();

    /// @notice Thrown when invalid string parameters are provided
    error InvalidStringParameter();

    /// @notice Thrown when ERC20 token has invalid properties
    error InvalidTokenProperties();

    // ========== INITIALIZATION ==========

    /**
     * @notice Initializes the factory contract with essential protocol addresses
     * @param _timelock Address of the timelock contract that will have admin privileges
     * @param _govToken Address of the protocol governance token
     * @param _multisig Address of the multisig wallet
     * @param _ecosystem Address of the ecosystem contract for rewards
     * @param _networkBase Network-specific base stablecoin address for oracle validation
     * @param _networkWrappedNative Network-specific wrapped native token address for oracle validation
     * @param _primaryPool Network-specific base/wrapped native pool for price reference
     */
    function initialize(
        address _timelock,
        address _govToken,
        address _multisig,
        address _ecosystem,
        address _networkBase,
        address _networkWrappedNative,
        address _primaryPool
    ) external;

    // ========== ADMIN FUNCTIONS ==========

    /**
     * @notice Sets the implementation contract addresses used for cloning new markets
     * @param _coreImplementation Address of the LendefiCore implementation contract
     * @param _vaultImplementation Address of the LendefiMarketVault implementation contract
     * @param _positionVaultImplementation Address of the position vault implementation contract
     * @param _assetsModuleImplementation Address of the assets module implementation contract
     * @param _PoRFeed Address of the Proof of Reserves feed implementation contract
     */
    function setImplementations(
        address _coreImplementation,
        address _vaultImplementation,
        address _positionVaultImplementation,
        address _assetsModuleImplementation,
        address _PoRFeed
    ) external;

    /**
     * @notice Adds a base asset to the allowlist for market creation
     * @param baseAsset Address of the base asset to add to the allowlist
     * @return True if the asset was added, false if it was already in the allowlist
     */
    function addAllowedBaseAsset(address baseAsset) external returns (bool);

    /**
     * @notice Removes a base asset from the allowlist for market creation
     * @param baseAsset Address of the base asset to remove from the allowlist
     * @return True if the asset was removed, false if it was not in the allowlist
     */
    function removeAllowedBaseAsset(address baseAsset) external returns (bool);

    // ========== MARKET MANAGEMENT ==========

    /**
     * @notice Creates a new lending market for the caller and specified base asset
     * @param baseAsset The ERC20 token address that will serve as the base asset for lending
     * @param name The name for the ERC4626 yield token
     * @param symbol The symbol for the ERC4626 yield token
     */
    function createMarket(address baseAsset, string memory name, string memory symbol) external;

    /**
     * @notice Schedules an upgrade to a new implementation with timelock
     * @param newImplementation Address of the new implementation contract
     */
    function scheduleUpgrade(address newImplementation) external;

    /**
     * @notice Cancels a previously scheduled upgrade
     */
    function cancelUpgrade() external;

    /**
     * @notice Updates the maximum markets allowed per address
     * @param newMax The new maximum number of markets per address
     */
    function setMaxMarketsPerAddress(uint256 newMax) external;

    /**
     * @notice Updates the required governance token balance for market creation
     * @param newBalance The new required balance amount
     */
    function setRequiredGovBalance(uint256 newBalance) external;

    /**
     * @notice Updates the governance token fee required for market creation
     * @param newAmount The new required transfer amount
     */
    function setNewMarketFee(uint256 newAmount) external;

    /**
     * @notice Withdraws collected governance tokens to the multisig address
     * @dev Transfers all collected governance tokens from market creation fees to the multisig wallet
     */
    function withdrawGovTokens() external;

    /**
     * @notice Pauses market creation
     * @dev Prevents new markets from being created while allowing existing operations to continue
     */
    function pause() external;

    /**
     * @notice Unpauses market creation
     * @dev Allows market creation to resume after being paused
     */
    function unpause() external;

    // ========== VIEW FUNCTIONS ==========

    /**
     * @notice Returns the current version of the factory contract
     * @return The version number
     */
    function version() external view returns (uint256);

    /**
     * @notice Returns the core implementation address
     * @return The address of the core implementation
     */
    function coreImplementation() external view returns (address);

    /**
     * @notice Returns the vault implementation address
     * @return The address of the vault implementation
     */
    function vaultImplementation() external view returns (address);

    /**
     * @notice Returns the position vault implementation address
     * @return The address of the position vault implementation
     */
    function positionVaultImplementation() external view returns (address);

    /**
     * @notice Returns the assets module implementation address
     * @return The address of the assets module implementation
     */
    function assetsModuleImplementation() external view returns (address);

    /**
     * @notice Returns the PoR feed implementation address
     * @return The address of the PoR feed implementation
     */
    function porFeedImplementation() external view returns (address);

    /**
     * @notice Returns the governance token address
     * @return The address of the governance token
     */
    function govToken() external view returns (address);

    /**
     * @notice Returns the timelock address
     * @return The address of the timelock
     */
    function timelock() external view returns (address);

    /**
     * @notice Returns the multisig address
     * @return The address of the multisig
     */
    function multisig() external view returns (address);

    /**
     * @notice Returns the ecosystem address
     * @return The address of the ecosystem contract
     */
    function ecosystem() external view returns (address);

    /**
     * @notice Retrieves complete market information for a given market owner and base asset
     * @param marketOwner Address of the market owner
     * @param baseAsset Address of the base asset to query market information for
     * @return Market configuration struct containing all market data
     */
    function getMarketInfo(address marketOwner, address baseAsset) external view returns (IPROTOCOL.Market memory);

    /**
     * @notice Checks if a market is currently active for the specified owner and base asset
     * @param marketOwner Address of the market owner
     * @param baseAsset Address of the base asset to check
     * @return bool True if the market is active, false if inactive or non-existent
     */
    function isMarketActive(address marketOwner, address baseAsset) external view returns (bool);

    /**
     * @notice Returns all markets created by a specific owner
     * @param marketOwner Address of the market owner to query
     * @return Array of Market structs for all markets owned by the specified address
     */
    function getOwnerMarkets(address marketOwner) external view returns (IPROTOCOL.Market[] memory);

    /**
     * @notice Returns all base assets for which a specific owner has created markets
     * @param marketOwner Address of the market owner to query
     * @return Array of base asset addresses
     */
    function getOwnerBaseAssets(address marketOwner) external view returns (address[] memory);

    /**
     * @notice Returns the remaining time before a scheduled upgrade can be executed
     * @return timeRemaining The time remaining in seconds
     */
    function upgradeTimelockRemaining() external view returns (uint256);

    /**
     * @notice Returns information about a pending upgrade
     * @return implementation The address of the pending implementation
     * @return scheduledTime The timestamp when the upgrade was scheduled
     * @return exists Whether an upgrade is pending
     */
    function pendingUpgrade() external view returns (address implementation, uint64 scheduledTime, bool exists);

    /**
     * @notice Checks if a base asset is allowed for market creation
     * @param baseAsset Address of the base asset to check
     * @return True if the base asset is in the allowlist, false otherwise
     */
    function isBaseAssetAllowed(address baseAsset) external view returns (bool);

    /**
     * @notice Returns all allowed base assets
     * @return Array of all allowed base asset addresses
     */
    function getAllowedBaseAssets() external view returns (address[] memory);

    /**
     * @notice Returns the number of allowed base assets
     * @return The count of allowed base assets
     */
    function getAllowedBaseAssetsCount() external view returns (uint256);
}
