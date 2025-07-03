// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPROTOCOL} from "../../contracts/interfaces/IProtocol.sol";
import {Treasury} from "../../contracts/ecosystem/Treasury.sol";
import {Ecosystem} from "../../contracts/ecosystem/Ecosystem.sol";
import {GovernanceToken} from "../../contracts/ecosystem/GovernanceToken.sol";
import {LendefiGovernor} from "../../contracts/ecosystem/LendefiGovernor.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {LendefiAssets} from "../../contracts/markets/LendefiAssets.sol";
import {LendefiPoRFeed} from "../../contracts/markets/LendefiPoRFeed.sol";
import {TimelockControllerUpgradeable} from
    "@openzeppelin/contracts-upgradeable/governance/TimelockControllerUpgradeable.sol";
import {LendefiMarketFactory} from "../../contracts/markets/LendefiMarketFactory.sol";
import {LendefiCore} from "../../contracts/markets/LendefiCore.sol";
import {LendefiMarketVault} from "../../contracts/markets/LendefiMarketVault.sol";
import {LendefiPositionVault} from "../../contracts/markets/LendefiPositionVault.sol";
import {LendefiConstants} from "../../contracts/markets/lib/LendefiConstants.sol";

contract BasicDeploy is Test {
    bytes32 internal constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 internal constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 internal constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 internal constant CANCELLER_ROLE = keccak256("CANCELLER_ROLE");
    bytes32 internal constant REWARDER_ROLE = keccak256("REWARDER_ROLE");
    bytes32 internal constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 internal constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 internal constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    address constant ethereum = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address constant gnosisSafe = address(0x9999987);
    address constant guardian = address(0x9999990);
    address constant charlie = address(0x9999993);

    GovernanceToken internal tokenInstance;
    Ecosystem internal ecoInstance;
    TimelockControllerUpgradeable internal timelockInstance;
    LendefiGovernor internal govInstance;
    Treasury internal treasuryInstance;
    LendefiAssets internal assetsInstance;
    LendefiMarketFactory internal marketFactoryInstance;
    LendefiCore internal marketCoreInstance;
    LendefiMarketVault internal marketVaultInstance;
    LendefiPoRFeed internal porFeedImplementation;
    // Real Polygon mainnet addresses for fork testing
    IERC20 usdcInstance = IERC20(0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359);
    IERC20 usdtInstance = IERC20(0xc2132D05D31c914a87C6611C10748AEb04B58e8F);
    IERC20 wethInstance = IERC20(0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619);

    function getNetworkAddresses()
        internal
        pure
        returns (address networkUSDT, address networkWETH, address usdtWethPool)
    {
        networkUSDT = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;
        networkWETH = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;
        usdtWethPool = 0x4CcD010148379ea531D6C587CfDd60180196F9b1;
    }

    function _deployToken() internal {
        if (address(timelockInstance) == address(0)) {
            _deployTimelock();
        }
        bytes memory data = abi.encodeCall(GovernanceToken.initializeUUPS, (guardian, address(timelockInstance)));
        address payable proxy = payable(Upgrades.deployUUPSProxy("GovernanceToken.sol", data));
        tokenInstance = GovernanceToken(proxy);
    }

    function _deployEcosystem() internal {
        bytes memory data =
            abi.encodeCall(Ecosystem.initialize, (address(tokenInstance), address(timelockInstance), gnosisSafe));
        address payable proxy = payable(Upgrades.deployUUPSProxy("Ecosystem.sol", data));
        ecoInstance = Ecosystem(proxy);
    }

    function _deployTimelock() internal {
        uint256 timelockDelay = 24 * 60 * 60;
        address[] memory temp = new address[](1);
        temp[0] = ethereum;
        TimelockControllerUpgradeable timelock = new TimelockControllerUpgradeable();
        bytes memory initData = abi.encodeWithSelector(
            TimelockControllerUpgradeable.initialize.selector, timelockDelay, temp, temp, guardian
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(timelock), initData);
        timelockInstance = TimelockControllerUpgradeable(payable(address(proxy)));
    }

    function _deployGovernor() internal {
        bytes memory data = abi.encodeCall(LendefiGovernor.initialize, (tokenInstance, timelockInstance, gnosisSafe));
        address payable proxy = payable(Upgrades.deployUUPSProxy("LendefiGovernor.sol", data));
        govInstance = LendefiGovernor(proxy);
    }

    function _deployTreasury() internal {
        uint256 startOffset = 180 days;
        uint256 vestingDuration = 3 * 365 days;
        bytes memory data =
            abi.encodeCall(Treasury.initialize, (address(timelockInstance), gnosisSafe, startOffset, vestingDuration));
        address payable proxy = payable(Upgrades.deployUUPSProxy("Treasury.sol", data));
        treasuryInstance = Treasury(proxy);
    }

    function _deployAssetsModule() internal {
        if (address(timelockInstance) == address(0)) {
            _deployTimelock();
        }
        porFeedImplementation = new LendefiPoRFeed();
        (address networkUSDT, address networkWETH, address usdtWethPool) = getNetworkAddresses();
        bytes memory data = abi.encodeCall(
            LendefiAssets.initialize,
            (
                address(timelockInstance),
                charlie,
                address(porFeedImplementation),
                address(0),
                networkUSDT,
                networkWETH,
                usdtWethPool
            )
        );
        address payable proxy = payable(Upgrades.deployUUPSProxy("LendefiAssets.sol", data));
        assetsInstance = LendefiAssets(proxy);
    }

    /**
     * @notice Deploys the LendefiMarketFactory contract
     * @dev This contract creates Core+Vault pairs for different base assets
     */
    function _deployMarketFactory() internal {
        // Ensure dependencies are deployed
        require(address(timelockInstance) != address(0), "Timelock not deployed");
        require(address(treasuryInstance) != address(0), "Treasury not deployed");
        require(address(tokenInstance) != address(0), "Governance token not deployed");

        // Deploy implementations
        LendefiCore coreImpl = new LendefiCore();
        LendefiMarketVault marketVaultImpl = new LendefiMarketVault(); // For market vaults
        LendefiPositionVault positionVaultImpl = new LendefiPositionVault(); // For user position vaults
        LendefiAssets assetsImpl = new LendefiAssets(); // Assets implementation for cloning
        LendefiPoRFeed porFeedImpl = new LendefiPoRFeed();

        // Get network-specific addresses
        (address networkUSDC, address networkWETH, address UsdcWethPool) = getNetworkAddresses();

        // Deploy factory using UUPS pattern with direct proxy deployment
        bytes memory factoryData = abi.encodeCall(
            LendefiMarketFactory.initialize,
            (
                address(timelockInstance),
                address(tokenInstance),
                gnosisSafe,
                address(ecoInstance),
                networkUSDC,
                networkWETH,
                UsdcWethPool
            )
        );
        address payable factoryProxy = payable(Upgrades.deployUUPSProxy("LendefiMarketFactory.sol", factoryData));
        marketFactoryInstance = LendefiMarketFactory(factoryProxy);

        // Set implementations - pass the implementation address, NOT the proxy
        vm.prank(gnosisSafe);
        marketFactoryInstance.setImplementations(
            address(coreImpl),
            address(marketVaultImpl),
            address(positionVaultImpl),
            address(assetsImpl),
            address(porFeedImpl)
        );

        // TGE setup - MUST be done before market creation to give guardian tokens
        vm.prank(guardian);
        tokenInstance.initializeTGE(address(ecoInstance), address(treasuryInstance));
    }

    /**
     * @notice Deploys a specific market (Core + Vault) for a base asset
     * @param baseAsset The base asset address for the market
     * @param name The name for the market
     * @param symbol The symbol for the market
     */
    function _deployMarket(address baseAsset, string memory name, string memory symbol) internal {
        require(address(marketFactoryInstance) != address(0), "Market factory not deployed");

        // Verify implementations are set
        require(marketFactoryInstance.coreImplementation() != address(0), "Core implementation not set");
        require(marketFactoryInstance.vaultImplementation() != address(0), "Vault implementation not set");

        // NOTE: MARKET_OWNER_ROLE no longer required - market creation is now permissionless with governance token requirement

        // Add base asset to allowlist (done by multisig which has MANAGER_ROLE)
        vm.prank(gnosisSafe);
        marketFactoryInstance.addAllowedBaseAsset(baseAsset);

        // Setup governance tokens for charlie (required for permissionless market creation)
        // Transfer governance tokens from guardian to charlie (guardian received DEPLOYER_SHARE during TGE)
        vm.prank(guardian);
        tokenInstance.transfer(charlie, 10000 ether); // Transfer 10,000 tokens (more than the 1000 required)

        // Charlie approves factory to spend governance tokens
        vm.prank(charlie);
        tokenInstance.approve(address(marketFactoryInstance), 100 ether); // Approve the 100 tokens that will be transferred

        // Create market via factory (charlie as market owner)
        vm.prank(charlie);
        marketFactoryInstance.createMarket(baseAsset, name, symbol);

        // Get deployed addresses (using charlie as market owner)
        IPROTOCOL.Market memory deployedMarket = marketFactoryInstance.getMarketInfo(charlie, baseAsset);
        marketCoreInstance = LendefiCore(deployedMarket.core);
        marketVaultInstance = LendefiMarketVault(deployedMarket.baseVault);

        // Get the assets module for this specific market from the market struct
        address marketAssetsModule = deployedMarket.assetsModule;
        assetsInstance = LendefiAssets(marketAssetsModule); // Update assetsInstance to point to the market's assets module

        // Grant necessary roles
        vm.startPrank(address(timelockInstance));
        ecoInstance.grantRole(REWARDER_ROLE, address(marketCoreInstance));
        // Grant market owner MANAGER_ROLE on vault (since factory can't do it without DEFAULT_ADMIN_ROLE)
        marketVaultInstance.grantRole(LendefiConstants.MANAGER_ROLE, charlie);
        vm.stopPrank();
    }
}
