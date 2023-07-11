// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/vaults/MatrixUno.sol";
import "../src/interfaces/IUSDC.sol";
import "../src/interfaces/ILP.sol";
import "../src/interfaces/IGauge.sol";
import "../src/interfaces/IthreeCRV.sol";
import "../src/interfaces/ICRV.sol";
import "../src/interfaces/IMinter.sol";
import "../src/interfaces/ISTBT.sol";
import "../src/interfaces/ISTBTModerator.sol";

contract MatrixUNOTest is Test {
    struct Permission {
        bool sendAllowed; // default: true
        bool receiveAllowed;
        // Address holder’s KYC will be validated till this time, after that the holder needs to re-KYC.
        uint64 expiryTime; // default:0 validated forever
    }
    address public whale = 0x171cda359aa49E46Dec45F375ad6c256fdFBD420;
    address public sWhale = 0x81BD585940501b583fD092BC8397F2119A96E5ba;
    address public eWhale = 0x868daB0b8E21EC0a48b726A1ccf25826c78C6d7F;
    address public stbtModeratorExecutor =
        0xd32a1441872774f30EC9C453983cf5C95a720123;
    address public stbtModeratorProposer =
        0x65FF5a67D8d7292Bd4Ea7B6CD863D9F3ca14f046;
    IUSDC public usdc = IUSDC(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    ILP public lp = ILP(0x892D701d94a43bDBCB5eA28891DaCA2Fa22A690b);
    IGauge public gauge = IGauge(0x4B6911E1aE9519640d417AcE509B9928D2F8377B);
    IthreeCRV public threeCRV =
        IthreeCRV(0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490);
    IStableSwap public stableSwap =
        IStableSwap(0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7);
    ICRV public crv = ICRV(0xD533a949740bb3306d119CC777fa900bA034cd52);
    IMinter public minter = IMinter(0xd061D61a4d941c39E5453435B6345Dc261C2fcE0);
    ISTBT public stbt = ISTBT(0x530824DA86689C9C17CdC2871Ff29B058345b44a);
    ISTBTModerator public stbtModerator =
        ISTBTModerator(0x22276A1BD16bc3052b362C2e0f65aacE04ed6F99);
    MatrixUno public matrixUno;
    address vault;
    uint256 public interval = 604800;

    function setUp() public {
        matrixUno = new MatrixUno(
            0x530824DA86689C9C17CdC2871Ff29B058345b44a,
            0x892D701d94a43bDBCB5eA28891DaCA2Fa22A690b,
            0x81BD585940501b583fD092BC8397F2119A96E5ba,
            0x40C57923924B5c5c5455c48D93317139ADDaC8fb,
            [
                0x6B175474E89094C44Da98b954EedeAC495271d0F,
                0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,
                0xdAC17F958D2ee523a2206206994597C13D831ec7
            ],
            interval
        );
        vault = address(matrixUno);
    }

    function testHighBalance() public {
        //"STBT whale should have a high STBT balance"
        uint256 initialBal = stbt.balanceOf(sWhale);
        // console.log("initial balance", initialBal);
        assertGt(initialBal, 100000 ether);
    }

    // function testsetPermission() public {
    //     //"allow moderator to update the vault's STBT permissions"
    //     //Permission calldata prePermissions = stbt.permissions(vault);
    //     //console.log("prepermissions:", prePermissions);
    //     // going to have to setPermission through `execute` function call
    //     //  if (prePermissions.sendAllowed == false) {
    //     uint fiveEther = 5 ether;
    //     vm.startPrank(eWhale);
    //     payable(stbtModeratorProposer).transfer(fiveEther);
    //     payable(stbtModeratorExecutor).transfer(fiveEther);
    //     vm.stopPrank();
    //     vm.prank(stbtModeratorProposer);
    //     stbtModerator.schedule(
    //         address(stbt),
    //         0,
    //         "0x47e640c000000000000000000000000097fd63d049089cd70d9d139ccf9338c81372de68000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000",
    //         0x0000000000000000000000000000000000000000000000000000000000000000,
    //         0x3235363030376561343437613862653633303530396531623764396132326335,
    //         0
    //     );
    //     vm.prank(stbtModeratorExecutor);
    //     stbtModerator.execute(
    //         address(stbt),
    //         0,
    //         "0x47e640c000000000000000000000000097fd63d049089cd70d9d139ccf9338c81372de68000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000",
    //         0x0000000000000000000000000000000000000000000000000000000000000000,
    //         0x3235363030376561343437613862653633303530396531623764396132326335
    //     );
    //     // }

    //     //  Permission calldata postPermissions = stbt.permissions(vault);
    //     //assertTrue(postPermissions.receiveAllowed);
    // }

    function testWhaleDeposit() public {
        uint256 stbtBalance = stbt.balanceOf(sWhale);
        console.log(stbtBalance);
        uint256 stbtAllowance = stbt.allowance(sWhale, address(matrixUno));
        uint stbtDeposit = 1 ether;
        uint256 matrixUnoStbtBalance = stbt.balanceOf(address(matrixUno));

        if (stbtAllowance < stbtDeposit) {
            vm.prank(sWhale);
            stbt.approve(address(matrixUno), stbtDeposit);
        }
        uint256 half = stbtDeposit / 2;
        if (matrixUnoStbtBalance < half) {
            vm.prank(sWhale);
            matrixUno.deposit(stbtDeposit, address(matrixUno));
        }
        uint256 endingmatrixUnoStbtBalance = stbt.balanceOf(address(matrixUno));
        assertGe(endingmatrixUnoStbtBalance, half);
    }
}
