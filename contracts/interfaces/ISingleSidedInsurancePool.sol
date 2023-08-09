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
>>>>>>> 0683404acad624a2f7425d8113cc0ddffe993b0c
