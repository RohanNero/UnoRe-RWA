// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILP {
    // Events
    event Transfer(
        address indexed sender,
        address indexed receiver,
        uint256 value
    );
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event TokenExchange(
        address indexed buyer,
        int128 soldId,
        uint256 tokensSold,
        int128 boughtId,
        uint256 tokensBought
    );
    event TokenExchangeUnderlying(
        address indexed buyer,
        int128 soldId,
        uint256 tokensSold,
        int128 boughtId,
        uint256 tokensBought
    );
    event AddLiquidity(
        address indexed provider,
        uint256[2] tokenAmounts,
        uint256[2] fees,
        uint256 invariant,
        uint256 tokenSupply
    );
    event RemoveLiquidity(
        address indexed provider,
        uint256[2] tokenAmounts,
        uint256[2] fees,
        uint256 tokenSupply
    );
    event RemoveLiquidityOne(
        address indexed provider,
        uint256 tokenAmount,
        uint256 coinAmount,
        uint256 tokenSupply
    );
    event RemoveLiquidityImbalance(
        address indexed provider,
        uint256[2] tokenAmounts,
        uint256[2] fees,
        uint256 invariant,
        uint256 tokenSupply
    );
    event RampA(
        uint256 oldA,
        uint256 newA,
        uint256 initialTime,
        uint256 futureTime
    );
    event StopRampA(uint256 A, uint256 t);

    // Functions
    function initialize(
        string memory _name,
        string memory _symbol,
        address _coin,
        uint256 _rateMultiplier,
        uint256 _A,
        uint256 _fee
    ) external;

    function decimals() external view returns (uint256);

    function transfer(address _to, uint256 _value) external returns (bool);

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external returns (bool);

    function approve(address _spender, uint256 _value) external returns (bool);

    function balances(uint256 i) external view returns (uint256);

    function get_balances() external view returns (uint256[2] memory);

    function admin_fee() external view returns (uint256);

    function A() external view returns (uint256);

    function A_precise() external view returns (uint256);

    function get_virtual_price() external view returns (uint256);

    function calc_token_amount(
        uint256[2] memory _amounts,
        bool _isDeposit
    ) external view returns (uint256);

    function add_liquidity(
        uint256[2] memory _amounts,
        uint256 _minMintAmount
    ) external returns (uint256);

    function add_liquidity(
        uint256[2] memory _amounts,
        uint256 _minMintAmount,
        address _receiver
    ) external returns (uint256);

    function get_dy(
        int128 i,
        int128 j,
        uint256 dx
    ) external view returns (uint256);

    function get_dy_underlying(
        int128 i,
        int128 j,
        uint256 dx
    ) external view returns (uint256);

    function exchange(
        int128 i,
        int128 j,
        uint256 _dx,
        uint256 _minDy
    ) external returns (uint256);

    function exchange(
        int128 i,
        int128 j,
        uint256 _dx,
        uint256 _minDy,
        address _receiver
    ) external returns (uint256);

    function exchange_underlying(
        int128 i,
        int128 j,
        uint256 _dx,
        uint256 _minDy
    ) external returns (uint256);

    function exchange_underlying(
        int128 i,
        int128 j,
        uint256 _dx,
        uint256 _minDy,
        address _receiver
    ) external returns (uint256);

    function remove_liquidity(
        uint256 _burnAmount,
        uint256[2] memory _minAmounts
    ) external returns (uint256[2] memory);

    function remove_liquidity(
        uint256 _burnAmount,
        uint256[2] memory _minAmounts,
        address _receiver
    ) external returns (uint256[2] memory);

    function remove_liquidity_imbalance(
        uint256[2] memory _amounts,
        uint256 _maxBurnAmount
    ) external returns (uint256);

    function remove_liquidity_imbalance(
        uint256[2] memory _amounts,
        uint256 _maxBurnAmount,
        address _receiver
    ) external returns (uint256);

    function calc_withdraw_one_coin(
        uint256 _burnAmount,
        int128 i
    ) external view returns (uint256);

    function remove_liquidity_one(
        uint256 _burnAmount,
        int128 i,
        uint256 _minReceived
    ) external returns (uint256);

    function remove_liquidity_one(
        uint256 _burnAmount,
        int128 i,
        uint256 _minReceived,
        address _receiver
    ) external returns (uint256);

    function ramp_A(uint256 _futureA, uint256 _futureTime) external;

    function stop_ramp_A() external;

    function withdraw_admin_fees() external;

    function coins(uint256 arg0) external view returns (address);

    function admin_balances(uint256 arg0) external view returns (uint256);

    function fee() external view returns (uint256);

    function initial_A() external view returns (uint256);

    function future_A() external view returns (uint256);

    function initial_A_time() external view returns (uint256);

    function future_A_time() external view returns (uint256);

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function balanceOf(address arg0) external view returns (uint256);

    function allowance(
        address arg0,
        address arg1
    ) external view returns (uint256);

    function totalSupply() external view returns (uint256);
}
