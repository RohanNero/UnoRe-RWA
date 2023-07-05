//SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUSDT is ERC20 {
    constructor() ERC20("MockUSDT", "mUSDT") {}

    /**@notice mints `amount` of mUSDT and transfers it to msg.sender */
    function getMockUSDT(uint amount) public {
        _mint(msg.sender, amount);
    }
}
