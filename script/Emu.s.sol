// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {Emu} from "../src/Emu.sol";

contract EmulatorScript is Script {
    Emu public emulator;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        emulator = new Emu();

        console2.log("emulator deployed at: ", address(emulator));

        vm.stopBroadcast();
    }
}
