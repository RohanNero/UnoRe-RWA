//SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**@title MapleUNO
  *@author Rohan Nero
  *@notice this contract allows UNO users to stake with Maple RWA asset pools at the same time as UNO SSIP pools
  *@dev UNO's vault stores the Maple vault `shares` token as its asset */
contract MapleUNO is ERC4626 {


    IERC20 private immutable _asset;
    

    /**@notice need to provide the asset that is used in this vault
      *@dev an example Maple USDC pool address: 0xd3cd37a7299B963bbc69592e5Ba933388f70dc88
      *@param asset_ the IERC contract you wish to use as the vault asset */
    constructor(IERC20 asset_) ERC4626(asset_) ERC20("Maple UNO","mUNO") {
      _asset = asset_;
    }



  
}