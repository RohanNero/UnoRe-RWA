//SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../Curve/interfaces/IStableSwap.sol";
import "hardhat/console.sol";

error MatrixUno__ZeroAmountGiven();
/**@param tokenId - corresponds to the `stables` indices */
error MatrixUno__InvalidTokenId(uint tokenId);
/**@param vaultBalance - the amount of shares the vault currently has
   @param transferAmount - the amount of shares that would be transferred to the user */
error MatrixUno__NotEnoughShares(uint vaultBalance, uint transferAmount);

/**@title MatrixUno
 *@author Rohan Nero
 *@notice this contract allows UNO users to earn native STBT yields from Matrixdock.
 *@dev This vault uses STBT as the asset and xUNO as the shares token*/
contract MatrixUnoV2 is ERC4626 {
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

    /**@notice this struct includes a list of variables that get updated inside the rewardInfoArray every week */
    struct weeklyRewardInfo {
        uint rewards;
        uint vaultAssetBalance; // total amount of assets deposited into the vault
        uint previousWeekBalance;
        uint rewardsClaimed;
        uint currentBalance; // total amount of assets in the vault, deposited or sent from MatrixPort
    }

    /**@notice this struct includes a variable that represents stablecoin balances as well as the last claim week*/
    struct claimInfo {
        uint[3] balances;
        uint16 lastClaimedWeek;
        uint totalAmountClaimed;
    }

    /**@notice each index corresponds to a week  */
    weeklyRewardInfo[] private rewardInfoArray;

    /**@notice Array of the stablecoin addresses */
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
        rewardInfoArray[0] = weeklyRewardInfo(0, 2e23, 2e23, );
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
        uint stableBalance = claimInfoMap[msg.sender].balances[token];
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
        // transfer earned STBT to STBT/3CRV pool and exchange for stablecoin
        uint minimumReceive = earned * (99e16);
        // 99% of the earned amount (.01)
        if (token > 0) {
            minimumReceive /= 1e30;
        } else {
            minimumReceive /= 1e18;
        }
        console.log("earned:", earned);
        console.log("minimumReceive:", minimumReceive);
        stbt.approve(address(pool), earned);
        pool.exchange_underlying(
            int128(0),
            int128(uint128(token + 1)),
            earned,
            minimumReceive
        );
        // finally transfer stablecoins to user
        IERC20(stables[token]).transfer(
            msg.sender,
            stableBalance + minimumReceive
        );
        return stableBalance + minimumReceive;
    }

    /**@notice allows users to claim their staking rewards without unstaking
     *@dev calculates the amount of rewards a user is owed and sends it to them
     *@dev this function is called by unstake */
    function claim() public returns (uint earned) {
        earned = _claim(msg.sender);
    }

    /** Internal and Private functions */

    /**@notice contains the reward calculation logic
     *@dev this function is called by `claim` and `unstake`  */
    function _claim(address addr) private view returns (uint) {
        uint lastClaimWeek = claimInfoMap[addr].lastClaimedWeek;
        uint currentWeek = (block.timestamp - startingTimestamp) /
            SECONDS_IN_WEEK;
        uint totalRewards = 0;
        for (uint i = lastClaimWeek; i < currentWeek; i++) {
            uint stakedPortion = viewPortion(addr);
            uint userRewards = rewardInfoArray[i].rewards / stakedPortion;
            totalRewards += userRewards;
        }
        return totalRewards;
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

    /**@notice this function returns the amount of times that the users totalStaked goes into the initialAmount
     *@dev essentially views what portion of the STBT is being represented by the user
     *@dev for example: user who staked $50,000 DAI would have portion of 4. (1/4 of initialAmount) */
    function viewPortion(address addr) public view returns (uint portion) {
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
}
