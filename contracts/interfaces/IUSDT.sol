// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

interface IUSDT {
    function transferFrom(address _from, address _to, uint256 _value) external;

    function approve(address _spender, uint256 _value) external;

    function transfer(address _to, uint256 _value) external;

    function balanceOf(address who) external view returns (uint256);
}