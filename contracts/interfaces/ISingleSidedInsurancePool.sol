// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.7;

interface ISingleSidedInsurancePool {
    function updatePool() external;

    function enterInPool(uint256 _amount) external payable;

    function leaveFromPoolInPending(uint256 _amount) external;

    function leaveFromPending() external;

    function harvest(address _to) external;

    function lpTransfer(address _from, address _to, uint256 _amount) external;

    function riskPool() external view returns (address);
<<<<<<< HEAD
}
=======
}
>>>>>>> 7c475f15903075f6cac3d37ea7b64bebb43815c1
