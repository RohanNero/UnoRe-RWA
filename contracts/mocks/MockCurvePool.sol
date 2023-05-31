//SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

/**@title Mock Curve STBT/3CRV Pool
 *@author Rohan Nero
 *@notice This is a fake version of the real STBT/3CRV pool
 *@dev This pool allows users to swap STBT for USDC */
contract MockCurvePool {
    /**@notice Perform an exchange between two underlying coins
     *@dev need this function to allow swapping STBT into USDC
     *@param i Index value for the underlying coin to send
     *@param j Index valie of the underlying coin to receive
     *@param _dx Amount of `i` being exchanged
     *@param _min_dy Minimum amount of `j` to receive
     *@param _receiver Address that receives `j`
     *@return Actual amount of `j` received */
    function exchange_underlying(
        int128 i,
        int128 j,
        uint256 _dx,
        uint256 _min_dy,
        address _receiver
    ) public returns (uint256) {}
}
