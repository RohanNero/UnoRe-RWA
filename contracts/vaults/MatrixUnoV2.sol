//SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

/**@notice this contract is a vault contract with some custom additions */
import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
/**@notice used to interact with multiple ERC20 token contracts */
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
/**@notice used to update contract values weekly for reward calculation */
import "@chainlink/contracts/src/v0.8/AutomationCompatible.sol";
/**@notice used when swapping STBT into stablecoins for user rewards */
import "../Curve/interfaces/IStableSwap.sol";
/**@notice used in testing to ensure values are set correctly */
import "hardhat/console.sol";

/**notice used to revert function calls that pass zero as the `amount` */
error MatrixUno__ZeroAmountGiven();
/**@param tokenId - corresponds to the `stables` indices */
error MatrixUno__InvalidTokenId(uint tokenId);
/**@param vaultBalance - the amount of shares the vault currently has
   @param transferAmount - the amount of shares that would be transferred to the user */
error MatrixUno__NotEnoughShares(uint vaultBalance, uint transferAmount);
/**@notice used when `performUpkeep()` is called before a week has passed */
error MatrixUno__UpkeepNotReady();
/**@notice used when calling `_claim` to ensure the user can claim rewards */
error MatrixUno__CannotClaimYet();

/**@title MatrixUno
 *@author Rohan Nero
 *@notice this contract allows UNO users to earn native STBT yields from Matrixdock.
 *@dev This vault uses STBT as the asset and xUNO as the shares token*/
contract MatrixUnoV2 is ERC4626, AutomationCompatibleInterface {
    /**@notice the STBT/3CRV pool used for withdrawals
     *@dev used to convert STBT rewards into stablecoins for users
     *@dev Ethereum mainnet address: 0x892d701d94a43bdbcb5ea28891daca2fa22a690b */
    IStableSwap private immutable pool;

    /**@notice STBT token address used as the vault asset
     *@dev Ethereum mainnet address: 0x530824da86689c9c17cdc2871ff29b058345b44a */
    IERC20 private immutable stbt;

    /**@notice The stablecoins that this contract can hold */
    IERC20 private dai;
    IERC20 private usdc;
    IERC20 private usdt;

    /**@notice this struct includes a list of variables that get updated inside the rewardInfoArray every week
     *@dev each struct corresponds to a different week since the contract's inception */
    struct weeklyRewardInfo {
        uint rewards; // amount of STBT rewards earned by the vault
        uint vaultAssetBalance; // total amount of assets deposited into the vault
        uint previousWeekBalance; // the total STBT in the vault the previous week (last `performUpkeep()` call)
        uint rewardsClaimed; // amount of STBT rewards that were claimed
        uint currentBalance; // total amount of assets in the vault, deposited or sent from MatrixPort
        uint deposited; // amount of STBT deposited into the vault
        uint withdrawn; // amount of STBT withdrawn from the vault
    }

    /**@notice this struct includes a variable that represents stablecoin balances as well as the last claim week*/
    struct claimInfo {
        uint[3] balances;
        uint16 lastClaimedWeek;
        uint totalAmountClaimed;
    }

    /**@notice each index corresponds to a week
     *@dev index 0 is the contract's first week of being deployed
     *@dev starting at startingTimestamp, ending at startingTimestamp + SECONDS_IN_WEEK */
    weeklyRewardInfo[] private rewardInfoArray;

    /**@notice Array of the stablecoin addresses
     *@dev 0 = DAI, 1 = USDC, 2= USDT*/
    address[3] private stables;

    /**@notice User stablecoin balances and week index of their last claim */
    mapping(address => claimInfo) private claimInfoMap;

    /**@notice tracks the amount of STBT each user has claimed */
    mapping(address => uint) private claimed;

    /**@notice tracks the total amount of STBT claimed by users */
    uint private totalClaimed;

    /**@notice the amount of STBT deposited by Uno Re */
    uint private initialAmount;

    /**@notice the current amount of STBT deposited in the vault by Uno Re */
    uint private currentAmount;

    /**@notice Uno Re's address used for depositing STBT */
    address private immutable uno;

    /**@notice the starting timestamp set once inside constructor */
    uint private immutable startingTimestamp;

    /**@notice constant variable representing the number of seconds in a week */
    uint private constant SECONDS_IN_WEEK = 604800;

    /**@notice last timestamp that performUpkeep() was called */
    uint private lastUpkeepTime;

    /**@notice need to provide the asset that is used in this vault
     *@dev vault shares are an ERC20 called "Matrix UNO"/"xUNO", these represent a user's stablecoin stake into an UNO-RWA pool
     *@param asset - the IERC contract you wish to use as the vault asset, in this case STBT
     *@param poolAddress - the STBT/3CRV pool
     *@param unoAddress - the EOA that Uno Re owns and has gotten whitelisted by STBT
     *@param stablecoins - array of stablecoin addresses (DAI/USDC/USDT)
     */
    constructor(
        address asset,
        address poolAddress,
        address unoAddress,
        address[3] memory stablecoins
    ) ERC4626(IERC20(asset)) ERC20("Matrix UNO", "xUNO") {
        stbt = IERC20(asset);
        pool = IStableSwap(poolAddress);
        uno = unoAddress;
        stables = stablecoins;
        dai = IERC20(stables[0]);
        usdc = IERC20(stables[1]);
        usdt = IERC20(stables[2]);
        startingTimestamp = block.timestamp;
        lastUpkeepTime = block.timestamp;
        rewardInfoArray[0].previousWeekBalance = 2e23;
    }

    /** USER FUNCTIONS */

    /**@notice this function allows users to stake stablecoins for xUNO
     *@dev this contract holds the stablecoins and transfers xUNO from its balance
     *@param amount - the amount of stablecoin to deposit
     *@param token - the stablecoin to deposit (DAI = 0, USDC = 1, USDT = 2)
     */
    function stake(uint amount, uint8 token) public returns (uint shares) {
        /**@notice all the logic checks come before actually moving the tokens */
        if (amount == 0) {
            revert MatrixUno__ZeroAmountGiven();
        }
        if (token > 2) {
            revert MatrixUno__InvalidTokenId(token);
        }
        /**  Transfer xUNO from the vault to the user
         Must add 12 zeros if user deposited USDC/USDT since these coins use 6 decimals
         DAI = 18 decimals, USDT/USDC = 6 decimals
         100 DAI  = 100000000000000000000
         100 USDC = 100000000 */
        uint transferAmount;
        if (token > 0) {
            transferAmount = amount * 1e12;
        } else {
            transferAmount = amount;
        }
        /** If there's less xUNO than the user is supposed to receive, the amount staked is equal to the amount of xUNO left */
        uint transferFromAmount;
        console.log("balanceOf:", this.balanceOf(address(this)));
        if (this.balanceOf(address(this)) < transferAmount) {
            if (token > 0) {
                transferFromAmount = this.balanceOf(address(this)) / 1e12;
            } else {
                transferFromAmount = this.balanceOf(address(this));
            }
        } else {
            transferFromAmount = amount;
        }
        console.log("transferFrom:", transferFromAmount);
        /** Actually moving the tokens and updating balance */
        IERC20(stables[token]).transferFrom(
            msg.sender,
            address(this),
            transferFromAmount
        );
        _claim(msg.sender);
        claimInfoMap[msg.sender].balances[token] += transferFromAmount;
        console.log("transferAmount:", transferAmount);
        console.log("msg.sender:", msg.sender);
        transfer(msg.sender, transferAmount);
        shares = transferAmount;
    }

    /**@notice this function allows users to claim their stablecoins plus accrued rewards
     *@dev requires approving this contract to take the xUNO first
     *@param amount - the amount of xUNO you want to return to the vault
     *@param token - the stablecoin you want your interest to be in
     *@dev (currently must match the deposited stable)*/
    function unstake(uint amount, uint8 token) public returns (uint) {
        /** Steps to claim
      1. approve xUNO
      2. xUNO transferFrom to vault
      3. user balance updated
      4. STBT earned by user will be exchaned for 3CRV
      5. 3CRV will be exchanged for the stablecoin user deposited
      6. stablecoin deposit and stablecoin interest are transferred to user
     */
        if (amount == 0) {
            revert MatrixUno__ZeroAmountGiven();
        }
        if (token > 2) {
            revert MatrixUno__InvalidTokenId(token);
        }
        this.transferFrom(msg.sender, address(this), amount);
        //uint stableBalance = claimInfoMap[msg.sender].balances[token];
        //uint rewards; // minimumRecieved used instead
        //  if(token > 0) {
        //   balances[msg.sender][token] -= (amount / 1e12);
        //  } else {
        //   balances[msg.sender][token] -= amount;
        //  }
        //console.log("subtractAmount:", subtractAmount);

        // calculate rewards earned by user
        // uint claimedByOthers = totalClaimed - claimed[msg.sender];
        // uint pot = viewRedeemable() + claimedByOthers;
        // uint earned = pot / viewPortion();
        uint earned = _claim(msg.sender);
        // updating global variables
        if (token > 0) {
            claimInfoMap[msg.sender].balances[token] -= (amount / 1e12);
        } else {
            claimInfoMap[msg.sender].balances[token] -= amount;
        }
        totalClaimed += earned;
        claimInfoMap[msg.sender].totalAmountClaimed += earned;

        // swap STBT into stable and send to user
        return _swap(earned, token, msg.sender);
    }

    /**@notice allows users to claim their staking rewards without unstaking
     *@dev calculates the amount of rewards a user is owed and sends it to them
     *@dev this function is called by unstake */
    function claim(uint8 token) public returns (uint earned) {
        // calculate amount earned
        earned = _claim(msg.sender);
        // swap STBT into stable and send to user
        return _swap(earned, token, msg.sender);
    }

    /** Native ERC-4626 Vault functions */

    /** @dev See {IERC4626-deposit}. */
    function deposit(
        uint256 assets,
        address receiver
    ) public virtual override returns (uint256) {
        require(
            assets <= maxDeposit(receiver),
            "ERC4626: deposit more than max"
        );

        uint256 shares = previewDeposit(assets);
        _deposit(_msgSender(), receiver, assets, shares);
        /**@notice custom MatrixUno logic to track STBT deposited by Uno Re */
        if (receiver == address(this) && msg.sender == uno) {
            initialAmount = assets;
        }

        return shares;
    }

    /** Chainlink Automation functions */

    /**@notice this function will call `performUpkeep()` when upkeepNeeded is true
     *@dev returns true when one week has passed since the last `performUpkeep()` call
     */
    function checkUpkeep(
        bytes calldata /* checkData */
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory /* performData */)
    {
        upkeepNeeded = (block.timestamp - lastUpkeepTime) > SECONDS_IN_WEEK;
    }

    /**@notice this function is called by Chainlink weekly to update values for reward calculation
     *@dev is only called once `checkUpkeep()` returns true */
    function performUpkeep(bytes calldata /* performData */) external override {
        // It's highly recommended to revalidate the upkeep in the performUpkeep function
        if ((block.timestamp - lastUpkeepTime) < SECONDS_IN_WEEK) {
            revert MatrixUno__UpkeepNotReady();
        }
        lastUpkeepTime = block.timestamp;
        // Most important task performUpkeep does is to set the weeklyRewardInfo for the week
        // This is crucial because the weeklyRewardInfo is used in user's reward calculation

        uint currentWeek = viewCurrentWeek();
        // set `currentBalance` for the current week
        rewardInfoArray[currentWeek].currentBalance = stbt.balanceOf(
            address(this)
        );
        weeklyRewardInfo memory currentInfo = rewardInfoArray[currentWeek];
        //`rewardsPerWeek` = (`currentBalance` + `claimedPerWeek` + `withdrawn` ) - (`lastWeekBalance` + `deposited`)
        rewardInfoArray[currentWeek].rewards =
            (currentInfo.currentBalance +
                currentInfo.rewardsClaimed +
                currentInfo.withdrawn) -
            (currentInfo.previousWeekBalance + currentInfo.deposited);
        // Set the `previousWeekBalance` variable unless it's still week 0
        if (currentWeek > 0) {
            rewardInfoArray[currentWeek].previousWeekBalance = rewardInfoArray[
                currentWeek - 1
            ].currentBalance;
        }
        // uint rewards; this will be calculated inside this function
        // uint vaultAssetBalance; already set
        // uint previousWeekBalance; MAY REMOVE THIS VARIABLE SINCE IT CAN BE FOUND BY VIEWING CURRENT BALANCE FOR PREVIOUS WEEK
        // uint rewardsClaimed; already set
        // uint currentBalance; view stbt.balanceOf(address(this))
        // uint deposited; already set
        // uint withdrawn; already set
    }

    /** Internal and Private functions */

    /**@notice contains the reward calculation logic
     *@dev this function is called by `claim` and `unstake`  */
    function _claim(address addr) private view returns (uint) {
        uint lastClaimWeek = claimInfoMap[addr].lastClaimedWeek;
        uint currentWeek = viewCurrentWeek();
        if (lastClaimWeek >= currentWeek) {
            revert MatrixUno__CannotClaimYet();
        }
        uint totalRewards = 0;
        for (uint i = lastClaimWeek; i < currentWeek; i++) {
            uint stakedPortion = viewPortionAt(i, addr);
            if (stakedPortion > 0) {
                uint userRewards = rewardInfoArray[i].rewards / stakedPortion;
                totalRewards += userRewards;
            }
        }
        return totalRewards;
    }

    function _swap(
        uint earned,
        uint8 token,
        address receiver
    ) private returns (uint) {
        uint stableBalance = claimInfoMap[receiver].balances[token];
        // transfer earned STBT to STBT/3CRV pool and exchange for stablecoin
        uint minimumReceive = earned * (99e16);
        // 99% of the earned amount (.01)
        if (token > 0) {
            minimumReceive /= 1e30;
        } else {
            minimumReceive /= 1e18;
        }
        // console.log("earned:", earned);
        // console.log("minimumReceive:", minimumReceive);
        stbt.approve(address(pool), earned);
        pool.exchange_underlying(
            int128(0),
            int128(uint128(token + 1)),
            earned,
            minimumReceive
        );
        // finally transfer stablecoins to user
        IERC20(stables[token]).transfer(
            receiver,
            stableBalance + minimumReceive
        );
        return stableBalance + minimumReceive;
    }

    /** View / Pure functions */

    /**@notice this function lets you view the stablecoin balances of users
     *@param addr the owner of the balance you are viewing
     *@param token is the tokenId of the stablecoin you want to view  */
    function viewBalance(
        address addr,
        uint8 token
    ) public view returns (uint256 balance) {
        balance = claimInfoMap[addr].balances[token];
    }

    /**@notice this function returns the totalClaimed variable */
    function viewTotalClaimed() public view returns (uint _totalClaimed) {
        _totalClaimed = totalClaimed;
    }

    /**@notice this function returns the total amount of STBT that can be redeemed for stablecoins */
    function viewRedeemable() public view returns (uint redeemable) {
        redeemable = this.totalAssets() - initialAmount;
    }

    /**@notice this function returns the amount of times that the users totalStaked goes into the initialAmount at given week
     *@dev essentially views what portion of the STBT is being represented by the user
     *@dev for example: user who staked $50,000 DAI would have portion of 4. (1/4 of initialAmount)
     *@param week is the rewardInfoArray index that you'd like to view portion from
     *@param addr is the user's portion you are viewing */
    function viewPortionAt(
        uint week,
        address addr
    ) public view returns (uint portion) {
        uint daiStaked = claimInfoMap[addr].balances[0];
        uint usdcStaked = claimInfoMap[addr].balances[1] * 1e12;
        uint usdtStaked = claimInfoMap[addr].balances[2] * 1e12;
        uint totalStaked = daiStaked + usdcStaked + usdtStaked;
        console.log("dai staked:", daiStaked);
        console.log("usdc staked:", usdcStaked);
        console.log("usdt staked:", usdtStaked);
        console.log("total staked:", totalStaked);
        console.log("initialAmount", initialAmount);
        if (totalStaked > 0) {
            portion = rewardInfoArray[week].vaultAssetBalance / totalStaked;
        } else {
            portion = 0;
        }
        console.log("portion:", portion);
    }

    /**@notice this function returns the amount of times that the users totalStaked goes into the initialAmount currently
     *@dev essentially views what portion of the STBT is being represented by the user
     *@dev for example: user who staked $50,000 DAI would have portion of 4. (1/4 of initialAmount) */
    function viewCurrentPortion(
        address addr
    ) public view returns (uint portion) {
        uint daiStaked = claimInfoMap[addr].balances[0];
        uint usdcStaked = claimInfoMap[addr].balances[1] * 1e12;
        uint usdtStaked = claimInfoMap[addr].balances[2] * 1e12;
        uint totalStaked = daiStaked + usdcStaked + usdtStaked;
        console.log("dai staked:", daiStaked);
        console.log("usdc staked:", usdcStaked);
        console.log("usdt staked:", usdtStaked);
        console.log("total staked:", totalStaked);
        console.log("initialAmount", initialAmount);
        if (totalStaked > 0) {
            uint index = (block.timestamp - startingTimestamp) /
                SECONDS_IN_WEEK;
            portion = rewardInfoArray[index].vaultAssetBalance / totalStaked;
        } else {
            portion = 0;
        }
        console.log("portion:", portion);
    }

    /**@notice this function returns what week the contract is currently at
     *@dev week 0 is the time frame from startingTimestamp to startingTimestamp + SECONDS_IN_WEEK */
    function viewCurrentWeek() public view returns (uint) {
        return (block.timestamp - startingTimestamp) / SECONDS_IN_WEEK;
    }
}
