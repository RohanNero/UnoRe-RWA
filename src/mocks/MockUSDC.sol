//SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("MockUSDC", "mUSDC") {
        _mint(msg.sender, 1000000 ether);
    }

    /**@notice mints `amount` of mUNO and transfers it to msg.sender */
    function getMockUSDC(uint amount) public {
        _mint(msg.sender, amount);
    }
}
