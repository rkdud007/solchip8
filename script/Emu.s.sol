// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {Emu} from "../src/Emu.sol";

contract EmulatorScript is Script {
    Emu public emulator;

    function setUp() public {
        emulator = new Emu();
    }

    function run() public {
        bytes memory bytecode = vm.readFileBinary("./c8games/PONG");
        console.logBytes(bytecode);
        uint8[] memory converted_bytes = new uint8[](bytecode.length);
        for (uint256 i = 0; i < bytecode.length;) {
            converted_bytes[i] = uint8(bytecode[i]);
            unchecked {
                ++i;
            }
        }
        emulator.load(converted_bytes);
        emulator.run();
    }
}
