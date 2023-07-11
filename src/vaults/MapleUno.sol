//SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title MapleUNO
 * @author Rohan Nero
 * @notice this contract allows UNO users to stake with Maple RWA asset pools at the same time as UNO SSIP pools
 * @dev UNO's vault stores the Maple vault `shares` token as its asset
 */
contract MapleUNO is ERC4626 {
    IERC20 private immutable _asset;

    /**
     * @notice need to provide the asset that is used in this vault 
     * @notice vault shares are an ERC20 called "Maple UNO", these represent a user's stablecoin stake into an UNO-RWA pool
     * @dev an example Maple USDC pool address: 0xd3cd37a7299B963bbc69592e5Ba933388f70dc88
     * @param asset_ the IERC contract you wish to use as the vault asset, in this case `MPLcashUSDC`
     */
    constructor(address asset_) ERC4626(IERC20(asset_)) ERC20("Maple UNO", "mUNO") {
        _asset = IERC20(asset_);
    }
}
