//SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

/**@title UNO Loki staking pool
  *@author Rohan Nero
  *@notice this contract stakes not only with UNO SSIP but with a Matrixdock RWA pool
  *@dev interacts with the MatrixUNO ERC4626 vault */
contract Loki {
    
    mapping(address => uint) public balances;


    //MapleUNO private immutable i_vault;
    IERC20 private immutable i_usdc;

    /**@notice the MatrixUNO vault */
    IERC4626 private immutable i_vault;

    /**@notice STBT issuer that handles deposits and redemptions */
    address private immutable i_issuer;

    event HadesDeposit(uint depositAmount, uint sharesReceived);


    /**@notice this contract needs to interact with the MatrixUNO vault as well as the Matrixdock STBT contracts
      *@param vault this is the MatrixUNO vault that stores STBT and issues xUNO
      *@param usdc this is the USDC contract address
      *@param issuer this is the Matrixdock Issuer that handles deposits and withdrawals
       */
    constructor(address vault, address usdc, address issuer) {
        //i_vault = MapleUNO(vault);
        i_usdc = IERC20(usdc);
        i_vault = IERC4626(vault);
        i_issuer = issuer;
    }

     /**@notice users use this function to deposit USDC in return for mUNO 
      *@dev must approve before this function can transferFrom */
      function enterPool(uint amount) public payable returns(uint sharesReceived) {

        // first accept stablecoin from user (must approve first)
        i_usdc.transferFrom(msg.sender, address(this), amount);

        // deposit stablecoin into MatrixUNO vault
        i_vault.deposit(amount, address(this));

        // then transfer stablecoin to STBT Issuer
        i_usdc.transfer(i_issuer, amount);

        // from here we are waiting for the STBT to be received from the Issuer contract
        // xUNO is earning yield from UNO by being held inside Loki pool but at the same time earning STBT yield since the user's 
        // stablecoin investment was transferred for STBT with issuer. 
    }


}