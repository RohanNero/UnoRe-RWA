//SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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


    /**@notice STBT token address used as the vault asset */
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
    mapping(address => mapping(uint => uint)) private balances;
    

    /**@notice need to provide the asset that is used in this vault 
      *@dev vault shares are an ERC20 called "Matrix UNO"/"xUNO", these represent a user's stablecoin stake into an UNO-RWA pool
      *@param asset - the IERC contract you wish to use as the vault asset, in this case STBT*/
    constructor(address asset) ERC4626(IERC20(asset)) ERC20("Maple UNO","mUNO") {
      stbt = IERC20(asset);
      stables = [0x6B175474E89094C44Da98b954EedeAC495271d0F,0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,0xdAC17F958D2ee523a2206206994597C13D831ec7];
    }


    /** USER FUNCTIONS */

    /**@notice this function allows users to stake stablecoins for xUNO
      *@dev this contract holds the stablecoins and transfers xUNO from its balance
      *@param amount - the amount of stablecoin to deposit
      *@param token - the stablecoin to deposit (DAI = 0, USDC = 1, USDT = 2) 
    */
    function stake(uint amount, uint token) public returns(uint shares) {
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
        transferAmount = transferAmount * 10 ** 12;
      } else {
        transferAmount = amount;
      }
      /**@notice if there's less xUNO than the user is supposed to receive, the amount staked is equal to the amount of xUNO left */
      uint transferFromAmount;
      if(this.balanceOf(address(this)) < transferAmount) {
        transferFromAmount = this.balanceOf(address(this));
      } else {
        transferFromAmount = amount; 
      }
      /**@notice actually moving the tokens and updating balance */
      IERC20(stables[token]).transferFrom(msg.sender, address(this), transferFromAmount);
      balances[msg.sender][token] += amount;
      this.transfer(msg.sender, transferAmount);
    }

    
    /**@notice this function allows users to claim their stablecoins plus accrued rewards
      *@dev requires approving this contract to take the xUNO first
      *@param amount - the amount of xUNO you want to return to the vault
      *@param token - the stablecoin you want your interest to be in */
    function claim(uint amount, uint token) public returns(uint claimed) {

    }

  
}