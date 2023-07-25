//SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

interface IMatrixUno {

    struct rewardInfo {
        uint256 rewards;
        uint256 previousPeriodBalance;
        uint256 currentBalance;
        uint256 claimed;
        uint256 deposited;
        uint256 withdrawn;
        uint256 vaultAssetBalance;
        uint256 unoDeposit;
        uint256 startTime;
        uint256 endTime;
    }

    event Deposit(
        address indexed caller,
        address indexed receiver,
        uint256 amount,
        uint256 shares
    );
    event Withdraw(
        address indexed caller,
        address indexed receiver,
        address indexed owner,
        uint256 amount,
        uint256 shares
    );
    event Stake(uint256 amount, address indexed owner);
    event Unstake(uint256 amount, address indexed owner);
    event Claim(uint256 stakingRewards, uint256 savingRewards);
    event UpkeepPerformed(rewardInfo currentPeriod);
    event UnoClaim(uint256 amount);

    function stake(
        uint256 amount,
        uint8 token,
        uint256 minimumPercentage
    ) external returns (uint256 shares);

    function unstake(
        uint256 amount,
        uint8 token,
        uint256 minimumPercentage
    ) external returns (uint256);

    function claim(
        address addr,
        uint8 token,
        uint256 minimumPercentage
    ) external returns (uint256, uint256);

    function unoClaim() external;

    function setSpendingTokens(uint8[4] memory tokens) external;

    // ERC-4626 functions
    function deposit(uint256 assets, address receiver) external returns (uint256);

    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) external returns (uint256);

    // ERC-20 functions
    function transfer(address to, uint256 value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);
}
    function viewPoolAddress() external view returns (address);

    function viewUnoAddress() external view returns (address);

    function viewStables() external view returns (address[3] memory);

    function viewSanctionsList() external view returns (address);

    function viewVaultStableBalance()
        external
        view
        returns (uint totalStableBal);

    function viewRedeemableAt(
        uint period
    ) external view returns (uint redeemable);

    function viewPortionAt(
        uint period,
        address addr
    ) external view returns (int128 portion, int128 sPortion);

    function viewCurrentPeriod() external view returns (uint);

    function viewRewards(address addr) external view returns (uint, uint);

    function viewRewardInfo(
        uint period
    ) external view returns (rewardInfo memory);

    function viewBalance(
        address user,
        uint8 token
    ) external view returns (uint256 balance);

    function viewTotalStableBalance(
        address user
    ) external view returns (uint totalUserStaked);

    function viewTotalBalance(
        address addr
    ) external view returns (uint totalBalance);

    function viewLastClaimed(address user) external view returns (uint16);

    function viewClaimedAmount(address user) external view returns (uint);

    function viewTotalClaimed() external view returns (uint _totalClaimed);

    function viewTotalStaked() external view returns (uint _totalStaked);

    function viewUnoDeposit() external view returns (uint);

    function viewStartingtime() external view returns (uint);

    function viewLastUpkeepTime() external view returns (uint);

    function viewInterval() external view returns (uint);

    function calculateUnaccountedRewards() external view returns (uint);

    function viewUnaccountedRewards() external view returns (uint);

    function viewAccountedForStbt() external view returns (uint);

    function viewStakeConversionRate()
        external
        view
        returns (int128 conversionRate);

    function viewUnstakeConversionRate()
        external
        view
        returns (int128 conversionRate);

    function hasDuplicates(uint8[4] memory arr) external pure returns (bool);
}
