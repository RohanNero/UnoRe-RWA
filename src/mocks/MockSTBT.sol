//SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockSTBT is ERC20 {
    constructor() ERC20("MockSTBT", "mSTBT") {
        _mint(msg.sender, 1000000 ether);
    }

    function getMockSTBT(uint256 amount) public {
        _mint(msg.sender, amount);
    }
}
