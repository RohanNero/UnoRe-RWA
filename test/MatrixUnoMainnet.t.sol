// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
//pragma experimental ABIEncoderV2;

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
    // struct Permission {
    //     bool sendAllowed; // default: true
    //     bool receiveAllowed;
    //     // Address holder’s KYC will be validated till this time, after that the holder needs to re-KYC.
    //     uint64 expiryTime; // default:0 validated forever
    // }
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

    // stbtAddress: "0x530824da86689c9c17cdc2871ff29b058345b44a",
    //     poolAddress: "0x892d701d94a43bdbcb5ea28891daca2fa22a690b",
    //     unoAddress: "0x81BD585940501b583fD092BC8397F2119A96E5ba",
    //     sanctionsAddress: "0x40C57923924B5c5c5455c48D93317139ADDaC8fb",
    //     stables: [
    //       "0x6B175474E89094C44Da98b954EedeAC495271d0F",
    //       "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
    //       "0xdAC17F958D2ee523a2206206994597C13D831ec7",
    //     ],
    //     interval: "86400",
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
        //console.log("address:", address(matrixUno));
        vault = address(matrixUno);
    }

    function testHighBalance() public {
        //"STBT whale should have a high STBT balance"
        uint256 initialBal = stbt.balanceOf(sWhale);
        // console.log("initial balance", initialBal);
        assertGt(initialBal, 100000 ether);
    }

    function setPermission() public {
        //"allow moderator to update the vault's STBT permissions"
        //(bool sendAllowed, bool receiveAllowed, uint64 expiry) = stbt.permissions(vault);
        bool sendAllowed = stbt.permissions(vault).sendAllowed;
        bool receiveAllowed = stbt.permissions(vault).receiveAllowed;
        //uint64 expiryTime = stbt.permissions(vault).expiryTime;
        //console.log("prepermissions:", sendAllowed);
        console.log(sendAllowed);
        console.log(receiveAllowed);
        // going to have to setPermission through `execute` function call
        //  if (prePermissions.sendAllowed == false) {
        uint fiveEther = 5 ether;
        bytes memory payload = abi.encodeWithSignature(
            "setPermission(address,(bool,bool,uint64))",
            0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f,
            true,
            true,
            0
        );
        vm.startPrank(eWhale);
        payable(stbtModeratorProposer).transfer(fiveEther);
        payable(stbtModeratorExecutor).transfer(fiveEther);
        vm.stopPrank();
        vm.prank(stbtModeratorProposer);
        stbtModerator.schedule(
            address(stbt),
            0,
            payload,
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0x3235363030376561343437613862653633303530396531623764396132326335,
            0
        );
        skip(420);
        vm.prank(stbtModeratorExecutor);
        stbtModerator.execute(
            address(stbt),
            0,
            payload,
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0x3235363030376561343437613862653633303530396531623764396132326335
        );
        // }

        // Permission memory postPermissions = stbt.permissions(vault);
        bool postSendAllowed = stbt.permissions(vault).sendAllowed;
        bool postReceiveAllowed = stbt.permissions(vault).receiveAllowed;
        console.log("postSendAllowed:", postSendAllowed);
        console.log("postReceiveAllowed:", postReceiveAllowed);
    }

    // whitelist the vault with stbt moderator
    function testsetPermission() public {
        //"allow moderator to update the vault's STBT permissions"
        //(bool sendAllowed, bool receiveAllowed, uint64 expiry) = stbt.permissions(vault);
        bool sendAllowed = stbt.permissions(vault).sendAllowed;
        bool receiveAllowed = stbt.permissions(vault).receiveAllowed;
        //uint64 expiryTime = stbt.permissions(vault).expiryTime;
        //console.log("prepermissions:", sendAllowed);
        console.log(sendAllowed);
        console.log(receiveAllowed);
        // going to have to setPermission through `execute` function call
        //  if (prePermissions.sendAllowed == false) {
        uint fiveEther = 5 ether;
        bytes memory payload = abi.encodeWithSignature(
            "setPermission(address,(bool,bool,uint64))",
            0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f,
            true,
            true,
            0
        );
        vm.startPrank(eWhale);
        payable(stbtModeratorProposer).transfer(fiveEther);
        payable(stbtModeratorExecutor).transfer(fiveEther);
        vm.stopPrank();
        vm.prank(stbtModeratorProposer);
        stbtModerator.schedule(
            address(stbt),
            0,
            payload,
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0x3235363030376561343437613862653633303530396531623764396132326335,
            0
        );
        skip(420);
        vm.prank(stbtModeratorExecutor);
        stbtModerator.execute(
            address(stbt),
            0,
            payload,
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0x3235363030376561343437613862653633303530396531623764396132326335
        );
        // }

        // Permission memory postPermissions = stbt.permissions(vault);
        bool postSendAllowed = stbt.permissions(vault).sendAllowed;
        bool postReceiveAllowed = stbt.permissions(vault).receiveAllowed;
        console.log("postSendAllowed:", postSendAllowed);
        console.log("postReceiveAllowed:", postReceiveAllowed);
        assertTrue(postSendAllowed);
        assertTrue(postReceiveAllowed);
    }

    // deposit initial 200,000 STBT into vault
    function testUnoDeposit() public {
        setPermission();
        vm.startPrank(sWhale);
        uint256 stbtBalance = stbt.balanceOf(sWhale);
        console.log("stbtBalance:", stbtBalance);
        uint256 stbtAllowance = stbt.allowance(sWhale, address(matrixUno));
        uint stbtDeposit = 200000 ether;
        uint256 matrixUnoStbtBalance = stbt.balanceOf(address(matrixUno));

        if (stbtAllowance < stbtDeposit) {
            stbt.approve(address(matrixUno), stbtDeposit);
        }
        uint256 half = stbtDeposit / 2;
        if (matrixUnoStbtBalance < half) {
            matrixUno.deposit(stbtDeposit, address(matrixUno));
        }
        uint256 endingmatrixUnoStbtBalance = stbt.balanceOf(address(matrixUno));
        vm.stopPrank();
        //"STBT whale should be able to deposit STBT"
        assertGe(endingmatrixUnoStbtBalance, half);

        //"vault should mint and hold xUNO after the STBT deposit"
        uint256 vaultSharesBalance = matrixUno.balanceOf(vault);
        assertGe(vaultSharesBalance, 99999);
        //"reverts if `amount` input is zero"

        bytes4 selector = bytes4(keccak256("MatrixUno__ZeroAmountGiven()"));
        vm.expectRevert(abi.encodeWithSelector(selector));
        vm.prank(whale);
        matrixUno.stake(0, 1, 99);

        //"reverts if `token` input is more than two"
        selector = bytes4(keccak256("MatrixUno__InvalidTokenId(uint256)"));
        vm.expectRevert(abi.encodeWithSelector(selector, 3));
        vm.prank(whale);
        matrixUno.stake(777, 3, 99);
    }

    function UnoDeposit() public {
        setPermission();
        vm.startPrank(sWhale);
        uint256 stbtBalance = stbt.balanceOf(sWhale);
        console.log("stbtBalance:", stbtBalance);
        uint256 stbtAllowance = stbt.allowance(sWhale, address(matrixUno));
        uint stbtDeposit = 200000 ether;
        uint256 matrixUnoStbtBalance = stbt.balanceOf(address(matrixUno));

        if (stbtAllowance < stbtDeposit) {
            stbt.approve(address(matrixUno), stbtDeposit);
        }
        uint256 half = stbtDeposit / 2;
        if (matrixUnoStbtBalance < half) {
            matrixUno.deposit(stbtDeposit, address(matrixUno));
        }
        vm.stopPrank();
    }

    function testStakeStablecoin() public {
        UnoDeposit();
        vm.startPrank(whale);
        //"transfers the stablecoins from user to vault"
        uint256 initialVaultUsdcBalance = usdc.balanceOf(vault);
        uint256 initialVaultXUNOBalance = matrixUno.balanceOf(vault);
        //console.log(whale)
        uint256 usdcBalance = usdc.balanceOf(whale);
        uint256 usdcAllowance = usdc.allowance(whale, vault);
        //const usdcDeposit = 50000 * 1e6
        uint256 usdcDeposit = 5 * 1e10;
        console.log("whale usdc balance:", usdcBalance);
        console.log("vault usdc allowance:", usdcAllowance);
        console.log("initial vault usdc balance:", initialVaultUsdcBalance);
        console.log("initial vault xUNO balance:", initialVaultXUNOBalance);
        //if (usdcAllowance < usdcDeposit)

        usdc.approve(vault, usdcDeposit);

        uint256 updatedUsdcAllowance = usdc.allowance(whale, vault);
        console.log("updated vault usdc allowance:", updatedUsdcAllowance);
        uint256 totalClaimed = matrixUno.viewTotalClaimed();

        //if (initialVaultUsdcBalance < usdcDeposit) {
        uint256 shares = matrixUno.stake(usdcDeposit, 1, 99);

        uint256 finalVaultUsdcBalance = usdc.balanceOf(vault);
        console.log("final vault usdc balance:", finalVaultUsdcBalance);

        //"updates the user's balance for the staked stablecoin"
        uint256 vaultBalance = matrixUno.viewBalance(whale, 1);
        totalClaimed = matrixUno.viewTotalClaimed();
        console.log("whale usdc balance:", vaultBalance);
        console.log("total claimed:", totalClaimed);
        // eventually need to make > into = since unstake should be working properly
        bool check = vaultBalance >= 50000000000 || totalClaimed > 0;
        console.log(check);
        assertTrue(check);

        //"transfers xUNO to the user"
        uint256 whalexUnoBalance = matrixUno.balanceOf(whale);
        uint256 vaultxUnoBalance = matrixUno.balanceOf(vault);
        //string memory vaultSymbol = matrixUno.symbol();
        totalClaimed = matrixUno.viewTotalClaimed();
        console.log("whale xUNO balance:", whalexUnoBalance);
        console.log("vault xUNO balance:", vaultxUnoBalance);
        // console.log("vault shares symbol:", vaultSymbol.toString())
        console.log("total claimed:", totalClaimed);
        check = whalexUnoBalance > 1000 || totalClaimed > 0;
        assertTrue(check);
        vm.stopPrank();
    }

    function testperformUpkeep() public {
        UnoDeposit();
        //"MOCK SENDING REWARDS"
        uint256 initialVaultAssets = stbt.balanceOf(vault);
        uint256 thousandStbt = 1000 ether;
        console.log("intialVaultStbt:", initialVaultAssets);

        //if (slicedVaultAssets < 200000) {
        vm.prank(sWhale);
        stbt.transfer(vault, thousandStbt);
        console.log("mock stbt rewards distributed!");

        uint256 updatedVaultStbt = stbt.balanceOf(vault);
        console.log("updatedVaultStbt:", updatedVaultStbt);

        //"should update reward info for the week"
        uint256 interval_1 = matrixUno.viewInterval();
        uint256 initialWeek = matrixUno.viewCurrentPeriod();
        //uint256 initialInfo = matrixUno.viewRewardInfo(initialWeek);
        console.log("interval:", interval_1);
        console.log("initialWeek:", initialWeek);
        console.log(
            "rewards, vaultAssetBalance, previousWeekBalance, claimed, currentBalance, deposited, withdrawn"
        );
        // console.log("initialInfo:", initialInfo);

        bool returnVal = matrixUno.checkUpkeep();
        console.log("upkeepNeeded:", returnVal);
        if (returnVal == false) {
            
            vm.warp(block.timestamp + 1000000);
            console.log("upkeepNeeded:", matrixUno.checkUpkeep());
        }
        matrixUno.performUpkeep();
        //       await perform.wait(1)
        console.log("Upkeep Performed!");
        uint256 finalWeek = matrixUno.viewCurrentPeriod();
        //const finalInfo = matrixUno.viewRewardInfo(initialWeek);
        //const nextWeekInfo = matrixUno.viewRewardInfo(finalWeek);
        console.log("finalWeek:", finalWeek);
        // console.log("finalInfo:", finalInfo);
        // console.log("nextWeekInfo:", nextWeekInfo);
    }

    // function testViewFunctions() public {
    //     UnoDeposit();
    //     //"returns the curve pool address"
    //     address value = matrixUno.viewPoolAddress();
    //     assertEq(value, 0x892D701d94a43bDBCB5eA28891DaCA2Fa22A690b);

    //     //"returns Uno's EOA address"
    //     value = matrixUno.viewUnoAddress();
    //     assertEq(value, 0x81BD585940501b583fD092BC8397F2119A96E5ba);

    //     //"returns addresses of DAI/UDSC/USDT used by this contract"
    //     address[3] memory stables = matrixUno.viewStables();

    //     assertEq(stables[0], 0x6B175474E89094C44Da98b954EedeAC495271d0F);
    //     assertEq(stables[1], 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    //     assertEq(stables[2], 0xdAC17F958D2ee523a2206206994597C13D831ec7);

    //     //"returns the sanctionsList contract address"
    //     value = matrixUno.viewSanctionsList();
    //     assertEq(value, 0x40C57923924B5c5c5455c48D93317139ADDaC8fb);

    //     //"returns the total stable balance of the vault"
    //     uint256 bal = matrixUno.viewVaultStableBalance();
    //     vm.prank(whale);
    //     usdc.transfer(vault, 777);
    //     uint256 updatedBal = matrixUno.viewVaultStableBalance();
    //     // console.log("bal:", bal.toString())
    //     // console.log("updatedBal:", updatedBal.toString())
    //     assertGt(updatedBal, bal);

    //     //"returns amount of times that users totalStaked goes into vaultAssetBalance at given week"
    //     // uint256[] portion =  matrixUno.viewPortionAt(0, whale);
    //     // console.log(value.toString())
    //     // console.log(value[0] / 2 ** 64)
    //     //assert.equal(value[0])

    //     // describe("viewCurrentPeriod", function () {
    //     //   it("returns what week the contract is currently at", async function () {
    //     //     let week = 1
    //     //     const value = await vault.viewCurrentPeriod()
    //     //     console.log("value:", value.toString())
    //     //     console.log("week:", week)
    //     //     assert.equal(week, value)
    //     //     week++
    //     //   })
    //     // })

    //     //"returns amount of rewards a user earns"
    //     (uint value0, ) = matrixUno.viewRewards(whale);
    //     console.log(value0 >= 249);
    //     assertGe(value0, 249);

    //     //"returns the rewardInfo for given week"
    //     uint value1 = matrixUno.viewRewardInfo(0).rewards;
    //     assertGe(999999999999999999999, value1);

    //     //"view the stablecoin balances of users"
    //     // value1 = matrixUno.viewStakedBalance(whale, 1);
    //     // assertEq(value1, 5e10);

    //     //   describe("viewTotalStakedBalance", function () {
    //     //     it("view total amount a user has staked", async function () {
    //     //       const value = await vault.viewStakedBalance(whale.address, 1)
    //     //       assert.equal(value, 5e10)
    //     //     })
    //     //   })
    //     //   describe("viewLastClaimed", function () {
    //     //     it("returns the last week a user has claimed", async function () {
    //     //       const currentWeek = await vault.viewCurrentPeriod()
    //     //       const value = await vault.viewLastClaimed(whale.address)
    //     //       console.log(value)
    //     //       assert.equal(value, Number(currentWeek) - 1)
    //     //     })
    //     //   })
    //     //   describe("viewClaimedAmount", function () {
    //     //     it("returns the amount a user has claimed", async function () {
    //     //       const value = await vault.viewClaimedAmount(whale.address)
    //     //       const totalClaimed = await vault.viewTotalClaimed()
    //     //       assert.equal(value.toString(), totalClaimed)
    //     //     })
    //     //   })
    //     //   describe("viewTotalClaimed", function () {
    //     //     it("returns the totalClaimed variable", async function () {
    //     //       const value = await vault.viewTotalClaimed()
    //     //       const totalClaimed = await vault.viewClaimedAmount(whale.address)
    //     //       assert.equal(value.toString(), totalClaimed)
    //     //     })
    //     //   })
    //     //   describe("viewTotalStaked", function () {
    //     //     it("returns the totalStaked variable", async function () {
    //     //       const value = await vault.viewTotalStaked()
    //     //       console.log(value)
    //     //       const convertedAmount = value.toLocaleString("fullwide", {
    //     //         useGrouping: false,
    //     //       })
    //     //       assert.equal(convertedAmount, 50000000000000000000000)
    //     //     })
    //     //   })
    //     //   describe("viewUnoDeposit", function () {
    //     //     it("returns the amount of STBT that Uno Re has deposited into the vault", async function () {
    //     //       const value = await vault.viewUnoDeposit()
    //     //       console.log(value)
    //     //       const convertedAmount = value.toLocaleString("fullwide", {
    //     //         useGrouping: false,
    //     //       })
    //     //       assert.equal(convertedAmount, 200000000000000000000000)
    //     //     })
    //     //   })
    //     //   describe("viewStartingtime", function () {
    //     //     it("returns the vault's starting timestamp", async function () {
    //     //       const value = await vault.viewStartingtime()
    //     //       const lastUpkeep = await vault.viewLastUpkeepTime()
    //     //       assert.isBelow(value, lastUpkeep)
    //     //     })
    //     //   })
    //     //   describe("viewLastUpkeepTime", function () {
    //     //     it("returns the last time this contract had upkeep performed", async function () {
    //     //       const value = await vault.viewLastUpkeepTime()
    //     //       const startingTime = await vault.viewStartingtime()
    //     //       assert.isAbove(value, startingTime)
    //     //     })
    //     //   })
    //     //   describe("viewInterval", function () {
    //     //     it("returns the seconds in each rewards period", async function () {
    //     //       const value = await vault.viewInterval()
    //     //       assert.equal(value, 86400)
    //     //     })
    //     //   })
    //     //   describe("viewUnaccountedRewards", function () {
    //     //     it("returns the amount of rewards that can be claimed by uno", async function () {
    //     //       const value = await vault.viewUnaccountedRewards()
    //     //       await vault.connect(sWhale).unoClaim()
    //     //       const updatedValue = await vault.viewUnaccountedRewards()
    //     //       // console.log(value.toString())
    //     //       // console.log(updatedValue.toString())
    //     //       assert.isAbove(value, updatedValue)
    //     //     })
    //     //   })
    //     //   describe("viewStakeConversionRate", function () {
    //     //     it("returns the current stake STBT / stablecoin conversion", async function () {
    //     //       const value = await vault.viewStakeConversionRate()
    //     //       const unstakeValue = await vault.viewUnstakeConversionRate()
    //     //       const number =
    //     //         (Number(value) / 2 ** 64) * (Number(unstakeValue) / 2 ** 64)
    //     //       //console.log(number.toString())
    //     //       assert.approximately(number, 1, 0.5)
    //     //     })
    //     //   })
    //     //   describe("viewUnstakeConversionRate", function () {
    //     //     it("returns the current unstake STBT / stablecoin conversion", async function () {
    //     //       const value = await vault.viewUnstakeConversionRate()
    //     //       const stakeValue = await vault.viewStakeConversionRate()
    //     //       const number =
    //     //         (Number(value) / 2 ** 64) * (Number(stakeValue) / 2 ** 64)
    //     //       //console.log(number.toString())
    //     //       assert.approximately(number, 1, 0.5)
    //     //     })
    //     //   })
    // }
}
