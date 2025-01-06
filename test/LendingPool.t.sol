// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {Test, console} from "forge-std/Test.sol";

import {ILendingPool} from "src/interfaces/ILendingPool.sol";
import {ILendingPoolAddressesProvider} from "src/interfaces/ILendingPoolAddressesProvider.sol";
import {ILendingPoolConfigurator} from "src/interfaces/ILendingPoolConfigurator.sol";
import {IERC20} from "src/dependencies/openzeppelin/contracts/IERC20.sol";

import {LendingPool} from "src/protocol/lendingpool/LendingPool.sol";
import {LendingPoolAddressesProvider} from "src/protocol/configuration/LendingPoolAddressesProvider.sol";
import {LendingPoolConfigurator} from "src/protocol/lendingpool/LendingPoolConfigurator.sol";
import {MintableERC20} from "src/mocks/tokens/MintableERC20.sol";
import {AToken} from "src/protocol/tokenization/AToken.sol";
import {StableDebtToken} from "src/protocol/tokenization/StableDebtToken.sol";
import {VariableDebtToken} from "src/protocol/tokenization/VariableDebtToken.sol";
import {DefaultReserveInterestRateStrategy} from "src/protocol/lendingpool/DefaultReserveInterestRateStrategy.sol";
import {LendingRateOracle} from "src/mocks/oracle/LendingRateOracle.sol";


contract LendingPoolTest is Test {
    MintableERC20 public asset;
    AToken public aTokenImpl;
    StableDebtToken public stableDebtTokenImpl;
    VariableDebtToken public variableDebtTokenImpl;
    DefaultReserveInterestRateStrategy public interestRateStrategy;

    ILendingPool public lpImpl;
    ILendingPool public lpProxy;
    ILendingPoolAddressesProvider public AddressProvider;
    LendingPoolConfigurator public ConfiguratorImpl;
    LendingPoolConfigurator public ConfiguratorProxy;
    LendingRateOracle public lendingRateOracle;

    address alice = vm.addr(1);
    address bob = vm.addr(2);
    address owner = vm.addr(3);
    address proxyAdmin = vm.addr(4);
    address poolAdmin = vm.addr(5);
    address treasury = vm.addr(6);


    function setUp() public {
        asset = new MintableERC20("testERC20", "asset", 18);
        vm.prank(alice);
        asset.mint(1000_000);

        aTokenImpl = new AToken();
        stableDebtTokenImpl = new StableDebtToken();
        variableDebtTokenImpl = new VariableDebtToken();

        lpImpl = new LendingPool();
        
        AddressProvider = new LendingPoolAddressesProvider("testERC20");
        AddressProvider.setPoolAdmin(poolAdmin);

        AddressProvider.setLendingPoolImpl(address(lpImpl));
        lpProxy = LendingPool(AddressProvider.getLendingPool());

        ConfiguratorImpl = new LendingPoolConfigurator();
        AddressProvider.setLendingPoolConfiguratorImpl(address(ConfiguratorImpl));
        ConfiguratorProxy = LendingPoolConfigurator(AddressProvider.getLendingPoolConfigurator());

        interestRateStrategy = new DefaultReserveInterestRateStrategy(AddressProvider, 1, 2, 3, 4, 5, 6);

        lendingRateOracle = new LendingRateOracle();
        AddressProvider.setLendingRateOracle(address(lendingRateOracle));
        
    }

    function testDeposit() public {
        //arrange
        ILendingPoolConfigurator.InitReserveInput[] memory input = new ILendingPoolConfigurator.InitReserveInput[](1);
        input[0] = ILendingPoolConfigurator.InitReserveInput({
            aTokenImpl: address(aTokenImpl),
            stableDebtTokenImpl: address(stableDebtTokenImpl),
            variableDebtTokenImpl: address(variableDebtTokenImpl),
            underlyingAssetDecimals: 18,
            interestRateStrategyAddress: address(interestRateStrategy),
            underlyingAsset: address(asset),
            treasury: address(treasury),
            incentivesController: address(0),
            underlyingAssetName: "testERC20",
            aTokenName: "aToken",
            aTokenSymbol: "aToken",
            variableDebtTokenName: "variableDebtToken",
            variableDebtTokenSymbol: "vDT",
            stableDebtTokenName: "stableDebtToken",
            stableDebtTokenSymbol: "sDT",
            params: ""
        });

        vm.prank(poolAdmin);
        ConfiguratorProxy.batchInitReserve(input);

        vm.prank(alice);
        asset.increaseAllowance(address(lpProxy), 1000);

        //act
        vm.prank(alice);
        lpProxy.deposit(address(asset), 1000, alice, 0);

        //assert
        address aTokenProxy = lpProxy.getReserveData(address(asset)).aTokenAddress;
        assertEq(asset.balanceOf(aTokenProxy), 1000);
    }
}
