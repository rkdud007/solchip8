// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {Emu} from "../src/Emu.sol";

contract EmulatorScript is Script {
    Emu public emulator;
}
