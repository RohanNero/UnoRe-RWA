//SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

interface IStableSwap {

    // ERC 20 functions
    function approve(address,uint256) external;
    function balanceOf(address,uint256) external view returns(uint256);

    // Curve functions

    function coins(uint256) external view returns(address);
    function get_virtual_price() external view returns(uint256);
    function calc_token_amount(uint256[] calldata,bool) external view returns(uint256);
    function exchange_underlying(int128,int128,uint256,uint256) external returns(uint);
    function fee() external view returns(uint256);

// interface Curve:
//     def coins(i: uint256) -> address: view
//     def get_virtual_price() -> uint256: view
//     def calc_token_amount(amounts: uint256[BASE_N_COINS], deposit: bool) -> uint256: view
//     def calc_withdraw_one_coin(_token_amount: uint256, i: int128) -> uint256: view
//     def fee() -> uint256: view
//     def get_dy(i: int128, j: int128, dx: uint256) -> uint256: view
//     def exchange(i: int128, j: int128, dx: uint256, min_dy: uint256): nonpayable
//     def add_liquidity(amounts: uint256[BASE_N_COINS], min_mint_amount: uint256): nonpayable
//     def remove_liquidity_one_coin(_token_amount: uint256, i: int128, min_amount: uint256): nonpayable
}

