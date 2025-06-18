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


    function _deployMarketFactory() internal {
        require(address(timelockInstance) != address(0), "Timelock not deployed");
        require(address(treasuryInstance) != address(0), "Treasury not deployed");
        require(address(tokenInstance) != address(0), "Governance token not deployed");

        LendefiCore coreImpl = new LendefiCore();
        LendefiMarketVault marketVaultImpl = new LendefiMarketVault();
        LendefiPositionVault positionVaultImpl = new LendefiPositionVault();
        LendefiAssets assetsImpl = new LendefiAssets();
        LendefiPoRFeed porFeedImpl = new LendefiPoRFeed();

        (address networkUSDT, address networkWETH, address usdtWethPool) = getNetworkAddresses();

        bytes memory factoryData = abi.encodeCall(
            LendefiMarketFactory.initialize,
            (
                address(timelockInstance),
                address(tokenInstance),
                gnosisSafe,
                address(ecoInstance),
                networkUSDT,
                networkWETH,
                usdtWethPool
            )
        );
        address payable factoryProxy = payable(Upgrades.deployUUPSProxy("LendefiMarketFactory.sol", factoryData));
        marketFactoryInstance = LendefiMarketFactory(factoryProxy);

        vm.prank(gnosisSafe);
        marketFactoryInstance.setImplementations(
            address(coreImpl),
            address(marketVaultImpl),
            address(positionVaultImpl),
            address(assetsImpl),
            address(porFeedImpl)
        );
    }

    function _deployMarket(address baseAsset, string memory name, string memory symbol) internal {
        require(address(marketFactoryInstance) != address(0), "Market factory not deployed");
        require(marketFactoryInstance.coreImplementation() != address(0), "Core implementation not set");
        require(marketFactoryInstance.vaultImplementation() != address(0), "Vault implementation not set");

        vm.prank(gnosisSafe);
        marketFactoryInstance.grantRole(LendefiConstants.MARKET_OWNER_ROLE, charlie);

        vm.prank(gnosisSafe);
        marketFactoryInstance.addAllowedBaseAsset(baseAsset);

        vm.prank(charlie);
        marketFactoryInstance.createMarket(baseAsset, name, symbol);

        IPROTOCOL.Market memory deployedMarket = marketFactoryInstance.getMarketInfo(charlie, baseAsset);
        marketCoreInstance = LendefiCore(deployedMarket.core);
        marketVaultInstance = LendefiMarketVault(deployedMarket.baseVault);
        assetsInstance = LendefiAssets(deployedMarket.assetsModule);

        vm.startPrank(address(timelockInstance));
        ecoInstance.grantRole(REWARDER_ROLE, address(marketCoreInstance));
        vm.stopPrank();
    }

}
