//SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IUSDT.sol";

/**@title Mock Curve STBT/3CRV Pool
 *@author Rohan Nero
 *@notice This is a mock version of the real STBT/3CRV pool
 *@dev This pool allows users to swap STBT for "USDC"
 *@dev This pool must be sent Goerli "USDC" before the function will work */
contract MockCurvePool {
    /**@notice Goerli STBT contract */
    IERC20 private stbt = IERC20(0x0f539454d2Effd45E9bFeD7C57B2D48bFd04CB32);

    /**@notice Goerli USDC contract */
    IERC20 private usdc = IERC20(0x43c7181e745Be7265EB103c5D69F1b7b4EF8763f);

    /**@notice Goerli USDT contract */
    IUSDT private usdt = IUSDT(0xf0A72B71665e161a27741EA5ed4391000C905098);

    /**@notice Goerli DAI contract */
    IERC20 private dai = IERC20(0xb72ff7B2cEF9dEE389CA68744f5EC6B9Ba4E5F32);

    /**@notice Perform an exchange between two underlying coins
     *@dev need this function to allow swapping STBT into USDC
     *@param i Index value for the underlying coin to send
     *@param j Index valie of the underlying coin to receive
     *@param _dx Amount of `i` being exchanged
     *@param _min_dy Minimum amount of `j` to receive
     *@return Actual amount of `j` received */
    function exchange_underlying(
        int128 i,
        int128 j,
        uint256 _dx,
        uint256 _min_dy
    ) public returns (uint256) {
        stbt.transferFrom(msg.sender, address(this), _dx);
        /**@notice the amount is divided by 1e12 to remove 12 zeros since USDC only has 6 decimals */
        if (j == 1) {
            dai.transfer(msg.sender, _min_dy);
        } else if (j == 2) {
            usdc.transfer(msg.sender, _min_dy);
        } else if (j == 3) {
            usdt.transfer(msg.sender, _min_dy);
        }
        return _min_dy;
    }

    /**@notice returns the return value from calling this function on the actual pool 23/6/25 */
    function get_virtual_price() public pure returns (uint256) {
        return 1008309935958532778;
    }
}
