//SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockSTBT is ERC20 {

    constructor() ERC20("MockSTBT","mSTBT") {
    }
}