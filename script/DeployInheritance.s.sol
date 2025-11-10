// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {Inheritance} from "../src/Inheritance.sol";

contract DeployInheritance is Script {
    function run() external returns (Inheritance) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address heir = vm.envAddress("HEIR_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);
        Inheritance inheritance = new Inheritance(heir);
        vm.stopBroadcast();

        return inheritance;
    }
}

