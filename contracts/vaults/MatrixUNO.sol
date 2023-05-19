//SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

error MatrixUno__ZeroAmountGiven();

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
      if(amount == 0) {
        revert MatrixUno__ZeroAmountGiven();
      }
      IERC20(stables[token]).transferFrom(msg.sender, address(this), amount);
      balances[msg.sender][token] += amount;
    }

    
    /**@notice this function allows users to claim their stablecoins plus accrued rewards
      *@dev requires approving this contract to take the xUNO first
      *@param amount - the amount of xUNO you want to return to the vault
      *@param token - the stablecoin you want your interest to be in */
    function claim(uint amount, uint token) public returns(uint claimed) {

    }

  
}