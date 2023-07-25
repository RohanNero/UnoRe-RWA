//SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

/**@notice this contract is a vault contract with some custom additions */
import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
/**@notice used to interact with multiple ERC20 token contracts */
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
/**@notice used to interact with USDT since function signature differs from OZ ERC-20 */
import "../interfaces/IUSDT.sol";
/**@notice used when swapping STBT into stablecoins for user rewards */
import "../Curve/interfaces/IStableSwap.sol";
/**@notice uses to screen addresses prior to staking */
import "../interfaces/ISanctionsList.sol";
// /**@notice uses to interact with SSIP */
// import "../interfaces/ISingleSidedInsurancePool.sol";
/**@notice used in testing to ensure values are set correctly */
import "hardhat/console.sol";
/**@notice used in reward calculation math */
import "abdk-libraries-solidity/ABDKMath64x64.sol";

/**notice used to revert function calls that pass zero as the `amount` */
error MatrixUno__ZeroAmountGiven();
/**@param tokenId - corresponds to the `stables` indices */
error MatrixUno__InvalidTokenId(uint256 tokenId);
/**@notice used when `performUpkeep()` is called before a period has passed */
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
error MatrixUno__InvalidPeriod(uint256 period);
/**@notice used when users try to transfer tokens */
error MatrixUno__InsufficientBalance(uint256 value, uint256 totalBalance);
/**@notice used to ensure the spendingTokens variable has no duplicate values */
error MatrixUno__NoDuplicates();
/**@notice used to ensure perform upkeep doesn't work if unoDepositAmount is zero */
error MatrixUno__UpkeepNotAllowed();

/**@title MatrixUno
 *@author Rohan Nero
 *@notice this contract allows UNO users to earn native STBT yields from Matrixdock.
 *@dev This vault uses STBT as the asset and xUNO as the shares token*/
contract MatrixUno is ERC4626 {
    /**@notice declare that we are using ABDK Math library for these variabels */
    using ABDKMath64x64 for uint256;
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
    IUSDT private usdt;

    /**@notice used to screen users prior to being allowed to stake */
    ISanctionsList private sanctionsList;

    // /**@notice used to interact with the SSIP */
    // ISingleSidedInsurancePool private ssip;

    /**@notice this struct includes a list of variables that get updated inside the rewardInfoArray every period
     *@dev each struct corresponds to a different period since the contract's inception */
    struct rewardInfo {
        uint256 rewards; // amount of STBT rewards earned by the vault during the period
        uint256 vaultAssetBalance; // total amount of assets DEPOSITED into the vault
        uint256 previousPeriodBalance; // total STBT in the vault the previous period (last `performUpkeep()` call)
        uint256 currentBalance; // TOTAL AMOUNT of assets in the vault, deposited or sent from MatrixPort as rewards (balanceOf)
        uint256 unoDeposit; // amount of stbt uno has deposited during the period
        uint256 claimed; // amount of STBT rewards that were claimed during the period
        uint256 deposited; // amount of STBT deposited into the vault during the period
        uint256 withdrawn; // amount of STBT withdrawn from the vault during the period
        uint256 startTime; // starting timestamp of this reward period
        uint256 endTime; // ending timestamp of this reward period
    }

    /**@notice this struct includes a variable that represents stablecoin balances as well as the last claim period
     *@dev balances corresponds to the stable array indices (DAI = 0, USDC = 1, USDT = 2, STBT = 3, and xUNO = 4) */
    struct claimInfo {
        uint256[5] balances;
        uint16 lastClaimPeriod;
        uint256 totalAmountClaimed;
        uint8[4] spendingOrder;
    }

    /**@notice each index corresponds to a period
     *@dev index 0 is the contract's first period of being deployed
     *@dev starting at i_startingTimestamp, ending at i_startingTimestamp +i_interval */
    rewardInfo[] private rewardInfoArray;

    /**@notice Array of the stablecoin addresses
     *@dev 0 = DAI, 1 = USDC, 2= USDT*/
    address[3] private stables;

    /**@notice User stablecoin balances and period index of their last claim */
    mapping(address => claimInfo) private claimInfoMap;

    /**@notice tracks the total amount of stablecoins staked
     *@dev USDC/UDST were converted into 18 decimals */
    uint256 private totalStaked;

    /**@notice tracks total amount of stbt deposited */
    uint256 private totalDeposited;

    /**@notice tracks the total amount of STBT claimed by users */
    uint256 private totalClaimed;

    /**@notice the amount of STBT deposited by Uno Re */
    uint256 private unoDepositAmount;

    /**@notice Uno Re's address used for depositing STBT */
    address private immutable uno;

    /**@notice the starting timestamp set once inside constructor */
    uint256 private immutable i_startingTimestamp;

    /**@notice immutable variable representing the number of seconds in ani_interval
     *@dev originally was constant variable set to one period (604800) */
    uint256 private immutable i_interval;

    /**@notice last timestamp that performUpkeep() was called */
    uint256 private lastUpkeepTime;

    /**@notice the total amount of rewards earned by Uno Re as opposed to users
     *@dev Uno Re can claim this amount at any time*/
    uint256 private unaccountedRewards;

    /**@notice this variable tracks the total number of STBT that is accounted for
     * i.e if a user stakes 50 DAI and gets 49 STBT, this variable will increment by 49
     */
    uint256 private accountedForStbt;

    /**@notice emits when uno calls `UnoClaim()`
     *@param amountClaimed is the amount of STBT sent to `uno` */
    event UnoClaim(uint256 amountClaimed);

    /**@notice emitted when perform upkeep is called */
    event UpkeepPerformed(rewardInfo info);

    /**@notice emitted when `claim` is called */
    event Claim(uint256 totalRewards, uint256 totalSRewards);

    /**@notice emitted when user stakes */
    event Stake(uint256 amount, address staker);

    /**@notice emitted when user unstakes */
    event Unstake(uint256 amount, address unstaker);

    /**@notice used for testing, remove after done testing. */
    // event transferInfo(uint256 _amount, uint256 _receive);
    // event actual(uint256 actualRec);
    // event upkeep(bool needed, uint256 lastUpkeep);
    event transferData(int128 p, uint256 r, uint256 t, bool b);
    event withdrawData(bool p, bool r, uint256 t, uint256 b);

    /**@notice used to check if the rewards are due to be updated */
    modifier calculateRewards() {
        _calculateRewards();
        _;
    }

    /**@notice used to update balances during ERC-20 transfers */
    modifier updatesBalance(
        address from,
        address to,
        uint256 value
    ) {
        _updatesBalance(from, to, value);
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
        uint256 interval
    ) ERC4626(IERC20(asset)) ERC20("Matrix UNO", "xUNO") {
        stbt = IERC20(asset);
        pool = IStableSwap(poolAddress);
        uno = unoAddress;
        sanctionsList = ISanctionsList(sanctionsAddress);
        stables = stablecoins;
        dai = IERC20(stables[0]);
        usdc = IERC20(stables[1]);
        usdt = IUSDT(stables[2]);
        i_startingTimestamp = block.timestamp;
        lastUpkeepTime = block.timestamp;
        i_interval = interval;
        //rewardInfoArray[0].previousPeriodBalance = 2e23;
        // 200,000 STBT with 18 decimals
        rewardInfoArray.push(
            rewardInfo(0, 0, 0, 0, 0, 0, 0, 0, block.timestamp, 0)
        );
    }

    /**@notice this function allows users to stake stablecoins for xUNO
     *@dev this contract holds the stablecoins and transfers xUNO from its balance
     *@param amount - the amount of stablecoin to deposit
     *@param token - the stablecoin to deposit (DAI = 0, USDC = 1, USDT = 2)
     */
    function stake(
        uint256 amount,
        uint8 token,
        uint256 minimumPercentage
    ) external calculateRewards returns (uint256 shares) {
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
        uint256 transferAmount;
        if (token > 0) {
            transferAmount = amount * 1e12;
        } else {
            transferAmount = amount;
        }
        /** If there's less xUNO than the user is supposed to receive, the amount staked is equal to the amount of xUNO left */
        uint256 transferFromAmount;
        /** amount of stablecoin deposited, with 18 decimals */
        uint256 amountStaked;
        // Using Curve's virtual price
        int128 conversionRate = viewStakeConversionRate();
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
                amountStaked = amount * 1e12;
                transferAmount = conversionRate.mulu(amount * 1e12);
            } else {
                amountStaked = amount;
                transferAmount = conversionRate.mulu(amount);
            }
        }
        if (token == 2) {
            IUSDT(stables[token]).transferFrom(
                msg.sender,
                address(this),
                transferFromAmount
            );
        } else {
            IERC20(stables[token]).transferFrom(
                msg.sender,
                address(this),
                transferFromAmount
            );
        }
        claim(msg.sender, token, minimumPercentage);
        claimInfoMap[msg.sender].balances[token] += amountStaked;
        claimInfoMap[msg.sender].balances[4] += transferAmount;
        if (token > 0) {
            totalStaked += transferFromAmount * 1e12;
        } else {
            totalStaked += transferFromAmount;
        }
        accountedForStbt += transferAmount;
        _transfer(address(this), msg.sender, transferAmount);
        emit Stake(transferFromAmount, msg.sender);
        shares = transferAmount;
    }

    /**@notice this function allows users to unstake their stablecoins plus accrued rewards
     *@dev requires approving this contract to take the xUNO first
     *@param amount - the amount of xUNO you want to return to the vault
     *@param token - the stablecoin you want your interest to be in
     *@dev (currently must match the deposited stable)*/
    function unstake(
        uint256 amount,
        uint8 token,
        uint256 minimumPercentage
    ) external calculateRewards returns (uint256) {
        if (amount == 0) {
            revert MatrixUno__ZeroAmountGiven();
        }
        if (amount > claimInfoMap[msg.sender].balances[4]) {
            revert MatrixUno__InsufficientBalance(
                amount,
                claimInfoMap[msg.sender].balances[4]
            );
        }
        if (token > 2) {
            revert MatrixUno__InvalidTokenId(token);
        }

        _spendAllowance(msg.sender, address(this), amount);
        _transfer(msg.sender, address(this), amount);
        if (unoDepositAmount == 0) {
            _burn(address(this), amount);
        }
        claim(msg.sender, token, minimumPercentage);
        uint256 adjustedAmount = amount;
        uint256 initialVaultBalance = claimInfoMap[msg.sender].balances[token];
        int128 portion = amount.divu(claimInfoMap[msg.sender].balances[4]);
        adjustedAmount = portion.mulu(viewTotalStableBalance(msg.sender));
        // // temporary fix to the adjustedAmount being slightly larger than user balance
        // if (adjustedAmount > initialVaultBalance) {
        //     adjustedAmount = initialVaultBalance;
        // }
        claimInfoMap[msg.sender].balances[token] -= adjustedAmount;
        claimInfoMap[msg.sender].balances[4] -= amount;
        accountedForStbt -= amount;
        totalStaked -= adjustedAmount;
        if (token > 0) {
            adjustedAmount /= 1e12;
        }
        if (token == 2) {
            IUSDT(stables[token]).transfer(msg.sender, adjustedAmount);
        } else {
            IERC20(stables[token]).transfer(msg.sender, adjustedAmount);
        }
        emit Unstake(initialVaultBalance, msg.sender);
        return amount;
    }

    /**@notice allows users to claim their staking rewards without unstaking
     *@dev calculates the amount of rewards a user is owed and sends it to them
     *@dev this function is called by unstake */
    function claim(
        address addr,
        uint8 token,
        uint256 minimumPercentage
    ) public calculateRewards returns (uint256, uint256) {
        if (msg.sender != addr && msg.sender != address(this)) {
            revert MatrixUno__AddrMustBeSender(msg.sender, addr);
        }
        uint256 lastClaimPeriod = claimInfoMap[addr].lastClaimPeriod;
        uint256 currentPeriod = rewardInfoArray.length - 1;
        uint256 totalRewards = 0;
        uint256 totalSRewards = 0;
        for (uint256 i = lastClaimPeriod; i < currentPeriod; i++) {
            (int128 stakedPortion, int128 sPortion) = viewPortionAt(i, addr);
            if (stakedPortion > 0) {
                uint256 userRewards = stakedPortion.mulu(
                    rewardInfoArray[i].rewards
                );
                totalRewards += userRewards;
            }
            if (sPortion > 0) {
                uint256 userSRewards = sPortion.mulu(
                    rewardInfoArray[i].rewards
                );
                totalSRewards += userSRewards;
            }
        }
        if (totalRewards > 0) {
            totalClaimed += totalRewards;
            rewardInfoArray[rewardInfoArray.length - 1].claimed += totalRewards;
            uint256 minimumReceive = _swap(
                totalRewards,
                token,
                minimumPercentage
            );
            claimInfoMap[addr].totalAmountClaimed += totalRewards;
            claimInfoMap[addr].lastClaimPeriod = uint16(
                rewardInfoArray.length - 1
            );
            if (token == 2) {
                IUSDT(stables[token]).transfer(addr, minimumReceive);
            } else {
                IERC20(stables[token]).transfer(addr, minimumReceive);
            }
        }
        if (totalSRewards > 0) {
            totalClaimed += totalSRewards;
            rewardInfoArray[rewardInfoArray.length - 1]
                .claimed += totalSRewards;
            stbt.transfer(addr, totalSRewards);
        }
        emit Claim(totalRewards, totalSRewards);
        return (totalRewards, totalSRewards);
    }

    /**@notice allows uno to claim the `unaccountedRewards` */
    function unoClaim() external calculateRewards {
        if (msg.sender != uno) {
            revert MatrixUno__OnlyUno();
        }
        uint amount = unaccountedRewards;
        unaccountedRewards = 0;
        rewardInfoArray[rewardInfoArray.length - 1].claimed += amount;

        stbt.transfer(uno, amount);
        emit UnoClaim(amount);
    }

    /**@notice allows users to specify their preferred spending tokens
     *@dev the tokens will be prioritized for spending starting at lowest `tokens` index
     *@dev this means that if tokens[0] == 0, (corresponds to DAI), the users DAI will be spent first if the user transfers xUNO */
    function setSpendingTokens(uint8[4] memory tokens) external {
        if (hasDuplicates(tokens)) {
            revert MatrixUno__NoDuplicates();
        }
        if (tokens[0] > 3 || tokens[1] > 3 || tokens[2] > 3 || tokens[3] > 3) {
            revert MatrixUno__InvalidTokenId(0);
        }
        claimInfoMap[msg.sender].spendingOrder = tokens;
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
        uint256 length = rewardInfoArray.length - 1;
        if (receiver == address(this) && msg.sender == uno) {
            unoDepositAmount += assets;
            rewardInfoArray[length].unoDeposit += assets;
        }
        rewardInfoArray[length].deposited += assets;
        rewardInfoArray[length].vaultAssetBalance += assets;
        claimInfoMap[msg.sender].balances[3] += assets;
        totalDeposited += assets;
        return assets;
    }

    /**@notice ERC-4626 but with some custom logic for calls from `uno`
     *@dev See {IERC4626-deposit}. */
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public virtual override calculateRewards returns (uint256) {
        if (assets > claimInfoMap[msg.sender].balances[3]) {
            revert MatrixUno__InsufficientBalance(
                assets,
                claimInfoMap[msg.sender].balances[3]
            );
        }
        if (msg.sender == uno) {
            this.performUpkeep();
        }
        claim(msg.sender, 1, 97);
        _withdraw(_msgSender(), receiver, owner, assets, 0);

        /**@notice custom MatrixUno logic to track STBT withdrawn by Uno Re */

        rewardInfoArray[rewardInfoArray.length - 1].withdrawn += assets;
        rewardInfoArray[rewardInfoArray.length - 1].vaultAssetBalance -= assets;
        claimInfoMap[msg.sender].balances[3] -= assets;
        totalDeposited -= assets;
        return assets;
    }

    // ERC-20 functions

    /**@notice overridden ERC-20 transfer function to include `updatesBalance` modifier */
    function transfer(
        address to,
        uint256 value
    )
        public
        virtual
        override
        updatesBalance(msg.sender, to, value)
        returns (bool)
    {
        address owner = _msgSender();
        _transfer(owner, to, value);
        return true;
    }

    /**@notice overridden ERC-20 transferFrom function to include `updatesBalance` modifier */
    function transferFrom(
        address from,
        address to,
        uint256 value
    ) public override updatesBalance(from, to, value) returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }

    /**@notice this function will call `performUpkeep()` when upkeepNeeded is true
     *@dev returns true when one period has passed since the last `performUpkeep()` call
     */
    function checkUpkeep() external view returns (bool upkeepNeeded) {
        if ((block.timestamp - lastUpkeepTime) >= i_interval) {
            upkeepNeeded = false;
        } else if (totalDeposited <= 0) {
            upkeepNeeded = false;
        } else {
            rewardInfo memory currentInfo = rewardInfoArray[
                rewardInfoArray.length - 1
            ];
            upkeepNeeded =
                (currentInfo.currentBalance +
                    currentInfo.claimed +
                    currentInfo.withdrawn) <=
                (currentInfo.previousPeriodBalance + currentInfo.deposited);
        }
    }

    /**@notice this function is called by core functions after `interval` passes to update values for reward calculation
     *@dev is only called once `checkUpkeep()` returns true */
    function performUpkeep() external {
        uint256 length = rewardInfoArray.length;
        console.log(_msgSender() != uno);
        console.log(_msgSender());
        if (
            (block.timestamp - lastUpkeepTime) < i_interval &&
            _msgSender() != uno &&
            _msgSender() != address(this)
        ) {
            revert MatrixUno__UpkeepNotReady();
        }
        if (
            totalDeposited == 0 &&
            _msgSender() != uno &&
            _msgSender() != address(this)
        ) {
            revert MatrixUno__UpkeepNotAllowed();
        }
        lastUpkeepTime = block.timestamp;
        uint256 currentStbt = stbt.balanceOf(address(this));
        rewardInfoArray[length - 1].currentBalance = currentStbt;
        rewardInfo memory currentInfo = rewardInfoArray[length - 1];
        if (
            (currentInfo.currentBalance +
                currentInfo.claimed +
                currentInfo.withdrawn) <=
            (currentInfo.previousPeriodBalance + currentInfo.deposited)
        ) {
            rewardInfoArray[length - 1].rewards = 0;
        } else {
            rewardInfoArray[length - 1].rewards =
                (currentInfo.currentBalance +
                    currentInfo.claimed +
                    currentInfo.withdrawn) -
                (currentInfo.previousPeriodBalance + currentInfo.deposited);
            unaccountedRewards += calculateUnaccountedRewards();
        }
        rewardInfoArray[length - 1].endTime = block.timestamp;
        rewardInfoArray.push(
            rewardInfo(
                0,
                currentInfo.vaultAssetBalance,
                currentStbt,
                0,
                unoDepositAmount,
                0,
                0,
                0,
                block.timestamp,
                0
            )
        );
        emit UpkeepPerformed(rewardInfoArray[length - 1]);
    }

    /** View / Pure functions */

    /**@notice returns the curve pool address */
    function viewPoolAddress() external view returns (address) {
        return address(pool);
    }

    /**@notice returns the address that Uno Re will use to deposit/withdraw STBT */
    function viewUnoAddress() external view returns (address) {
        return uno;
    }

    /**@notice returns addresses of DAI/UDSC/USDT used by this contract */
    function viewStables() external view returns (address[3] memory) {
        return stables;
    }

    /**@notice returns the sanctionsList contract address */
    function viewSanctionsList() external view returns (address) {
        return address(sanctionsList);
    }

    /**@notice returns the total amount of stablecoins in the vault
     *@dev this views balance using ERC-20 balanceOf so it shows even coins sent directly to this contract (lost coins)*/
    function viewVaultStableBalance()
        external
        view
        returns (uint256 totalStableBal)
    {
        uint256 daiBalance = dai.balanceOf(address(this));
        uint256 usdcBalance = usdc.balanceOf(address(this));
        uint256 usdtBalance = usdt.balanceOf(address(this));
        // Add 12 zeros to USDC and USDT because they only have 6 decimals
        totalStableBal =
            daiBalance +
            (usdcBalance * 1e12) +
            (usdtBalance * 1e12);
    }

    /**@notice this function returns the total amount of STBT that can be redeemed for stablecoins
     *@param period is the rewardInfoArray index that you'd like to view portion from */
    function viewRedeemableAt(
        uint256 period
    ) external view returns (uint256 redeemable) {
        redeemable = totalAssets() - rewardInfoArray[period].vaultAssetBalance;
    }

    /**@notice this function returns the amount of times that the users totalStaked goes into the vaultAssetBalance at given period
     *@dev essentially views what portion of the STBT is being represented by the user
     *@dev for example: user who staked $50,000 DAI would have portion of 4. (1/4 of unoDepositAmount)
     *@dev portion is the stablecoins staked portion, sPortion is the STBT portion
     *@param period is the rewardInfoArray index that you'd like to view portion from
     *@param addr is the user's portion you are viewing */
    function viewPortionAt(
        uint256 period,
        address addr
    ) public view returns (int128 portion, int128 sPortion) {
        if (period >= rewardInfoArray.length) {
            revert MatrixUno__InvalidPeriod(period);
        }
        uint256 stbtDeposited = claimInfoMap[addr].balances[3];
        uint256 xunoBalance = claimInfoMap[addr].balances[4];
        // If msg.sender is uno, we don't want to count the initial deposit towards earned rewards
        if (msg.sender == uno) {
            stbtDeposited -= unoDepositAmount;
        }
        if (xunoBalance > 0 && rewardInfoArray[period].unoDeposit > 0) {
            portion = xunoBalance.divu(
                rewardInfoArray[period].vaultAssetBalance
            );
        } else {
            portion = 0;
        }
        if (stbtDeposited > 0) {
            sPortion = stbtDeposited.divu(
                rewardInfoArray[period].vaultAssetBalance
            );
        } else {
            sPortion = 0;
        }
    }

    /**@notice returns the length of the rewardInfoArray - 1 */
    function viewCurrentPeriod() external view returns (uint256) {
        return rewardInfoArray.length - 1;
    }

    /**@notice allows users to view the amount of rewards they currently can claim */
    function viewRewards(
        address addr
    ) external view returns (uint256, uint256) {
        uint256 lastClaimPeriod = claimInfoMap[addr].lastClaimPeriod;
        uint256 currentPeriod = rewardInfoArray.length - 1;
        uint256 totalRewards = 0;
        uint256 totalSRewards = 0;
        for (uint256 i = lastClaimPeriod; i < currentPeriod; i++) {
            (int128 stakedPortion, int128 sPortion) = viewPortionAt(i, addr);
            if (stakedPortion > 0) {
                uint256 userRewards = stakedPortion.mulu(
                    rewardInfoArray[i].rewards
                );
                totalRewards += userRewards;
            }
            if (sPortion > 0) {
                uint256 userSRewards = sPortion.mulu(
                    rewardInfoArray[i].rewards
                );
                totalSRewards += userSRewards;
            }
        }
        return (totalRewards, totalSRewards);
    }

    /**@notice returns the rewardInfo struct for a given period
     *@param period corresponds to the rewardInfoArray index */
    function viewRewardInfo(
        uint256 period
    ) external view returns (rewardInfo memory) {
        return rewardInfoArray[period];
    }

    /**@notice this function lets you view the balances of users
     *@dev DAI = 0, USDC = 1, USDT = 2, STBT = 3, xUNO = 4
     *@param user the owner of the balance you are viewing
     *@param token is the tokenId of the token you want to view  */
    function viewBalance(
        address user,
        uint8 token
    ) public view returns (uint256 balance) {
        if (token > 4) {
            revert MatrixUno__InvalidTokenId(token);
        }
        balance = claimInfoMap[user].balances[token];
    }

    /**@notice this function returns the total amount of stablecoins a user has deposited
     *@param user the owner of the balance you are viewing */
    function viewTotalStableBalance(
        address user
    ) public view returns (uint256 totalUserStaked) {
        uint256 daiBalance = viewBalance(user, 0);
        uint256 usdcBalance = viewBalance(user, 1);
        uint256 usdtBalance = viewBalance(user, 2);
        totalUserStaked = daiBalance + usdcBalance + usdtBalance;
    }

    /**@notice this function returns the total amount of stablecoins + STBT a user has deposited */
    function viewTotalBalance(
        address addr
    ) public view returns (uint256 totalBalance) {
        uint256 totalStable = viewTotalStableBalance(addr);
        uint256 totalStbt = viewBalance(addr, 3);
        return totalStable + totalStbt;
    }

    /**@notice returns the last period a user has claimed
     *@param user the address that has claimed */
    function viewLastClaimed(address user) external view returns (uint16) {
        return claimInfoMap[user].lastClaimPeriod;
    }

    /**@notice returns the amount a user has claimed
     *@param user the address that has claimed */
    function viewClaimedAmount(address user) external view returns (uint256) {
        return claimInfoMap[user].totalAmountClaimed;
    }

    /**@notice this function returns the totalClaimed variable */
    function viewTotalClaimed() external view returns (uint256 _totalClaimed) {
        _totalClaimed = totalClaimed;
    }

    /**@notice this function returns the totalStaked variable */
    function viewTotalStaked() external view returns (uint256 _totalStaked) {
        _totalStaked = totalStaked;
    }

    /**@notice returns the amount of STBT that Uno Re has deposited into the vault */
    function viewUnoDeposit() external view returns (uint256) {
        return unoDepositAmount;
    }

    /**@notice returns the vault's starting timestamp */
    function viewStartingtime() external view returns (uint256) {
        return i_startingTimestamp;
    }

    /**@notice returns the last time this contract had upkeep performed */
    function viewLastUpkeepTime() external view returns (uint256) {
        return lastUpkeepTime;
    }

    /**@notice returns the seconds in each rewards period */
    function viewInterval() external view returns (uint256) {
        return i_interval;
    }

    /**@notice returns the portion of rewards that are unaccounted for
     *@dev all unaccounted rewards are claimable by Uno Re's EOA */
    function calculateUnaccountedRewards() public view returns (uint256) {
        uint256 length = rewardInfoArray.length;
        if (unoDepositAmount <= accountedForStbt) {
            return 0;
        } else {
            uint256 remainder = unoDepositAmount - accountedForStbt;
            console.log("remainder:", remainder);
            console.log("cb:", rewardInfoArray[length - 1].currentBalance);
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
    function viewUnaccountedRewards() external view returns (uint256) {
        return unaccountedRewards;
    }

    /**@notice returns the total number of STBT that is accounted for aka belongs to staked users
     *@dev current value of the `accountedForStbt` variable */
    function viewAccountedForStbt() external view returns (uint256) {
        return accountedForStbt;
    }

    /**@notice returns the current STBT / stablecoin conversion from Curve's get_virtual_price for `stake()` */
    function viewStakeConversionRate()
        public
        view
        returns (int128 conversionRate)
    {
        conversionRate = uint256(1e18).divu(pool.get_virtual_price());
    }

    /**@notice returns the current STBT / stablecoin conversion from Curve's get_virtual_price for `unstake()` */
    function viewUnstakeConversionRate()
        external
        view
        returns (int128 conversionRate)
    {
        conversionRate = pool.get_virtual_price().divu(uint256(1e18));
    }

    /**@notice returns if the array contains duplicate numbers */
    function hasDuplicates(uint8[4] memory arr) public pure returns (bool) {
        uint256 length = arr.length;
        for (uint256 i = 0; i < length - 1; i++) {
            for (uint256 j = i + 1; j < length; j++) {
                if (arr[i] == arr[j]) {
                    return true;
                }
            }
        }
        return false;
    }

    /** Internal and Private functions */

    /**@notice handles swapping STBT into stablecoins by using the Curve finance STBT/3CRV pool
     *@param earned is the total STBT rewards earned by the user
     *@param token corresponds to the `stables` array index */
    function _swap(
        uint256 earned,
        uint8 token,
        uint256 minimumPercentage
    ) private returns (uint256) {
        // transfer earned STBT to STBT/3CRV pool and exchange for stablecoin
        uint256 minimumReceive;
        int128 formatPercentage = minimumPercentage.fromUInt();
        if (token > 0) {
            minimumReceive = formatPercentage.mulu(earned) / 1e14;
        } else {
            minimumReceive = formatPercentage.mulu(earned) / 100;
        }
        stbt.approve(address(pool), earned);
        //try
        uint256 actualReceived = pool.exchange_underlying(
            int128(0),
            int128(uint128(token + 1)),
            earned,
            minimumReceive
        );
        return actualReceived;
        //} catch {
        //    revert MatrixUno__StableSwapFailed();
        //}
        // uint256 actualReceived = pool.exchange_underlying(
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
        if (caller != owner && caller != uno) {
            _spendAllowance(owner, caller, assets);
        }
        emit withdrawData(
            caller == uno,
            balanceOf(address(this)) < unoDepositAmount,
            balanceOf(address(this)),
            unoDepositAmount
        );
        if (caller == uno && balanceOf(address(this)) < unoDepositAmount) {
            _burn(owner, balanceOf(address(this)));
        } else {
            _burn(owner, assets);
        }
        if (caller == uno) {
            unoDepositAmount = 0;
        }
        stbt.transfer(receiver, assets);
        emit Withdraw(caller, receiver, owner, assets, assets);
    }

    /**@notice checks upkeep and if true, calls performUpkeep */
    function _calculateRewards() private {
        if (this.checkUpkeep()) {
            this.performUpkeep();
        }
    }

    /**@notice updates user balances for transferring xUNO tokens */
    function _updatesBalance(address from, address to, uint256 value) private {
        if (value > viewTotalBalance(from)) {
            revert MatrixUno__InsufficientBalance(
                value,
                viewTotalBalance(from)
            );
        }
        uint8[4] memory tokens = claimInfoMap[from].spendingOrder;
        // If user has never set `spendingOrder` just start from 0 and go up
        if (tokens[0] + tokens[1] + tokens[2] + tokens[3] == 0) {
            tokens = [0, 1, 2, 3];
        }
        int128 portion = value.divu(claimInfoMap[from].balances[4]);
        uint256 totalBalance;
        if (from == uno) {
            totalBalance = viewTotalBalance(from) - unoDepositAmount;
        }
        uint256 remaining = portion.mulu(totalBalance);
        emit transferData(portion, remaining, totalBalance, from == uno);
        // int128 conversion = viewUnstakeConversionRate();
        // uint256 remaining = conversion.mulu(value);
        //uint256 remaining = value;
        uint256 firstBalance = viewBalance(from, tokens[0]);
        uint256 secondBalance = viewBalance(from, tokens[1]);
        uint256 thirdBalance = viewBalance(from, tokens[2]);
        if (remaining > firstBalance) {
            remaining -= firstBalance;
            claimInfoMap[to].balances[tokens[0]] += firstBalance;
            claimInfoMap[from].balances[tokens[0]] = 0;
        } else {
            claimInfoMap[from].balances[tokens[0]] -= remaining;
            claimInfoMap[to].balances[tokens[0]] += remaining;
            remaining = 0;
        }
        if (remaining > secondBalance) {
            remaining -= secondBalance;
            claimInfoMap[to].balances[tokens[1]] += secondBalance;
            claimInfoMap[from].balances[tokens[1]] = 0;
        } else {
            claimInfoMap[from].balances[tokens[1]] -= remaining;
            claimInfoMap[to].balances[tokens[1]] += remaining;
            remaining = 0;
        }
        if (remaining > thirdBalance) {
            remaining -= thirdBalance;
            claimInfoMap[to].balances[tokens[2]] += thirdBalance;
            claimInfoMap[from].balances[tokens[2]] = 0;
        } else {
            claimInfoMap[from].balances[tokens[2]] -= remaining;
            claimInfoMap[to].balances[tokens[2]] += remaining;
            remaining = 0;
        }
        // Since totalbalance is assumed to be more than value, we don't need to check it on the last token
        if (remaining > 0) {
            claimInfoMap[from].balances[tokens[3]] -= remaining;
            claimInfoMap[to].balances[tokens[3]] += remaining;
            remaining = 0;
        }
        claimInfoMap[from].balances[4] -= value;
        claimInfoMap[to].balances[4] += value;
    }
}
