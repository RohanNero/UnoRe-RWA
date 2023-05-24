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
contract MatrixUno is ERC4626 {


    /**@notice the STBT/3CRV pool used for withdrawals 
      *@dev used to convert STBT rewards into stablecoins for users 
      *@dev Ethereum mainnet address: 0x892d701d94a43bdbcb5ea28891daca2fa22a690b */
    IStableSwap private immutable pool;

    /**@notice STBT token address used as the vault asset 
      *@dev Ethereum mainnet address: 0x530824da86689c9c17cdc2871ff29b058345b44a */
    IERC20 private immutable stbt;

    /**@notice The stablecoins that this contract can hold */
    IERC20 private constant dai = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    IERC20 private constant usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 private constant usdt = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);

    /**@notice Array of the stablecoin addresses */
    address[3] private stables; 

    /**@notice User stablecoin balances 
      *@dev The middle uint correlates to the stables indices 
      *@dev For example: balances[0x77][0] = DAI balance of address 0x77 */
    mapping(address => mapping(uint8 => uint)) private balances;


    /* Variables used in reward calculation */

    /**@notice tracks the amount of STBT each user has claimed */
    mapping(address => uint) private claimed;

    /**@notice tracks the total amount of STBT claimed by users */
    uint totalClaimed;

    /**@notice the amount of STBT deposited by Uno Re */
    uint initialAmount;


    /**@notice Uno Re's address used for depositing STBT */
    address uno;
    

    

    /**@notice need to provide the asset that is used in this vault 
      *@dev vault shares are an ERC20 called "Matrix UNO"/"xUNO", these represent a user's stablecoin stake into an UNO-RWA pool
      *@param asset - the IERC contract you wish to use as the vault asset, in this case STBT*/
    constructor(address asset, address poolAddress) ERC4626(IERC20(asset)) ERC20("Matrix UNO","xUNO") {
      stbt = IERC20(asset);
      pool = IStableSwap(poolAddress);
      stables = [0x6B175474E89094C44Da98b954EedeAC495271d0F,0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,0xdAC17F958D2ee523a2206206994597C13D831ec7];
    }


    /** USER FUNCTIONS */

    /**@notice this function allows users to stake stablecoins for xUNO
      *@dev this contract holds the stablecoins and transfers xUNO from its balance
      *@param amount - the amount of stablecoin to deposit
      *@param token - the stablecoin to deposit (DAI = 0, USDC = 1, USDT = 2) 
    */
    function stake(uint amount, uint8 token) public returns(uint shares) {
      /**@notice all the logic checks come before actually moving the tokens */
      if(amount == 0) {
        revert MatrixUno__ZeroAmountGiven();
      }
      if(token > 2) {
        revert MatrixUno__InvalidTokenId(token);
      }
      /**@notice Transfer xUNO from the vault to the user
         @dev Must add 12 zeros if user deposited USDC/USDT since these coins use 6 decimals
         DAI = 18 decimals, USDT/USDC = 6 decimals
         100 DAI  = 100000000000000000000
         100 USDC = 100000000 */
      uint transferAmount;
      if(token > 0) {
        transferAmount = amount * 1e12;
      } else {
        transferAmount = amount;
      }
      /**@notice if there's less xUNO than the user is supposed to receive, the amount staked is equal to the amount of xUNO left */
      uint transferFromAmount;
      console.log("balanceOf:", this.balanceOf(address(this)));
      if(this.balanceOf(address(this)) < transferAmount) {
        transferFromAmount = this.balanceOf(address(this));
      } else {
        transferFromAmount = amount; 
      }
      console.log("transferFrom:",transferFromAmount);
      /**@notice actually moving the tokens and updating balance */
      IERC20(stables[token]).transferFrom(msg.sender, address(this), transferFromAmount);
      balances[msg.sender][token] += transferFromAmount;
      console.log("transferAmount:", transferAmount);
      console.log("msg.sender:", msg.sender);
      this.transfer(msg.sender, transferAmount);
      shares = transferAmount;
    }

    
    /**@notice this function allows users to claim their stablecoins plus accrued rewards
      *@dev requires approving this contract to take the xUNO first
      *@param amount - the amount of xUNO you want to return to the vault
      *@param token - the stablecoin you want your interest to be in 
      *@dev (currently must match the deposited stable)*/
    function claim(uint amount, uint8 token) public returns(uint) {
      /** Steps to claim
      1. approve xUNO
      2. xUNO transferFrom to vault
      3. user balance updated
      4. STBT earned by user will be exchaned for 3CRV
      5. 3CRV will be exchanged for the stablecoin user deposited
      6. stablecoin deposit and stablecoin interest are transferred to user
     */
     this.transferFrom(msg.sender, address(this), amount);
     uint subtractAmount = amount;
     uint stableBalance = balances[msg.sender][token];
     uint rewards;
     if(token > 0) {
      subtractAmount / 1e12;
     }
     balances[msg.sender][token] -= subtractAmount;
     // calculate rewards earned by user
     uint claimedByOthers = totalClaimed - claimed[msg.sender];
     uint pot = viewRedeemable() + claimedByOthers;
     uint earned = pot / viewPortion();
     totalClaimed += earned;
     claimed[msg.sender] += earned;
     // transfer earned STBT to STBT/3CRV pool and exchange for stablecoin
     uint minimumReceive = earned;
     // 1/10000th of the earned amount (.0001)
     uint slippage = minimumReceive / 10000;
     if(token > 0) {
      (minimumReceive - slippage) / 1e12;
     } else {
      minimumReceive - slippage;
     }
     stbt.approve(address(pool), earned);
     pool.exchange_underlying(0,(token + 1), earned, minimumReceive);
     // finally transfer stablecoins to user
     IERC20(stables[token]).transfer(msg.sender, stableBalance + rewards);
     return stableBalance + rewards;
    }

    /** Native ERC-4626 Vault functions */

    /** @dev See {IERC4626-deposit}. */
    function deposit(uint256 assets, address receiver) public virtual override returns (uint256) {
        require(assets <= maxDeposit(receiver), "ERC4626: deposit more than max");

        uint256 shares = previewDeposit(assets);
        _deposit(_msgSender(), receiver, assets, shares);
        /**@notice custom MatrixUno logic to track STBT deposited by Uno Re */
        if(receiver == address(this) && msg.sender == uno) {
          initialAmount = assets;
        }

        return shares;
    }




    /** View / Pure functions */


    /**@notice this function lets you view the stablecoin balances of users */
    function viewBalance(uint8 token) public view returns(uint256 balance) {
      balance = balances[msg.sender][token];
    }

  
    /**@notice this function returns the total amount of STBT that can be redeemed for stablecoins */
    function viewRedeemable() public view returns(uint redeemable) {
      redeemable = this.totalAssets() - initialAmount;
    }

    /**@notice this function returns the amount of times that the users totalStaked goes into the initialAmount
      *@dev essentially views what portion of the STBT is being represented by the user
      *@dev for example: user who staked $50,000 DAI would have portion of 4. (1/4 of initialAmount) */
      function viewPortion() public view returns(uint portion) {
        uint daiStaked = balances[tx.origin][0];
        uint usdcStaked = (balances[tx.origin][1]) * 1e12;
        uint usdtStaked = (balances[tx.origin][2]) * 1e12;
        uint totalStaked = daiStaked + usdcStaked + usdtStaked;
        portion = initialAmount / totalStaked;
      }

  
}