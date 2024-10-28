// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Emu} from "../src/Emu.sol";

contract EmulatorScript is Script {
    Emu public emulator;
}
