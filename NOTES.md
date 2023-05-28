### Notes

- When calling an overloaded function, (function that shares name with another), you must use full signature!

  **Example:**

  Throws error

  `contract.overloaded("a")`

  Doesn't throw error

  `contract["overloaded(string)"]("a")`

- We can't test depositing STBT since our vault would have to be whitelisted, instead will use mock STBT
- Can we impersonate the STBT admin and whitelist our vault on the mainnet fork?
- To run tests on local blockchain

  1. need to deploy mock STBT, mock STBT/3CRV pool, mock Curve tripool, mock stables

- Only STBT `Moderator` can call `setPermission()` so we need to impersonate that address and allow the vault to receive STBT

### TO DO

1. implement the updated vault logic for reward calculation
2. rename `claim` to `unstake` and implement a `claim` function to get rewards without withdrawing stablecoins
3. test the new logic on mainnet fork
4. test the new logic on Goerli testnet

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

0. Impersonate STBT admin to whitelist our vault
1. Need to find STBT whale to begin testing
2. Next will deposit STBT into MatrixUno vault
3. ensure that xUNO is handled correctly (minted and then held by vault)
4. then test user calling `stake` (sending stablecoins for xUNO in return)
5. once users have xUNO we will need to test staking xUNO with Loki pool and receiving rewards (STBT's `distributeInterests`)

Once users have staked xUNO we have finished the deposit/staking flow.

1. user will need to leave from SSIP
2. once user has xUNO, they need to call `claim` on the MatrixUno vault
3. after calling claim, xUNO is sent to the vault and now the vault needs to send STBT to the STBT/3CRV pool to exchange it for 3CRV
4. after getting the 3CRV, the vault needs to exchange 3CRV for a stablecoin
5. once the vault gets the stablecoin it can be sent, along with the initial deposit, to the user

### Questions

1. If a user tries to stake an amount that requires the vault sending more shares than it currently has, should we revert the entire transaction and display the current balance next to the amount requested? Or should we send them all the xUNO we have left and only transferFrom part of the stablecoin amount they approved to cover the amouunt of xUNO we send to them?
2. What will we do about users that hold STBT and want to `deposit` into the vault and mint new xUNO?
3. What if Uno Re wants to withdrawal the STBT and burn it for the initial stablecoin deposit?

- should Uno always be allowed to withdraw? Or should they only be allowed if they have the xUNO amount that was minted.

### Additional

Changing withdrawal slippage caluclation to:

1. multiply by .99, which is 99 followed by 16 zeros
2. divie by 1e18 if stable is dai OR divide by 1e30 if stable is usdc or usdt

This means that the maximum amount you could ever lose is 1% of your rewards

### Test explaination / walkthrough

The `MatrixUno` tests start with setting up the vault by depositing the initial $200,000 worth of STBT into it.
Once the xUNO has been minted and stored into the vault, users are ready to `stake`.
We test `stake` by letting a USDC whale stake $50,000, which is 1/4 of the initial amount.
Now that the user has the xUNO, we want to test the `claim` function.
But before we can, we must send a transaction that mocks STBT's `distributeRewards` function call.
I sent $1000 STBT to the vault so now the total vault STBT balance is $201,000.
Now when we call `claim`, and transfer the xUNO back to the vault.
Now the vault swaps $250 STBT into USDC as the user's rewards since he owned 25% of initial amount.
The vault finally transfers the $50,250 to the user.
The vault's final STBT balance is $200,750.

### Possible upgrades

1. instead of using `stableBalance` + `minimumReceive` as the rewards to send to users when they `claim()`, we could just increment the
   user's balance with the `minimumReceive` and then transfer the balance
2. total STBT earned by the vault as rewards can be calculated by `totalClaimed` + `viewRedeemable()`, then using this number you can caluclate the amount of rewards a user should receieve. This way users can't repeatedly `stake` and `claim` to keep receiving rewards proportional to
   the amount they staked.

For example:

User `stake`s 25% / $50,000 of `initialAmount` ($200,000).
Then `claim`s $250 out of $1000 rewards earned by the vault.
Then the user `stake`s again and now has 25% of the `initialAmount` again.
The user calls `claim` to try and get 25% of the remaining $750 that is redeemable, currently the user can do this.
To correct this, we need to somehow calculate his rewards and end up with 0 as the answer.

currently we get his rewards with the formula:

r = (t - i) / (i / u)
r = d / p

rewards = (totalAssets - initialAssets) / (initialAssets / userStake)
rewards = totalRedeemable / portion

But a revised formula that accounts for the amount that the user has already claimed could be:

rewards = ((t - i) - (e - c)) / (i / u) <---------- WORK IN PROGRESS, THIS DOESN'T WORK

**where**:

t/totalAssets = total amount of STBT in the vault
i/initialAssets = initial amount of STBT in the vault
e/totalEarned = total amount of stbt sent to the vault (totalRedeemable + totalClaimed)
c/claimed = total amount the user has claimed
u/userStake = total amount of stablecoins the user staked

**variables:**

- totalClaimed - total stbt rewards claiemd
- totalEarned - total stbt rewards sent to vault (this is totalRedeemable + totalClaimed)
- claimed[msg.sender] - how much the user has claimed
-

### Possible reward calculation function

```js
function calculateRewards(address user) public view returns (uint) {
  uint lastClaimWeek = lastClaim[user];
  uint currentWeek = (block.timestamp - startingTimestamp) / SECONDS_IN_WEEK;
  uint totalRewards = 0;

  for (uint i = lastClaimWeek; i < currentWeek; i++) {
    totalRewards += rewardsPerWeek[i];
  }

  uint stakedPortion = initialVaultBalance / userStakes[user];
  uint userRewards = (totalRewards / stakedPortion);

  return userRewards;
}
```

Test function examples:

1. Alice depositing 50,000 for the first time on week 1:
   lastClaimWeek = 0
   currentWeek = 1
   totalRewards = 1000
   stakedPortion = 0
   userRewards = 0

2. Alice depositing 50,000 for the second time on week 3:
   lastClaimWeek = 1
   currentWeek = 3
   totalRewards = 2000
   stakedPortion = 4
   userRewards = $500

3. Bob depositing $50,000 for the first time on week 3:
   lastClaimWeek = 0
   currentWeek = 3
   totalRewards = 3000
   stakedPortion = 0
   userRewards = 0

4. Alice claiming rewards on week 5:
   lastClaimWeek = 3
   currentWeek = 5
   totalRewards = 2000
   stakedPortion = 2
   userRewards = $1000

5. Bob claiming rewards on week 5:
   lastClaimWeek = 3
   currentWeek = 5
   totalRewards = 2000
   stakedPortion = 4
   userRewards = $500

6. Patrick depositing $50,000 on week 6
   lastClaimWeek = 0
   currentWeek = 6
   totalRewards = 6000
   stakedPortion = 0
   userRewards = 0

7. Alice claiming rewards on week 6
   lastClaimWeek = 5
   currentWeek = 6
   totalRewards = 1000
   stakedPortion = 2
   userRewards = $500

8. Bob claiming rewards on week 6
   lastClaimWeek = 5
   currentWeek = 6
   totalRewards = 1000
   stakedPortion = 4
   userRewards = $250

9. Patrick claiming rewards on week 7
   lastClaimWeek = 6
   currentWeek = 7
   totalRewards = 1000
   stakedPortion = 4
   userRewards = $250

10. Alice claiming rewards on week 7
    lastClaimWeek = 6
    currentWeek = 7
    totalRewards = 1000
    stakedPortion = 2
    userRewards = $500

11. Bob claiming rewards on week 7
    lastClaimWeek = 6
    currentWeek = 7
    totalRewards = 1000
    stakedPortion = 4
    userRewards = $250

12. Patrick claiming rewards on week 8
    lastClaimWeek = 7
    currentWeek = 8
    totalRewards = 1000
    stakedPortion = 4
    userRewards = $250

13. Alice claiming rewards on week 8
    lastClaimWeek = 7
    currentWeek = 8
    totalRewards = 1000
    stakedPortion = 2
    userRewards = $500

14. Bob claiming rewards on week 8
    lastClaimWeek = 7
    currentWeek = 8
    totalRewards = 1000
    stakedPortion = 4
    userRewards = $250
