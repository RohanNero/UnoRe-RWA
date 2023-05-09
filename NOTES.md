### Notes

- When calling an overloaded function, (function that shares name with another), you must use full signature!

  **Example:**

  Throws error

  `contract.overloaded("a")`

  Doesn't throw error

  `contract["overloaded(string)"]("a")`

### TO DO

1. clean up tests and make them adapt to the current network
2. create Loki contract logic that follows preliminary tests flow
3. calculate exact yield
4. create redemption and withdrawal flows
5. create withdrawal tests to follow preiliminary deposit test flow

### EXTRA

#### Preliminary steps

1. UNO mints $200,000 worth of STBT
2. UNO deposits STBT into STBT/3CRV pool
3. UNO deposits STBT/3CRV LP token into Liquidity Gauge
4. UNO does X, Y, or Z with the CRV

#### User flow

User may

- Deposit stablecoin (for xUNO)
- Deposit stablecoin and stake xUNO

1. user deposits stablecoin into Loki pool
2. user receieves xUNO
   Optional
3. user stakes xUNO
