//SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

/**@title UNO Loki staking pool
  *@author Rohan Nero
  *@notice this contract stakes not only with UNO SSIP but with a Matrixdock RWA pool
  *@dev interacts with the MatrixUNO ERC4626 vault */
contract Loki {
    
    mapping(address => uint) public balances;

}