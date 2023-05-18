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

   - 4-5% currently for STBT
   - x - y% currently for xUNO

4. create redemption and withdrawal flows
5. create withdrawal tests to follow preliminary deposit test flow

### EXTRA

#### Preliminary steps

1. UNO mints $200,000 worth of STBT
2. UNO receives STBT
3. UNO deposits STBT with MatrixUno vault
4. UNO holds xUNO

#### User flow

User may

- Deposit stablecoin (for xUNO)
- Deposit stablecoin and stake xUNO

1. user deposits stablecoin into Loki pool
2. user receieves xUNO
3. Optional: user stakes xUNO
