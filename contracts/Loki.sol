//SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

/**@title UNO Loki staking pool
  *@author Rohan Nero
  *@notice this contract stakes not only with UNO SSIP but with a Matrixdock RWA pool
  *@dev interacts with the MatrixUNO ERC4626 vault */
contract Loki {
    
    mapping(address => uint) public balances;

     /**@notice users use this function to deposit USDC in return for mUNO 
      *@dev must approve before this function can transferFrom */
    function enterPool(uint amount) public payable returns(uint sharesReceived) {

        // // to ensure mUNO was sent to user we check the user's balance before deposit
        // uint bal = IERC20(i_vault).balanceOf(msg.sender);
        
        // // USDC received
        // i_usdc.transferFrom(msg.sender, address(this), amount);

        // // approve USDC for Maple `transferFrom`
        // i_usdc.approve(address(i_pool), amount);

        // // deposit USDC with Maple LP and send Maple shares to this contract
        // uint shares = i_pool.deposit(amount, address(this));

        // // deposit Maple LP tokens into MapleUNO vault
        // IERC4626(i_vault).deposit(shares, msg.sender);

        // // to ensure mUNO was sent to user we check the user's balance after deposit
        // uint postBal = IERC20(i_vault).balanceOf(msg.sender);

        // // revert if shares weren't received correctly
        // if(bal >= postBal) {
        //     revert Hades__SharesNotReceived();
        // }

        // // emit deposit with amount deposited and amount of shares sent to msg.sender
        // emit HadesDeposit(amount, postBal - bal);

        // // return sharesReceived
        // return postBal - bal;
    }


}