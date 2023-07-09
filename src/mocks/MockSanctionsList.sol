//SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

contract MockSanctionsList {

    /**@notice mapping storing bool whether addresses are sanctioned or not */
    mapping(address => bool) private sanctionedMap;

    /**@notice returns bool representing if an address is sanctioned or not */
    function isSanctioned(address addr) public view returns (bool) {
        return sanctionedMap[addr];
    }

    /**@notice toggles the boolean at `addr` in the sanctionedMap */
    function toggleSanctioned(address addr) public {
        if(isSanctioned(addr) == true) {
           sanctionedMap[addr] = false; 
        } else {
            sanctionedMap[addr] = true;
        }
        
    }
}