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
import {LendingPoolCollateralManager} from "src/protocol/lendingpool/LendingPoolCollateralManager.sol";
import {MintableERC20} from "src/mocks/tokens/MintableERC20.sol";
import {AToken} from "src/protocol/tokenization/AToken.sol";
import {StableDebtToken} from "src/protocol/tokenization/StableDebtToken.sol";
import {VariableDebtToken} from "src/protocol/tokenization/VariableDebtToken.sol";
import {DefaultReserveInterestRateStrategy} from "src/protocol/lendingpool/DefaultReserveInterestRateStrategy.sol";
import {LendingRateOracle} from "src/mocks/oracle/LendingRateOracle.sol";
import {PriceOracle} from "src/mocks/oracle/PriceOracle.sol";


contract LendingPoolTest is Test {
    MintableERC20 public asset;
    AToken public aTokenImpl;
    StableDebtToken public stableDebtTokenImpl;
    VariableDebtToken public variableDebtTokenImpl;
    DefaultReserveInterestRateStrategy public interestRateStrategy;
    LendingPoolCollateralManager public collateralManager;

    ILendingPool public lpImpl;
    ILendingPool public lpProxy;
    ILendingPoolAddressesProvider public AddressProvider;
    LendingPoolConfigurator public ConfiguratorImpl;
    LendingPoolConfigurator public ConfiguratorProxy;
    LendingRateOracle public lendingRateOracle;
    PriceOracle public priceOracle;

    address alice = vm.addr(1);
    address bob = vm.addr(2);
    address owner = vm.addr(3);
    address proxyAdmin = vm.addr(4);
    address poolAdmin = vm.addr(5);
    address treasury = vm.addr(6);

    function setUp() public {
        vm.label(alice, "alice");
        vm.label(bob, "bob");
        vm.label(owner, "owner");
        vm.label(proxyAdmin, "proxyAdmin");
        vm.label(poolAdmin, "poolAdmin");
        vm.label(treasury, "treasury");

        asset = new MintableERC20("testERC20", "asset", 18);
        vm.label(address(asset), "asset");
        vm.prank(alice);
        asset.mint(1000_000e18);
        vm.prank(bob);
        asset.mint(1000_000e18);

        aTokenImpl = new AToken();
        stableDebtTokenImpl = new StableDebtToken();
        variableDebtTokenImpl = new VariableDebtToken();

        lpImpl = new LendingPool();
        
        AddressProvider = new LendingPoolAddressesProvider("testERC20");
        vm.label(address(AddressProvider), "AddressProvider");
        AddressProvider.setPoolAdmin(poolAdmin);

        AddressProvider.setLendingPoolImpl(address(lpImpl));
        lpProxy = LendingPool(AddressProvider.getLendingPool());
        vm.label(address(lpProxy), "lpProxy");

        collateralManager = new LendingPoolCollateralManager();
        vm.label(address(collateralManager), "collateralManager");
        AddressProvider.setLendingPoolCollateralManager(address(collateralManager));

        ConfiguratorImpl = new LendingPoolConfigurator();
        AddressProvider.setLendingPoolConfiguratorImpl(address(ConfiguratorImpl));
        ConfiguratorProxy = LendingPoolConfigurator(AddressProvider.getLendingPoolConfigurator());
        vm.label(address(ConfiguratorProxy), "ConfiguratorProxy");
        vm.startPrank(poolAdmin);
        ConfiguratorProxy.enableBorrowingOnReserve(address(asset), true);
        ConfiguratorProxy.configureReserveAsCollateral(address(asset), 7500, 8500, 10500);
        vm.stopPrank();

        interestRateStrategy = new DefaultReserveInterestRateStrategy(AddressProvider, 1e18, 2e18, 3e18, 4e18, 5e18, 6e18);
        vm.label(address(interestRateStrategy), "interestRateStrategy");

        lendingRateOracle = new LendingRateOracle();
        vm.label(address(lendingRateOracle), "lendingRateOracle");
        AddressProvider.setLendingRateOracle(address(lendingRateOracle));

        priceOracle = new PriceOracle();
        vm.label(address(priceOracle), "priceOracle");
        AddressProvider.setPriceOracle(address(priceOracle));
        priceOracle.setAssetPrice(address(asset), 1e18);
        
    }

    function testDeposit() public {
        // params
        address caller;
        address underlying;
        uint256 amount;
        address onBehalfOf;
        uint16 referralCode;
        uint256 interestRateMode;

        caller = alice;
        underlying = address(asset);
        amount = 1000e18;
        onBehalfOf = alice;
        referralCode = 0;
        console.log("------------------------------------------------------------------------------------");
        _deposit(caller, underlying, amount, onBehalfOf, referralCode);
        console.log("------------------------------------------------------------------------------------");

        //assert
        address aTokenProxy = lpProxy.getReserveData(address(asset)).aTokenAddress;
        assertEq(asset.balanceOf(aTokenProxy), 1000e18);
    }

    function _deposit(address caller, address underlying, uint256 amount, address onBehalfOf, uint16 referralCode) internal {
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

        if(lpProxy.getReserveData(address(asset)).aTokenAddress == address(0)) {
            vm.prank(poolAdmin);
            ConfiguratorProxy.batchInitReserve(input);
        }

        vm.prank(caller);
        asset.increaseAllowance(address(lpProxy), amount);
        
        //act
        vm.prank(caller);
        lpProxy.deposit(underlying, amount, onBehalfOf, referralCode);
    }

    function testWithdraw() public {
        // params
        address caller;
        address underlying;
        uint256 amount;
        address onBehalfOf;
        uint16 referralCode;
        uint256 interestRateMode;

        // history
        console.log("1. deposit 1000 ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^");
        caller = alice;
        underlying = address(asset);
        amount = 1000e18;
        onBehalfOf = alice;
        referralCode = 0;
        _deposit(caller, underlying, amount, onBehalfOf, referralCode);

        caller = alice;
        underlying = address(asset);
        amount = 800e18;
        onBehalfOf = alice;
        console.log("--------------------------------------------------------------------------------------");
        _withdraw(caller, underlying, amount, onBehalfOf);
        console.log("--------------------------------------------------------------------------------------");

        //assert
        address aTokenProxy = lpProxy.getReserveData(address(asset)).aTokenAddress;
        assertEq(asset.balanceOf(aTokenProxy), 200e18);
    }

    function _withdraw(address caller, address underlying, uint256 amount, address onBehalfOf) internal {
        //act
        vm.prank(caller);
        lpProxy.withdraw(underlying, amount, onBehalfOf);
    }

    function testBorrow() public {
        // params
        address caller;
        address underlying;
        uint256 amount;
        address onBehalfOf;
        uint16 referralCode;
        uint256 interestRateMode;

        // history 
        console.log("1. alice deposit 1000 ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^");
        caller = alice;
        underlying = address(asset);
        amount = 1000e18;
        onBehalfOf = alice;
        referralCode = 0;
        _deposit(caller, underlying, amount, onBehalfOf, referralCode);

        caller = alice;
        underlying = address(asset);
        amount = 500e18;
        interestRateMode = 2;
        referralCode = 0;
        onBehalfOf = alice;
        console.log("--------------------------------------------------------------------------------------");
        _borrow(caller, underlying, amount, interestRateMode, referralCode, onBehalfOf);
        console.log("--------------------------------------------------------------------------------------");
    }

    function _borrow(address caller, address underlying, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf) internal {
        //act
        vm.prank(caller);
        lpProxy.borrow(underlying, amount, interestRateMode, referralCode, onBehalfOf);
    }

    function testRepay() public {
        // params
        address caller;
        address underlying;
        uint256 amount;
        uint256 rateMode;
        address onBehalfOf;
        uint16 referralCode;

        // history
        console.log("1. alice deposit 1000 ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^");
        caller = alice;
        underlying = address(asset);
        amount = 1000e18;
        onBehalfOf = alice;
        _deposit(caller, underlying, amount, onBehalfOf, referralCode);

        console.log("2. alice borrow 500 ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^");
        caller = alice;
        underlying = address(asset);
        amount = 500e18;
        rateMode = 2;
        onBehalfOf = alice;
        _borrow(caller, underlying, amount, rateMode, referralCode, onBehalfOf);

        caller = alice;
        underlying = address(asset);
        amount = 300e18;
        onBehalfOf = alice;
        console.log("--------------------------------------------------------------------------------------");
        _repay(caller, underlying, amount, rateMode, onBehalfOf);
        console.log("--------------------------------------------------------------------------------------");

    }

    function _repay(address caller, address underlying, uint256 amount, uint256 rateMode, address onBehalfOf) internal {
        //arrange 
        vm.prank(caller);
        IERC20(underlying).approve(address(lpProxy), amount);

        //act
        vm.prank(caller);
        lpProxy.repay(underlying, amount, rateMode, onBehalfOf);
    }

    // function testliquidate() public {
    //     // params
    //     address caller;
    //     address collateral;
    //     address reserve;
    //     address user;
    //     uint256 amount;
    //     uint16 referralCode;

    //     // history
    //     console.log("1. alice deposit 1000 ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^");
    //     caller = alice;
    //     collateral = address(asset);
    //     amount = 1000e18;
    //     _deposit(caller, collateral, amount, alice, referralCode);

    //     console.log("2. alice borrow 500 ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^");
    //     caller = alice;
    //     reserve = address(asset);
    //     amount = 500e18;
    //     _borrow(caller, reserve, amount, 2, referralCode, alice);

    //     console.log("3. collateral price drops ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^");
    //     priceOracle.setAssetPrice(address(asset), 0);

    //     caller = owner;
    //     collateral = address(asset);
    //     reserve = address(asset);
    //     user = alice;
    //     amount = 500e18;
    //     console.log("--------------------------------------------------------------------------------------");
    //     _liquidate(caller, collateral, reserve, user, amount);
    //     console.log("--------------------------------------------------------------------------------------");
    // }

    // function _liquidate(address caller, address collateral, address reserve, address user, uint256 amount) internal {
    //     //act
    //     vm.prank(caller);
    //     lpProxy.liquidationCall(collateral, reserve, user, amount, false);
    // }
}
