// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {Solchip8} from "../src/Solchip8.sol";

contract Solchip8Script is Script {
    Solchip8 public solchip8;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        solchip8 = new Solchip8();

        console2.log("solchip8 deployed at: ", address(solchip8));

        vm.stopBroadcast();
    }
}
