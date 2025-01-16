# Overview
### features
- lending
- borrowing
- flashloans

### accounting
- indexes
- rates
- token accounting via mint/burn

### fees
1. interest
   1. deposit index scaling : deposit interest when assets are lent
   2. borrow index scaling : borrow interest when assets are borrowed
2. flashloan fee

# System Internals
### protocol components
1. core
   1. rates, index calculation formulas
   2. accounting variables : rates, indexes and tokens(aToken, sDT, vDT), interest accrual via normalized balances
   3. interest rate strategy
   4. lending rate oracle
2. using core to deliver features
   1. lending pool : deposit, borrow, repay, withdraw, liquidate, flashloan, swapBorrowRates
3. pre-built snippets
   1. openzeppelin
   2. math
4. organizing the code
   1. address provider
   2. configurator
   3. custom libraries : health factor
   4. validation logic
   5. errors
5. basic security 
   1. access control heirarchy
   2. reentrancy guards
   3. approve race condition protection
   4. safemath
6. enhancements
   1. factory pattern : implementation and proxy
   2. third party integrations : price oracle
   3. cross chain interop
   4. router
   5. quoter
   6. gas optimization
7.  unit tests
8.  deployment script
  
### System Architecture
1. lendingPool : 
2. addressProvider :
3. configurator :
4. DefaultInterestRateStrategy : 
5. LendingRateOracle : 
6. aToken : 
7. variableDebtToken : 
8. stableDebtToken : 
9. proxies : 



# short notes
### deposit mechanism

### Withdraw mechanism

### Validate logic

### reserve logic



# Testing
### Unit testing
1. import interfaces
2. import contracts
3. import libraries
4. baseTest contract to be inherited
5. helper functions that do the repititive mechanism
6. history
7. local vars for params
8. act section has input and call to helper (acts as a button with input)
9. create some system path to cross check state variables

# Mistakes I make
1. mechanishm mistakes
2. undeclared identifier
3. implicit type conversion not possible
4. identifier not found
5. EVM Error : Revert
6. accessing uninitialized variable