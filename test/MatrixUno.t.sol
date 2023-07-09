// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/vaults/MatrixUno.sol";
import "../src/mocks/MockSTBT.sol";
import "../src/mocks/MockCurvePool.sol";
import "../src/mocks/MockSanctionsList.sol";
import "../src/mocks/MockUSDT.sol";
import "../src/mocks/MockDAI.sol";
import "../src/mocks/MockUSDC.sol";
import "../src/mocks/MockUno.sol";

contract CounterTest is Test {
    MatrixUno public matrixUno;
    MockSTBT public mockSTBT;
    MockSanctionsList public mockSanctionsList;
    MockUSDT public mockUSDT;
    MockDAI public mockDAI;
    MockUSDC public mockUSDC;
    MockUNO public mockUNO;
    MockCurvePool public mockCurvePool;
    uint256 interval = 604800;

    function setUp() public {
        mockSTBT = new MockSTBT();
        mockCurvePool = new MockCurvePool();
        mockUNO = new MockUNO();
        mockUSDC = new MockUSDC();
        mockSanctionsList = new MockSanctionsList();
        mockDAI = new MockDAI();
        mockUSDT = new MockUSDT();
        matrixUno = new MatrixUno(
            address(mockSTBT),
            address(mockCurvePool),
            address(mockUNO),
            address(mockSanctionsList),
            [address(mockDAI), address(mockUSDC), address(mockUSDT)],
            interval
        );
    }

    function testStake() public {
        matrixUno.stake(1 ether, 0, 1);
        // assertEq(counter.number(), 1);
    }

    function testDeposit(uint96 amount) public {
        uint256 balanceBefore = mockSTBT.balanceOf(address(matrixUno));
        mockSTBT.getMockSTBT(amount);
        mockSTBT.approve(address(matrixUno), amount);
        matrixUno.deposit(amount, address(mockSTBT));
        uint256 balanceAfter = mockSTBT.balanceOf(address(matrixUno));
        assertEq(balanceAfter, balanceBefore + amount);
    }

    // function testZeroDepositError() public {
    //     vm.expectRevert(MatrixUno.MatrixUno__ZeroAmountGiven.selector);
    //     matrixUno.stake(0, 1, 99);
    // }

    // function testSetNumber(uint256 x) public {
    //     counter.setNumber(x);
    //     assertEq(counter.number(), x);
    // }
}
