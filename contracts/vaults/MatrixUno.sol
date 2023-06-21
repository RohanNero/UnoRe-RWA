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
/**@notice uses to screen addresses prior to staking */
import "../interfaces/ISanctionsList.sol";
/**@notice used in testing to ensure values are set correctly */
import "hardhat/console.sol";
/**@notice used in reward calculation math */
import "abdk-libraries-solidity/ABDKMath64x64.sol";

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
/**@notice used when calling `stake` to ensure the user isn't a sanctioned entity */
error MatrixUno__SanctionedAddress();
/**@notice used when calling `unoClaim` to ensure msg.sender is uno */
error MatrixUno__OnlyUno();
/**@notice used inside of `_swap()` to catch if the exchange fails */
error MatrixUno__StableSwapFailed();

/**@title MatrixUno
 *@author Rohan Nero
 *@notice this contract allows UNO users to earn native STBT yields from Matrixdock.
 *@dev This vault uses STBT as the asset and xUNO as the shares token*/
contract MatrixUno is ERC4626, AutomationCompatibleInterface {
    /**@notice declare that we are using ABDK Math library for these variabels */
    using ABDKMath64x64 for uint;
    using ABDKMath64x64 for int128;

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

    /**@notice used to screen users prior to being allowed to stake */
    ISanctionsList private sanctionsList;

    /**@notice this struct includes a list of variables that get updated inside the rewardInfoArray every week
     *@dev each struct corresponds to a different week since the contract's inception */
    struct weeklyRewardInfo {
        uint rewards; // amount of STBT rewards earned by the vault during the week
        uint vaultAssetBalance; // total amount of assets DEPOSITED into the vault
        uint previousWeekBalance; // total STBT in the vault the previous week (last `performUpkeep()` call)
        uint claimed; // amount of STBT rewards that were claimed during the week
        uint currentBalance; // total amount of assets in the vault, deposited or sent from MatrixPort as rewards
        uint deposited; // amount of STBT deposited into the vault during the week
        uint withdrawn; // amount of STBT withdrawn from the vault during the week
    }

    /**@notice this struct includes a variable that represents stablecoin balances as well as the last claim week */
    struct claimInfo {
        uint[3] balances;
        uint16 lastClaimWeek;
        uint totalAmountClaimed;
    }

    /**@notice each index corresponds to a week
     *@dev index 0 is the contract's first week of being deployed
     *@dev starting at i_startingTimestamp, ending at i_startingTimestamp +i_interval */
    weeklyRewardInfo[] private rewardInfoArray;

    /**@notice Array of the stablecoin addresses
     *@dev 0 = DAI, 1 = USDC, 2= USDT*/
    address[3] private stables;

    /**@notice User stablecoin balances and week index of their last claim */
    mapping(address => claimInfo) private claimInfoMap;

    /**@notice tracks the total amount of stablecoins staked
     *@dev USDC/UDST were converted into 18 decimals */
    uint private totalStaked;

    /**@notice tracks the total amount of STBT claimed by users */
    uint private totalClaimed;

    /**@notice the amount of STBT deposited by Uno Re */
    uint private unoDepositAmount;

    /**@notice Uno Re's address used for depositing STBT */
    address private immutable uno;

    /**@notice the starting timestamp set once inside constructor */
    uint private immutable i_startingTimestamp;

    /**@notice immutable variable representing the number of seconds in ani_interval
     *@dev originally was constant variable set to one week (604800) */
    uint private immutable i_interval;

    /**@notice last timestamp that performUpkeep() was called */
    uint private lastUpkeepTime;

    /**@notice the total amount of rewards earned by Uno Re as opposed to users
     *@dev Uno Re can claim this amount at any time*/
    uint private unaccountedRewards;

    /**@notice emits when uno calls `UnoClaim()`
     *@param amountClaimed is the amount of STBT sent to `uno` */
    event UnoClaim(uint amountClaimed);

    /**@notice used for testing, remove after done testing. */
    event transferInfo(uint _amount, uint _receive);
    event actual(uint actualRec);

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
        address sanctionsAddress,
        address[3] memory stablecoins,
        uint interval
    ) ERC4626(IERC20(asset)) ERC20("Matrix UNO", "xUNO") {
        stbt = IERC20(asset);
        pool = IStableSwap(poolAddress);
        uno = unoAddress;
        sanctionsList = ISanctionsList(sanctionsAddress);
        stables = stablecoins;
        dai = IERC20(stables[0]);
        usdc = IERC20(stables[1]);
        usdt = IERC20(stables[2]);
        i_startingTimestamp = block.timestamp;
        lastUpkeepTime = block.timestamp;
        i_interval = interval;
        //rewardInfoArray[0].previousWeekBalance = 2e23;
        // 200,000 STBT with 18 decimals
        rewardInfoArray.push(weeklyRewardInfo(0, 0, 0, 0, 0, 0, 0));
    }

    /**@notice this function allows users to stake stablecoins for xUNO
     *@dev this contract holds the stablecoins and transfers xUNO from its balance
     *@param amount - the amount of stablecoin to deposit
     *@param token - the stablecoin to deposit (DAI = 0, USDC = 1, USDT = 2)
     */
    function stake(
        uint amount,
        uint8 token,
        uint minimumPercentage
    ) public returns (uint shares) {
        /**@notice all the logic checks come before actually moving the tokens */
        if (amount == 0) {
            revert MatrixUno__ZeroAmountGiven();
        }
        if (token > 2) {
            revert MatrixUno__InvalidTokenId(token);
        }
        if (sanctionsList.isSanctioned(msg.sender)) {
            revert MatrixUno__SanctionedAddress();
        }
        /**  Transfer xUNO from the vault to the user
         Must add 12 zeros if user deposited USDC/USDT since these coins use 6 decimals
         DAI = 18 decimals, USDT/USDC = 6 decimals
         100 DAI  = 100 000000000000000000
         100 USDC = 100 000000 */
        uint transferAmount;
        if (token > 0) {
            transferAmount = amount * 1e12;
        } else {
            transferAmount = amount;
        }
        /** If there's less xUNO than the user is supposed to receive, the amount staked is equal to the amount of xUNO left */
        uint transferFromAmount;
        //console.log("balanceOf:", balanceOf(address(this)));
        if (this.balanceOf(address(this)) < transferAmount) {
            if (token > 0) {
                transferFromAmount = this.balanceOf(address(this)) / 1e12;
            } else {
                transferFromAmount = this.balanceOf(address(this));
            }
        } else {
            transferFromAmount = amount;
        }
        //console.log("transferFrom:", transferFromAmount);
        /** Actually moving the tokens and updating balance */
        IERC20(stables[token]).transferFrom(
            msg.sender,
            address(this),
            transferFromAmount
        );
        uint totalRewards = _claim(msg.sender);
        if (totalRewards > 0) {
            totalClaimed += totalRewards;
            rewardInfoArray[viewCurrentWeek()].claimed += totalRewards;
            uint minimumReceive = _swap(totalRewards, token, minimumPercentage);
            // since user is staking, send only the rewards
            IERC20(stables[token]).transfer(msg.sender, minimumReceive);
        }

        claimInfoMap[msg.sender].balances[token] += transferFromAmount;
        claimInfoMap[msg.sender].lastClaimWeek = uint16(viewCurrentWeek());
        // Updating `totalStaked` depending on how many decimals `token` has
        if (token > 0) {
            totalStaked += transferFromAmount * 1e12;
        } else {
            totalStaked += transferFromAmount;
        }

        // console.log("transferAmount:", transferAmount);
        // console.log(balanceOf(address(this)));
        // console.log("msg.sender:", msg.sender);
        this.transfer(msg.sender, transferAmount);
        //console.log("transferred");
        shares = transferAmount;
    }

    /**@notice this function allows users to unstake their stablecoins plus accrued rewards
     *@dev requires approving this contract to take the xUNO first
     *@param amount - the amount of xUNO you want to return to the vault
     *@param token - the stablecoin you want your interest to be in
     *@dev (currently must match the deposited stable)*/
    function unstake(
        uint amount,
        uint8 token,
        uint minimumPercentage
    ) public returns (uint) {
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
        // grab the xUNO from the user
        this.transferFrom(msg.sender, address(this), amount);
        console.log("unstake checkpoint 1");
        // calculate rewards owed to user
        uint totalRewards = _claim(msg.sender);
        console.log("unstake checkpoint 2");
        // swap STBT into stable and send to user
        uint received = _swap(totalRewards, token, minimumPercentage);
        console.log("unstake checkpoint 3");
        uint adjustedAmount;
        if (token > 0) {
            adjustedAmount = amount / 1e12;
        } else {
            adjustedAmount = amount;
        }
        console.log("unstake checkpoint 4");
        // since user is unstaking, send rewards plus the balance
        console.log("amount:", adjustedAmount);
        console.log("minimumReceive:", received);
        console.log("transferAmount:", adjustedAmount + received);
        console.log("usdcBalance:", usdc.balanceOf(address(this)));
        // updating global variables
        console.log("unstake checkpoint 5");
        console.log("currentWeek:", viewCurrentWeek());
        rewardInfoArray[viewCurrentWeek()].claimed += totalRewards;
        console.log("unstake checkpoint 6");
        totalClaimed += totalRewards;
        claimInfoMap[msg.sender].totalAmountClaimed += totalRewards;
        claimInfoMap[msg.sender].balances[token] -= adjustedAmount;
        claimInfoMap[msg.sender].lastClaimWeek = uint16(viewCurrentWeek());
        totalStaked -= adjustedAmount;
        emit transferInfo(adjustedAmount, received);
        IERC20(stables[token]).transfer(msg.sender, adjustedAmount + received);
        console.log("unstake checkpoint 7");
        return amount + received;
    }

    /**@notice allows users to claim their staking rewards without unstaking
     *@dev calculates the amount of rewards a user is owed and sends it to them
     *@dev this function is called by unstake */
    function claim(uint8 token, uint minimumPercentage) public returns (uint) {
        // calculate amount earned
        uint totalRewards = _claim(msg.sender);
        totalClaimed += totalRewards;
        rewardInfoArray[viewCurrentWeek()].claimed += totalRewards;
        claimInfoMap[msg.sender].lastClaimWeek = uint16(viewCurrentWeek());
        uint minimumReceive = _swap(totalRewards, token, minimumPercentage);
        // since user is claiming, send only the rewards
        IERC20(stables[token]).transfer(msg.sender, minimumReceive);
        return totalRewards;
    }

    /**@notice allows uno to claim the `unaccountedRewards` */
    function unoClaim() public {
        if (msg.sender != uno) {
            revert MatrixUno__OnlyUno();
        }
        stbt.transfer(uno, unaccountedRewards);
        emit UnoClaim(unaccountedRewards);
        unaccountedRewards = 0;
    }

    /**@notice ERC-4626 but with some custom logic for calls from `uno`
     *@dev See {IERC4626-deposit}. */
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
            unoDepositAmount += assets;
        }
        rewardInfoArray[viewCurrentWeek()].deposited += assets;
        rewardInfoArray[viewCurrentWeek()].vaultAssetBalance += assets;
        return shares;
    }

    /**@notice ERC-4626 but with some custom logic for calls from `uno`
     *@dev See {IERC4626-deposit}. */
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public virtual override returns (uint256) {
        require(
            assets <= maxWithdraw(owner),
            "ERC4626: withdraw more than max"
        );

        uint256 shares = previewWithdraw(assets);
        _withdraw(_msgSender(), receiver, owner, assets, shares);
        /**@notice custom MatrixUno logic to track STBT withdrawn by Uno Re */
        if (msg.sender == uno) {
            unoDepositAmount -= assets;
        }
        rewardInfoArray[viewCurrentWeek()].withdrawn += assets;
        rewardInfoArray[viewCurrentWeek()].vaultAssetBalance -= assets;
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
        console.log("lastUpkeepTime:", lastUpkeepTime);
        console.log("difference:", block.timestamp - lastUpkeepTime);
        upkeepNeeded = (block.timestamp - lastUpkeepTime) > i_interval;
    }

    /**@notice this function is called by Chainlink weekly to update values for reward calculation
     *@dev is only called once `checkUpkeep()` returns true */
    function performUpkeep(bytes calldata /* performData */) external override {
        // It's highly recommended to revalidate the upkeep in the performUpkeep function
        if ((block.timestamp - lastUpkeepTime) < i_interval) {
            revert MatrixUno__UpkeepNotReady();
        }
        lastUpkeepTime = block.timestamp;
        // Most important task performUpkeep does is to set the weeklyRewardInfo for the week
        // This is crucial because the weeklyRewardInfo is used in user's reward calculation

        uint currentWeek = viewCurrentWeek();
        // set `currentBalance` for the current week
        uint currentStbt = stbt.balanceOf(address(this));
        rewardInfoArray[currentWeek - 1].currentBalance = currentStbt;
        console.log("checkpoint 0");
        weeklyRewardInfo memory currentInfo = rewardInfoArray[currentWeek - 1];
        //`rewardsPerWeek` = (`currentBalance` + `claimedPerWeek` + `withdrawn` ) - (`lastWeekBalance` + `deposited`)
        console.log("checkpoint 1");
        console.log("currentBalance:", currentInfo.currentBalance);
        console.log("claimed:", currentInfo.claimed);
        console.log("withdrawn:", currentInfo.withdrawn);
        console.log("previous:", currentInfo.previousWeekBalance);
        console.log("deposited:", currentInfo.deposited);
        if (
            (currentInfo.currentBalance +
                currentInfo.claimed +
                currentInfo.withdrawn) <
            (currentInfo.previousWeekBalance + currentInfo.deposited)
        ) {
            rewardInfoArray[currentWeek - 1].rewards = 0;
        } else {
            rewardInfoArray[currentWeek - 1].rewards =
                (currentInfo.currentBalance +
                    currentInfo.claimed +
                    currentInfo.withdrawn) -
                (currentInfo.previousWeekBalance + currentInfo.deposited);
            unaccountedRewards += calculateUnaccountedRewards();
        }

        console.log("checkpoint 2");
        // push a new struct to the array with only the `previousWeekBalance`
        rewardInfoArray.push(
            weeklyRewardInfo(
                0,
                currentInfo.vaultAssetBalance,
                currentStbt,
                0,
                0,
                0,
                0
            )
        );
        console.log("checkpoint 3");
        // increment the `unaccountedRewards` variable
        console.log("currentBalance:", currentInfo.currentBalance);
        console.log("uno deposit:", unoDepositAmount);
        console.log("rewards:", rewardInfoArray[currentWeek - 1].rewards);
        // unaccountedRewards += (rewardInfoArray[currentWeek - 1].rewards /
        //     (currentInfo.currentBalance / unoDepositAmount));
        console.log("checkpoint 4");
    }

    /** Internal and Private functions */

    /**@notice contains the reward calculation logic
     *@dev this function is called by `claim` and `unstake`  */
    function _claim(address addr) private view returns (uint) {
        uint lastClaimWeek = claimInfoMap[addr].lastClaimWeek;
        uint currentWeek = viewCurrentWeek();
        uint totalRewards = 0;
        for (uint i = lastClaimWeek; i < currentWeek; i++) {
            int128 stakedPortion = viewPortionAt(i, addr);
            if (stakedPortion > 0) {
                //uint userRewards = rewardInfoArray[i].rewards / stakedPortion;
                uint userRewards = stakedPortion.mulu(
                    rewardInfoArray[i].rewards
                );
                console.log("userRewards:", userRewards);
                totalRewards += userRewards;
            }
        }
        console.log("for loop passed");
        console.log("totalRewards:", totalRewards);
        // Temporarily adding 12 zeros during testing since it keeps returning with only 6 decimals instead of 18 (we want 18)
        return totalRewards;
    }

    /**@notice handles swapping STBT into stablecoins by using the Curve finance STBT/3CRV pool
     *@param earned is the total STBT rewards earned by the user
     *@param token corresponds to the `stables` array index */
    function _swap(
        uint earned,
        uint8 token,
        uint minimumPercentage
    ) private returns (uint) {
        // transfer earned STBT to STBT/3CRV pool and exchange for stablecoin
        uint minimumReceive;
        int128 formatPercentage = minimumPercentage.fromUInt();
        if (token > 0) {
            minimumReceive = formatPercentage.mulu(earned) / 1e14;
            console.log("reached:", minimumReceive);
        } else {
            minimumReceive = formatPercentage.mulu(earned) / 100;
        }
        console.log("SWAP");
        console.log("earned:", earned);
        console.log("token:", token);
        console.log("minimumPercentage:", minimumPercentage);
        console.log("minimumReceive:", minimumReceive);
        stbt.approve(address(pool), earned);
        //try
        uint actualReceived = pool.exchange_underlying(
            int128(0),
            int128(uint128(token + 1)),
            earned,
            minimumReceive
        );
        //returns (uint actualReceived) {
        console.log("try reached");
        console.log("actual:", actualReceived);
        emit actual(actualReceived);
        return actualReceived;
        //} catch {
        //    revert MatrixUno__StableSwapFailed();
        //}
        // uint actualReceived = pool.exchange_underlying(
        //     int128(0),
        //     int128(uint128(token + 1)),
        //     earned,
        //     minimumReceive
        // );
        // return actualReceived;
    }

    /** View / Pure functions */

    /**@notice returns the curve pool address */
    function viewPoolAddress() public view returns (address) {
        return address(pool);
    }

    /**@notice returns the address that Uno Re will use to deposit/withdraw STBT */
    function viewUnoAddress() public view returns (address) {
        return uno;
    }

    /**@notice returns addresses of DAI/UDSC/USDT used by this contract */
    function viewStables() public view returns (address[3] memory) {
        return stables;
    }

    /**@notice returns the sanctionsList contract address */
    function viewSanctionsList() public view returns (address) {
        return address(sanctionsList);
    }

    /**@notice returns the total amount of stablecoins in the vault */
    function viewVaultStableBalance()
        public
        view
        returns (uint totalStableBal)
    {
        uint daiBalance = dai.balanceOf(address(this));
        uint usdcBalance = usdc.balanceOf(address(this));
        uint usdtBalance = usdt.balanceOf(address(this));
        // Add 12 zeros to USDC and USDT because they only have 6 decimals
        totalStableBal =
            daiBalance +
            (usdcBalance * 1e12) +
            (usdtBalance * 1e12);
    }

    /**@notice this function returns the total amount of STBT that can be redeemed for stablecoins
     *@param week is the rewardInfoArray index that you'd like to view portion from */
    function viewRedeemableAt(uint week) public view returns (uint redeemable) {
        redeemable = totalAssets() - rewardInfoArray[week].vaultAssetBalance;
    }

    /**@notice this function returns the amount of times that the users totalStaked goes into the unoDepositAmount at given week
     *@dev essentially views what portion of the STBT is being represented by the user
     *@dev for example: user who staked $50,000 DAI would have portion of 4. (1/4 of unoDepositAmount)
     *@param week is the rewardInfoArray index that you'd like to view portion from
     *@param addr is the user's portion you are viewing */
    function viewPortionAt(
        uint week,
        address addr
    ) public view returns (int128 portion) {
        uint daiStaked = claimInfoMap[addr].balances[0];
        uint usdcStaked = claimInfoMap[addr].balances[1] * 1e12;
        uint usdtStaked = claimInfoMap[addr].balances[2] * 1e12;
        uint totalUserStaked = daiStaked + usdcStaked + usdtStaked;
        console.log("dai staked:", daiStaked);
        console.log("usdc staked:", usdcStaked);
        console.log("usdt staked:", usdtStaked);
        console.log("total staked:", totalUserStaked);
        console.log(
            "vaultAssetBalance",
            rewardInfoArray[week].vaultAssetBalance
        );
        if (totalUserStaked > 0 && unoDepositAmount > 0) {
            portion = totalUserStaked.divu(
                rewardInfoArray[week].vaultAssetBalance
            );
        } else {
            portion = 0;
        }
        //console.log("portion:", portion);
    }

    /**@notice this function returns the amount of times that the users totalStaked goes into the unoDepositAmount currently
     *@dev essentially views what portion of the STBT is being represented by the user
     *@dev for example: user who staked $50,000 DAI would have portion of 4. (1/4 of unoDepositAmount) */
    // function viewCurrentPortion(
    //     address addr
    // ) public view returns (int128 portion) {
    //     uint daiStaked = claimInfoMap[addr].balances[0];
    //     uint usdcStaked = claimInfoMap[addr].balances[1] * 1e12;
    //     uint usdtStaked = claimInfoMap[addr].balances[2] * 1e12;
    //     uint totalUserStaked = daiStaked + usdcStaked + usdtStaked;
    //     console.log("dai staked:", daiStaked);
    //     console.log("usdc staked:", usdcStaked);
    //     console.log("usdt staked:", usdtStaked);
    //     console.log("total staked:", totalUserStaked);
    //     console.log(
    //         "vaultAssetBalance",
    //         rewardInfoArray[viewCurrentWeek()].vaultAssetBalance
    //     );
    //     if (totalStaked > 0 && unoDepositAmount > 0) {
    //         portion = totalStaked.divu(
    //             rewardInfoArray[viewCurrentWeek()].vaultAssetBalance
    //         );
    //     } else {
    //         portion = 0;
    //     }
    //     //console.log("portion:", portion);
    // }

    /**@notice this function returns what week the contract is currently at
     *@dev week 0 is the time frame from i_startingTimestamp to i_startingTimestamp +i_interval */
    function viewCurrentWeek() public view returns (uint) {
        console.log("current:", block.timestamp);
        console.log("starting:", i_startingTimestamp);
        console.log("interval:", i_interval);
        console.log("difference:", (block.timestamp - i_startingTimestamp));
        console.log(
            "return:",
            (block.timestamp - i_startingTimestamp) / i_interval
        );
        return (block.timestamp - i_startingTimestamp) / i_interval;
    }

    /**@notice this function allows users to view the amount of rewards they currently have earned */
    function viewRewards() public view returns (uint totalRewards) {
        totalRewards = _claim(msg.sender);
    }

    /**@notice returns roughly the total amount of stablecoins that a user can withdraw
     *@dev this amount is not precise since STBT needs to be swapped for stablecoins and some slippage will occur */
    function viewTotalWithdrawable()
        public
        view
        returns (uint totalWithdrawable)
    {
        totalWithdrawable =
            _claim(msg.sender) +
            viewTotalStakedBalance(msg.sender);
    }

    /**@notice returns the rewardInfo struct for a given week
     *@param week corresponds to the rewardInfoArray index */
    function viewRewardInfo(
        uint week
    ) public view returns (weeklyRewardInfo memory) {
        return rewardInfoArray[week];
    }

    /**@notice this function lets you view the stablecoin balances of users
     *@param user the owner of the balance you are viewing
     *@param token is the tokenId of the stablecoin you want to view  */
    function viewStakedBalance(
        address user,
        uint8 token
    ) public view returns (uint256 balance) {
        balance = claimInfoMap[user].balances[token];
    }

    /**@notice this function returns the total amount of stablecoins a user has deposited
     *@param user the owner of the balance you are viewing */
    function viewTotalStakedBalance(
        address user
    ) public view returns (uint totalUserStaked) {
        uint daiBalance = viewStakedBalance(user, 0);
        uint usdcBalance = viewStakedBalance(user, 1);
        uint usdtBalance = viewStakedBalance(user, 2);
        // Add 12 zeros to USDC and USDT because they only have 6 decimals
        totalUserStaked =
            daiBalance +
            (usdcBalance * 1e12) +
            (usdtBalance * 1e12);
    }

    /**@notice returns the last week a user has claimed
     *@param user the address that has claimed */
    function viewLastClaimed(address user) public view returns (uint16) {
        return claimInfoMap[user].lastClaimWeek;
    }

    /**@notice returns the amount a user has claimed
     *@param user the address that has claimed */
    function viewClaimedAmount(address user) public view returns (uint) {
        return claimInfoMap[user].totalAmountClaimed;
    }

    /**@notice this function returns the totalClaimed variable */
    function viewTotalClaimed() public view returns (uint _totalClaimed) {
        _totalClaimed = totalClaimed;
    }

    /**@notice this function returns the totalStaked variable */
    function viewTotalStaked() public view returns (uint _totalStaked) {
        _totalStaked = totalStaked;
    }

    /**@notice returns the amount of STBT that Uno Re has deposited into the vault */
    function viewUnoDeposit() public view returns (uint) {
        return unoDepositAmount;
    }

    /**@notice returns the vault's starting timestamp */
    function viewStartingtime() public view returns (uint) {
        return i_startingTimestamp;
    }

    /**@notice returns the last time this contract had upkeep performed */
    function viewLastUpkeepTime() public view returns (uint) {
        return lastUpkeepTime;
    }

    /**@notice returns the seconds in each rewards period */
    function viewInterval() public view returns (uint) {
        return i_interval;
    }

    /**@notice returns the portion of rewards that are unaccounted for
     *@dev all unaccounted rewards are claimable by Uno Re's EOA */
    function calculateUnaccountedRewards() public view returns (uint) {
        uint currentWeek = viewCurrentWeek();
        if (unoDepositAmount < totalStaked) {
            return 0;
        } else {
            uint remainder = unoDepositAmount - totalStaked;
            int128 portion = remainder.divu(
                rewardInfoArray[currentWeek - 1].currentBalance
            );
            return portion.mulu(rewardInfoArray[currentWeek - 1].rewards);
        }

        // Example Scenario: 300,000 total STBT. 200,000 from UNO. 100,000 Deposited. 50,000 stablecoins staked.
        // Uno portion/unaccounted portion is 1/2 of total rewards
        // 200,000 - 50,000 = 150,000
        // 150,000 / 300,000 = .5
        // unaccounted portion = ((unoDepositAmount - totalStaked) / currentBalance)
        // unaccountedRewards = rewards * unaccountedPortion
    }

    /**@notice returns the amount of rewards that can be claimed by uno since they dont belong to any user
     *@dev current value of the `unaccountedRewards` variable */
    function viewUnaccountedRewards() public view returns (uint) {
        return unaccountedRewards;
    }
}
