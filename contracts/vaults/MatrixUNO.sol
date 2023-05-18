//SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**@title MatrixUno
  *@author Rohan Nero
  *@notice this contract allows UNO users to earn native STBT yields from Matrixdock.
  *@dev This vault uses STBT as the asset and xUNO as the shares token*/
contract MapleUNO is ERC4626 {


    IERC20 private immutable _asset;
    

    /**@notice need to provide the asset that is used in this vault 
      *@dev vault shares are an ERC20 called "Matrix UNO"/"xUNO", these represent a user's stablecoin stake into an UNO-RWA pool
      *@param asset_ the IERC contract you wish to use as the vault asset, in this case STBT*/
    constructor(address asset_) ERC4626(IERC20(asset_)) ERC20("Maple UNO","mUNO") {
      _asset = IERC20(asset_);
    }


    // need function to stake stablecoins and function to return/withdrawal stablecoins

    /**@notice this function allows users to stake stablecoins for xUNO
      *@dev this contract holds the stablecoins and transfers xUNO from its balance
      *@param amount - the amount of stablecoin to deposit
      *@param token - the stablecoin to deposit (DAI = 0, USDC = 1, USDT = 2) 
    */
    function stake(uint amount, uint token) public payable returns(uint shares) {
    }


    function claim() public returns(uint claimed) {

    }

  
}