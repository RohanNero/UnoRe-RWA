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

### Matrix Uno Revised testing

1. Will need to find STBT whale to begin testing
2. Next will deposit STBT into MatrixUno vault
3. ensure that xUNO is handled correctly (minted and then held by vault)
4. then test user calling `stake` (sending stablecoins for xUNO in return)
5. once users have xUNO we will need to test staking xUNO with Loki pool

Once users have staked xUNO we have finished the deposit/staking flow.

1. user will need to leave from SSIP
2. once user has xUNO, they need to call `claim` on the MatrixUno vault
3. after calling claim, xUNO is sent to the vault and now the vault needs to send STBT to the STBT/3CRV pool to exchange it for 3CRV
4. after getting the 3CRV, the vault needs to exchange 3CRV for a stablecoin
5. once the vault gets the stablecoin it can be sent, along with the initial deposit, to the user
