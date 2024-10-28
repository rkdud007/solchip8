// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Test, console} from "forge-std/Test.sol";
import {Emu} from "../src/Emu.sol";

contract EmuTest is Test {
    Emu public emulator;

    function setUp() public {
        emulator = new Emu();
    }

    function testReset() public {
        emulator.tick();
        emulator.reset();

        // pc == START_ADDR
        uint16 pc = emulator.getPC();
        assertEq(pc, 0x200, "Program counter should be reset to START_ADDR (0x200)");
    }

    function testExecuteSetVx() public {
        // 0x61BB: Set V1 to 0xBB
        uint8[] memory program = new uint8[](2);
        program[0] = 0x61;
        program[1] = 0xBB;

        emulator.load(program);
        emulator.tick();

        // V1 == 0xBB
        uint8 v1 = emulator.getVRegister(1);
        assertEq(v1, 0xBB, "V1 should be set to 0xBB");
    }

    function testCallAndReturn() public {
        // 0x2210: CALL 0x210
        uint8[] memory program = new uint8[](18);
        program[0] = 0x22;
        program[1] = 0x10;

        // At address 0x210 (offset 16), 0x00EE: RET
        program[16] = 0x00;
        program[17] = 0xEE;

        emulator.load(program);
        emulator.tick();
        uint16 pc = emulator.getPC();
        assertEq(pc, 0x210, "Program counter should be at 0x210 after CALL");

        // RET
        emulator.tick();
        pc = emulator.getPC();
        assertEq(pc, 0x202, "Program counter should return to 0x202 after RET");
    }

    function testSimpleProgram() public {
        uint8[] memory program = new uint8[](17);
        // 00E0 - CLS
        program[0] = 0x00;
        program[1] = 0xE0;
        // 6000 - LD V0, 0x00
        program[2] = 0x60;
        program[3] = 0x00;
        // 6100 - LD V1, 0x00
        program[4] = 0x61;
        program[5] = 0x00;
        // A20C - LD I, 0x20C
        program[6] = 0xA2;
        program[7] = 0x0C;
        // D015 - DRW V0, V1, 5
        program[8] = 0xD0;
        program[9] = 0x15;
        // 120A - JP 0x20A
        program[10] = 0x12;
        program[11] = 0x0A;

        program[12] = 0xF0;
        program[13] = 0x90;
        program[14] = 0xF0;
        program[15] = 0x90;
        program[16] = 0x90;

        emulator.load(program);
        for (uint256 i = 0; i < 10; i++) {
            emulator.tick();
        }

        bool[64 * 32] memory display = emulator.getDisplay();

        // Expected pattern:
        // Row 0: 1 1 1 1 0 0 0 0 (0xF0)
        // Row 1: 1 0 0 1 0 0 0 0 (0x90)
        // Row 2: 1 1 1 1 0 0 0 0 (0xF0)
        // Row 3: 1 0 0 1 0 0 0 0 (0x90)
        // Row 4: 1 0 0 1 0 0 0 0 (0x90)

        // Starting coordinates (V0, V1)
        uint8 xPos = emulator.getVRegister(0);
        uint8 yPos = emulator.getVRegister(1);
        assertEq(xPos, 0, "Should be 0");
        assertEq(yPos, 0, "Should be 0");

        uint8[5] memory pixelData = [program[12], program[13], program[14], program[15], program[16]];

        // Iterate over each row of the pixel
        for (uint8 row = 0; row < 5; row++) {
            uint8 pixelByte = pixelData[row];
            // Iterate over each column (bit) in the pixel row
            for (uint8 col = 0; col < 8; col++) {
                // Extract the bit at position (7 - col)
                bool pixelShouldBeSet = (pixelByte & (0x80 >> col)) != 0;

                // Calculate the display index
                uint8 x = xPos + col;
                uint8 y = yPos + row;
                // Ensure coordinates wrap around if they exceed the screen dimensions
                x = x % 64;
                y = y % 32;

                uint256 index = uint256(y) * 64 + uint256(x);
                console.log("Index: %s", index);

                // Assert that the display pixel matches the expected value
                assertEq(display[index], pixelShouldBeSet, "Pixel should be set");
            }
        }
    }

    function testRunSimpleProgram() public {
        uint8[] memory program = new uint8[](17);
        // 00E0 - CLS
        program[0] = 0x00;
        program[1] = 0xE0;
        // 6000 - LD V0, 0x00
        program[2] = 0x60;
        program[3] = 0x00;
        // 6100 - LD V1, 0x00
        program[4] = 0x61;
        program[5] = 0x00;
        // A20C - LD I, 0x20C
        program[6] = 0xA2;
        program[7] = 0x0C;
        // D015 - DRW V0, V1, 5
        program[8] = 0xD0;
        program[9] = 0x15;
        // 120A - JP 0x20A
        program[10] = 0x12;
        program[11] = 0x0A;

        program[12] = 0xF0;
        program[13] = 0x90;
        program[14] = 0xF0;
        program[15] = 0x90;
        program[16] = 0x90;

        emulator.load(program);
        emulator.run();

        bool[64 * 32] memory display = emulator.getDisplay();

        // Expected pattern:
        // Row 0: 1 1 1 1 0 0 0 0 (0xF0)
        // Row 1: 1 0 0 1 0 0 0 0 (0x90)
        // Row 2: 1 1 1 1 0 0 0 0 (0xF0)
        // Row 3: 1 0 0 1 0 0 0 0 (0x90)
        // Row 4: 1 0 0 1 0 0 0 0 (0x90)

        // Starting coordinates (V0, V1)
        uint8 xPos = emulator.getVRegister(0);
        uint8 yPos = emulator.getVRegister(1);
        assertEq(xPos, 0, "Should be 0");
        assertEq(yPos, 0, "Should be 0");

        uint8[5] memory pixelData = [program[12], program[13], program[14], program[15], program[16]];

        // Iterate over each row of the pixel
        for (uint8 row = 0; row < 5; row++) {
            uint8 pixelByte = pixelData[row];
            // Iterate over each column (bit) in the pixel row
            for (uint8 col = 0; col < 8; col++) {
                // Extract the bit at position (7 - col)
                bool pixelShouldBeSet = (pixelByte & (0x80 >> col)) != 0;

                // Calculate the display index
                uint8 x = xPos + col;
                uint8 y = yPos + row;
                // Ensure coordinates wrap around if they exceed the screen dimensions
                x = x % 64;
                y = y % 32;

                uint256 index = uint256(y) * 64 + uint256(x);
                console.log("Index: %s", index);

                // Assert that the display pixel matches the expected value
                assertEq(display[index], pixelShouldBeSet, "Pixel should be set");
            }
        }
    }
}
