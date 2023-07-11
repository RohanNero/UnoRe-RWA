//SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

/**@notice this contract is a vault contract with some custom additions */
import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
/**@notice used to interact with multiple ERC20 token contracts */
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
/**@notice used when swapping STBT into stablecoins for user rewards */
import "../Curve/interfaces/IStableSwap.sol";
/**@notice uses to screen addresses prior to staking */
import "../interfaces/ISanctionsList.sol";
/**@notice uses to interact with SSIP */
import "../interfaces/ISingleSidedInsurancePool.sol";
/**@notice used in testing to ensure values are set correctly */
import "hardhat/console.sol";
/**@notice used in reward calculation math */
import "abdk-libraries-solidity/ABDKMath64x64.sol";

/**notice used to revert function calls that pass zero as the `amount` */
error MatrixUno__ZeroAmountGiven();
/**@param tokenId - corresponds to the `stables` indices */
error MatrixUno__InvalidTokenId(uint tokenId);
// Instead of this, I think we just send the user what is left and refund the difference. May be revised further.
// /**@param vaultBalance - the amount of shares the vault currently has
//    @param transferAmount - the amount of shares that would be transferred to the user */
// error MatrixUno__NotEnoughShares(uint vaultBalance, uint transferAmount);
/**@notice used when `performUpkeep()` is called before a week has passed */
error MatrixUno__UpkeepNotReady();
/**@notice used when calling `stake` to ensure the user isn't a sanctioned entity */
error MatrixUno__SanctionedAddress();
/**@notice used when calling `unoClaim` to ensure msg.sender is uno */
error MatrixUno__OnlyUno();
/**@notice used inside of `_swap()` to catch if the exchange fails */
error MatrixUno__StableSwapFailed();
/**@notice used inside of `claim` to ensure the sender is claiming for themselves */
error MatrixUno__AddrMustBeSender(address sender, address addr);
/**@notice used inside `viewPortionAt()` to ensure the function doesn't try to access out-of-bounds index */
error MatrixUno__InvalidWeek(uint week);

/**@title MatrixUno
 *@author Rohan Nero
 *@notice this contract allows UNO users to earn native STBT yields from Matrixdock.
 *@dev This vault uses STBT as the asset and xUNO as the shares token*/
contract MatrixUno is ERC4626 {
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

    /**@notice used to interact with the SSIP */
    ISingleSidedInsurancePool private ssip;

    /**@notice this struct includes a list of variables that get updated inside the rewardInfoArray every week
     *@dev each struct corresponds to a different week since the contract's inception */
    struct rewardInfo {
        uint rewards; // amount of STBT rewards earned by the vault during the week
        uint vaultAssetBalance; // total amount of assets DEPOSITED into the vault
        uint previousWeekBalance; // total STBT in the vault the previous week (last `performUpkeep()` call)
        uint currentBalance; // TOTAL AMOUNT of assets in the vault, deposited or sent from MatrixPort as rewards (balanceOf)
        uint claimed; // amount of STBT rewards that were claimed during the week
        uint deposited; // amount of STBT deposited into the vault during the week
        uint withdrawn; // amount of STBT withdrawn from the vault during the week
        uint startTime; // starting timestamp of this reward period
        uint endTime; // ending timestamp of this reward period
    }

    /**@notice this struct includes a variable that represents stablecoin balances as well as the last claim week
     *@dev balances corresponds to the stable array indices (DAI = 0, USDC = 1, USDT = 2, STBT = 3, and xUNO = 4) */
    struct claimInfo {
        uint[5] balances;
        uint16 lastClaimPeriod;
        uint totalAmountClaimed;
    }

    /**@notice each index corresponds to a week
     *@dev index 0 is the contract's first week of being deployed
     *@dev starting at i_startingTimestamp, ending at i_startingTimestamp +i_interval */
    rewardInfo[] private rewardInfoArray;

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

    /**@notice emitted when perform upkeep is called */
    event UpkeepPerformed(rewardInfo info);

    /**@notice emitted when `claim` is called */
    event Claim(uint totalRewards, uint totalSRewards);

    /**@notice emitted when user stakes */
    event Stake(uint amount, address staker);

    /**@notice emitted when user unstakes */
    event Unstake(uint amount, address unstaker);

    /**@notice used for testing, remove after done testing. */
    event transferInfo(uint _amount, uint _receive);
    event actual(uint actualRec);
    event upkeep(bool needed, uint lastUpkeep);

    /**@notice used to check if the rewards are due to be updated */
    modifier calculateRewards() {
        if (this.checkUpkeep()) {
            this.performUpkeep();
        }
        _;
    }

    /**@notice used to update balances during ERC-20 transfers */
    modifier updatesBalance(uint, uint[3]) {
        _;
    }

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
        rewardInfoArray.push(
            rewardInfo(0, 0, 0, 0, 0, 0, 0, block.timestamp, 0)
        );
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
    ) public calculateRewards returns (uint shares) {
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
        // Using Curve's virtual price
        int128 conversionRate = viewStakeConversionRate();
        //console.log("balanceOf:", balanceOf(address(this)));
        if (this.balanceOf(address(this)) < transferAmount) {
            if (token > 0) {
                transferFromAmount = this.balanceOf(address(this)) / 1e12;
            } else {
                transferFromAmount = this.balanceOf(address(this));
            }
            transferAmount = conversionRate.mulu(this.balanceOf(address(this)));
        } else {
            transferFromAmount = amount;
            if (token > 0) {
                transferAmount = conversionRate.mulu(amount * 1e12);
            } else {
                transferAmount = conversionRate.mulu(amount);
            }
        }
        //console.log("transferFrom:", transferFromAmount);
        /** Actually moving the tokens and updating balance */
        IERC20(stables[token]).transferFrom(
            msg.sender,
            address(this),
            transferFromAmount
        );
        // Calling `claim`
        claim(msg.sender, token, minimumPercentage);
        // Increment balance and `totalStaked` on `stake()`
        claimInfoMap[msg.sender].balances[token] += transferFromAmount;
        claimInfoMap[msg.sender].balances[4] += transferAmount;
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
        // return shares
        emit Stake(transferFromAmount, msg.sender);
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
    ) public calculateRewards returns (uint) {
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
        claim(msg.sender, token, minimumPercentage);
        console.log("unstake checkpoint 2");
        // swap STBT into stable and send to user
        uint adjustedAmount;
        if (token > 0) {
            adjustedAmount = amount / 1e12;
        } else {
            adjustedAmount = amount;
        }
        // since user is unstaking, send rewards plus the balance
        console.log("unstake checkpoint 3");
        console.log("amount:", adjustedAmount);
        console.log("transferAmount:", adjustedAmount);
        console.log("usdcBalance:", usdc.balanceOf(address(this)));
        console.log("currentPeriod:", rewardInfoArray.length - 1);
        // updating global variables
        uint initialVaultBalance = claimInfoMap[msg.sender].balances[token];
        int128 conversionRate = viewUnstakeConversionRate();
        adjustedAmount = conversionRate.mulu(adjustedAmount);
        console.log("initialVaultBalance:", initialVaultBalance);
        console.log("adjustedAmount:", adjustedAmount);
        // temporary fix to the adjustedAmount being slightly larger than user balance
        // right now the math is probably causing this due to rounding or something
        if (adjustedAmount > initialVaultBalance) {
            console.log(
                "Over balance by:",
                adjustedAmount - initialVaultBalance
            );
            adjustedAmount = initialVaultBalance;
        }
        claimInfoMap[msg.sender].balances[token] -= adjustedAmount;
        claimInfoMap[msg.sender].balances[4] -= amount;
        if (token > 0) {
            totalStaked -= adjustedAmount * 1e12;
        } else {
            totalStaked -= adjustedAmount;
        }
        IERC20(stables[token]).transfer(msg.sender, initialVaultBalance);
        console.log("unstake checkpoint 7");
        // return total amount of stable received
        emit Unstake(initialVaultBalance, msg.sender);
        return amount;
    }

    /**@notice allows users to claim their staking rewards without unstaking
     *@dev calculates the amount of rewards a user is owed and sends it to them
     *@dev this function is called by unstake */
    function claim(
        address addr,
        uint8 token,
        uint minimumPercentage
    ) public calculateRewards returns (uint, uint) {
        // ensure msg.sender == addr or that this contract is calling
        if (msg.sender != addr && msg.sender != address(this)) {
            revert MatrixUno__AddrMustBeSender(msg.sender, addr);
        }
        // START _claim() START
        uint lastClaimPeriod = claimInfoMap[addr].lastClaimPeriod;
        uint currentPeriod = rewardInfoArray.length - 1;
        uint totalRewards = 0;
        uint totalSRewards = 0;
        for (uint i = lastClaimPeriod; i < currentPeriod; i++) {
            (int128 stakedPortion, int128 sPortion) = viewPortionAt(i, addr);
            if (stakedPortion > 0) {
                uint userRewards = stakedPortion.mulu(
                    rewardInfoArray[i].rewards
                );
                console.log("userRewards:", userRewards);
                totalRewards += userRewards;
            }
            if (sPortion > 0) {
                uint userSRewards = sPortion.mulu(rewardInfoArray[i].rewards);
                console.log("userSRewards:", userSRewards);
                totalSRewards += userSRewards;
            }
        }
        console.log("for loop passed");
        console.log("totalRewards:", totalRewards);
        console.log("totalSRewards:", totalSRewards);
        // END _claim() END

        // updating variables and sending stablecoin rewards after calling `_swap()`
        if (totalRewards > 0) {
            totalClaimed += totalRewards;
            rewardInfoArray[rewardInfoArray.length - 1].claimed += totalRewards;
            uint minimumReceive = _swap(totalRewards, token, minimumPercentage);
            // send stablecoin of type `token`
            IERC20(stables[token]).transfer(addr, minimumReceive);
        }
        // updating variables and sending STBT rewards
        if (totalSRewards > 0) {
            totalClaimed += totalSRewards;
            rewardInfoArray[rewardInfoArray.length - 1]
                .claimed += totalSRewards;
            // send stbt
            stbt.transfer(addr, totalSRewards);
        }
        claimInfoMap[addr].totalAmountClaimed += totalRewards;
        claimInfoMap[addr].lastClaimPeriod = uint16(rewardInfoArray.length - 1);
        emit Claim(totalRewards, totalSRewards);
        return (totalRewards, totalSRewards);
    }

    /**@notice allows uno to claim the `unaccountedRewards` */
    function unoClaim() public calculateRewards {
        if (msg.sender != uno) {
            revert MatrixUno__OnlyUno();
        }
        stbt.transfer(uno, unaccountedRewards);
        emit UnoClaim(unaccountedRewards);
        rewardInfoArray[rewardInfoArray.length - 1]
            .claimed += unaccountedRewards;
        unaccountedRewards = 0;
    }

    // ERC-4626 functions

    /**@notice ERC-4626 but with some custom logic for calls from `uno`
     *@dev See {IERC4626-deposit}. */
    function deposit(
        uint256 assets,
        address receiver
    ) public virtual override calculateRewards returns (uint256) {
        //uint256 shares = previewDeposit(assets);
        _deposit(_msgSender(), receiver, assets, 0);
        claim(msg.sender, 1, 97);
        /**@notice custom MatrixUno logic to track STBT deposited by Uno Re */
        if (receiver == address(this) && msg.sender == uno) {
            unoDepositAmount += assets;
        }
        rewardInfoArray[rewardInfoArray.length - 1].deposited += assets;
        rewardInfoArray[rewardInfoArray.length - 1].vaultAssetBalance += assets;
        claimInfoMap[msg.sender].balances[3] += assets;
        return assets;
    }

    /**@notice ERC-4626 but with some custom logic for calls from `uno`
     *@dev See {IERC4626-deposit}. */
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public virtual override calculateRewards returns (uint256) {
        require(
            assets <= maxWithdraw(owner),
            "ERC4626: withdraw more than max"
        );
        _withdraw(_msgSender(), receiver, owner, assets, 0);
        claim(msg.sender, 1, 97);
        /**@notice custom MatrixUno logic to track STBT withdrawn by Uno Re */
        if (msg.sender == uno) {
            unoDepositAmount -= assets;
        }
        rewardInfoArray[rewardInfoArray.length - 1].withdrawn += assets;
        rewardInfoArray[rewardInfoArray.length - 1].vaultAssetBalance -= assets;
        claimInfoMap[msg.sender].balances[3] -= assets;
        return assets;
    }

    // ERC-20 functions

    /**@notice  */
    function transfer(
        address to,
        uint256 value
    ) public virtual override updatesBalance([0, 1, 2, 3]) returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, value);
        return true;
    }

    /** Admin only functions (Uno's whitelisted EOA) */

    /**@notice this function allows uno to set the SSIP address */
    function setSSIP(address ssipAddress) public {
        ssip = ISingleSidedInsurancePool(ssipAddress);
    }

    /**@notice this function will call `performUpkeep()` when upkeepNeeded is true
     *@dev returns true when one week has passed since the last `performUpkeep()` call
     */
    function checkUpkeep() external view returns (bool upkeepNeeded) {
        console.log("lastUpkeepTime:", lastUpkeepTime);
        console.log("difference:", block.timestamp - lastUpkeepTime);
        upkeepNeeded = (block.timestamp - lastUpkeepTime) >= i_interval;
    }

    /**@notice this function is called by core functions after `interval` passes to update values for reward calculation
     *@dev is only called once `checkUpkeep()` returns true */
    function performUpkeep() external {
        console.log("performUpkeep reached");
        uint length = rewardInfoArray.length;
        console.log("length:", length);
        // It's highly recommended to revalidate the upkeep in the performUpkeep function
        if ((block.timestamp - lastUpkeepTime) < i_interval) {
            revert MatrixUno__UpkeepNotReady();
        }
        emit upkeep(
            (block.timestamp - lastUpkeepTime) < i_interval,
            lastUpkeepTime
        );
        lastUpkeepTime = block.timestamp;

        // Most important task performUpkeep does is to set the rewardInfo for the week
        // This is crucial because the rewardInfo is used in user's reward calculation

        //uint currentPeriod = rewardInfoArray.length - 1;
        // set `currentBalance` for the current week
        uint currentStbt = stbt.balanceOf(address(this));
        rewardInfoArray[length - 1].currentBalance = currentStbt;
        console.log("checkpoint 0");
        rewardInfo memory currentInfo = rewardInfoArray[length - 1];
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
            rewardInfoArray[length - 1].rewards = 0;
        } else {
            rewardInfoArray[length - 1].rewards =
                (currentInfo.currentBalance +
                    currentInfo.claimed +
                    currentInfo.withdrawn) -
                (currentInfo.previousWeekBalance + currentInfo.deposited);
            unaccountedRewards += calculateUnaccountedRewards();
        }
        rewardInfoArray[length - 1].endTime = block.timestamp;

        console.log("checkpoint 2");
        // push a new struct to the array with only the `previousWeekBalance`
        rewardInfoArray.push(
            rewardInfo(
                0,
                currentInfo.vaultAssetBalance,
                currentStbt,
                0,
                0,
                0,
                0,
                block.timestamp,
                0
            )
        );
        console.log("checkpoint 3");
        // increment the `unaccountedRewards` variable
        console.log("currentBalance:", currentInfo.currentBalance);
        console.log("uno deposit:", unoDepositAmount);
        console.log("rewards:", rewardInfoArray[length - 1].rewards);
        // unaccountedRewards += (rewardInfoArray[length - 1].rewards /
        //     (currentInfo.currentBalance / unoDepositAmount));
        console.log("checkpoint 4");
        emit UpkeepPerformed(rewardInfoArray[length - 1]);
    }

    /** Internal and Private functions */

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

    /**@notice native ERC-4626 function */
    function _deposit(
        address caller,
        address receiver,
        uint256 assets,
        uint256
    ) internal override {
        stbt.transferFrom(caller, address(this), assets);
        _mint(receiver, assets);
        // inherited event, currently emitting with assets for assets and shares since 1:1 peg.
        emit Deposit(caller, receiver, assets, assets);
    }

    /**@notice native ERC-4626 function */
    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256
    ) internal override {
        if (caller != owner) {
            _spendAllowance(owner, caller, assets);
        }
        _burn(owner, assets);
        stbt.transfer(receiver, assets);
        emit Withdraw(caller, receiver, owner, assets, assets);
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

    /**@notice returns the total amount of stablecoins in the vault
     *@dev this views balance using ERC-20 balanceOf so it shows even coins sent directly to this contract (lost coins)*/
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

    /**@notice this function returns the amount of times that the users totalStaked goes into the vaultAssetBalance at given week
     *@dev essentially views what portion of the STBT is being represented by the user
     *@dev for example: user who staked $50,000 DAI would have portion of 4. (1/4 of unoDepositAmount)
     *@dev portion is the stablecoins staked portion, sPortion is the STBT portion
     *@param week is the rewardInfoArray index that you'd like to view portion from
     *@param addr is the user's portion you are viewing */
    function viewPortionAt(
        uint week,
        address addr
    ) public view returns (int128 portion, int128 sPortion) {
        if (week >= rewardInfoArray.length) {
            revert MatrixUno__InvalidWeek(week);
        }
        // uint daiStaked = claimInfoMap[addr].balances[0];
        // uint usdcStaked = claimInfoMap[addr].balances[1] * 1e12;
        // uint usdtStaked = claimInfoMap[addr].balances[2] * 1e12;
        uint stbtDeposited = claimInfoMap[addr].balances[3];
        uint xunoBalance = claimInfoMap[addr].balances[4];
        //uint totalUserStaked = daiStaked + usdcStaked + usdtStaked;
        // console.log("dai staked:", daiStaked);
        // console.log("usdc staked:", usdcStaked);
        // console.log("usdt staked:", usdtStaked);
        console.log("stbt deposit:", stbtDeposited);
        console.log("xUno balance:", xunoBalance);
        //console.log("total staked:", totalUserStaked);
        console.log(
            "vaultAssetBalance",
            rewardInfoArray[week].vaultAssetBalance
        );
        // If msg.sender is uno, we don't want to count the initial deposit towards earned rewards
        if (msg.sender == uno) {
            stbtDeposited -= unoDepositAmount;
        }
        if (xunoBalance > 0 && unoDepositAmount > 0) {
            portion = xunoBalance.divu(rewardInfoArray[week].vaultAssetBalance);
        } else {
            portion = 0;
        }
        if (stbtDeposited > 0) {
            sPortion = stbtDeposited.divu(
                rewardInfoArray[week].vaultAssetBalance
            );
        } else {
            sPortion = 0;
        }
        //console.log("portion:", portion);
    }

    /**@notice returns the length of the rewardInfoArray - 1 */
    function viewCurrentPeriod() public view returns (uint) {
        return rewardInfoArray.length - 1;
    }

    /**@notice allows users to view the amount of rewards they currently can claim */
    function viewRewards(address addr) public view returns (uint, uint) {
        uint lastClaimPeriod = claimInfoMap[addr].lastClaimPeriod;
        uint currentPeriod = rewardInfoArray.length - 1;
        uint totalRewards = 0;
        uint totalSRewards = 0;
        for (uint i = lastClaimPeriod; i < currentPeriod; i++) {
            (int128 stakedPortion, int128 sPortion) = viewPortionAt(i, addr);
            if (stakedPortion > 0) {
                uint userRewards = stakedPortion.mulu(
                    rewardInfoArray[i].rewards
                );
                console.log("userRewards:", userRewards);
                totalRewards += userRewards;
            }
            if (sPortion > 0) {
                uint userSRewards = sPortion.mulu(rewardInfoArray[i].rewards);
                console.log("userSRewards:", userSRewards);
                totalSRewards += userSRewards;
            }
        }
        console.log("for loop passed");
        console.log("totalRewards:", totalRewards);
        console.log("totalSRewards:", totalSRewards);
        return (totalRewards, totalSRewards);
    }

    /**@notice returns the rewardInfo struct for a given week
     *@param week corresponds to the rewardInfoArray index */
    function viewRewardInfo(uint week) public view returns (rewardInfo memory) {
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
        return claimInfoMap[user].lastClaimPeriod;
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
        console.log("calculateUnnacountedRewards reached!");
        uint length = rewardInfoArray.length;
        console.log("length:", length);
        console.log("totalStaked:", totalStaked);
        if (unoDepositAmount <= totalStaked) {
            return 0;
        } else {
            uint remainder = unoDepositAmount - totalStaked;
            console.log("remainder:", remainder);
            int128 portion = remainder.divu(
                rewardInfoArray[length - 1].currentBalance
            );
            return portion.mulu(rewardInfoArray[length - 1].rewards);
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

    /**@notice returns the current STBT / stablecoin conversion from Curve's get_virtual_price for `stake()` */
    function viewStakeConversionRate()
        public
        view
        returns (int128 conversionRate)
    {
        conversionRate = uint(1e18).divu(pool.get_virtual_price());
        console.log("stake rate:", uint128(conversionRate));
    }

    /**@notice returns the current STBT / stablecoin conversion from Curve's get_virtual_price for `unstake()` */
    function viewUnstakeConversionRate()
        public
        view
        returns (int128 conversionRate)
    {
        conversionRate = pool.get_virtual_price().divu(uint256(1e18));
        console.log("unstake rate:", uint128(conversionRate));
    }
}
