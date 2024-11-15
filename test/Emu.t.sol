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

    // -------------------------------------------------------------------------
    // Instruction tests
    // -------------------------------------------------------------------------

    // Test 1: NOP instruction (0x0000)
    function testExecuteNOP() public {
        // 0x0000: Nothing

        uint8[] memory program = new uint8[](4);
        program[0] = 0x00;
        program[1] = 0x00;
        program[2] = 0x00;
        program[3] = 0x00;

        emulator.load(program);
        emulator.tick();
        emulator.tick();

        assertEq(emulator.getPC(), 0x204, "PC should be advanced by 2 after NOP instruction");
    }

    // Test 2: CLS instruction (0x00E0)
    function testExecuteCLS() public {
        // 0x00E0: Clear the display
        // Set some pixels to true
        emulator.setScreenPixel(0, true);
        emulator.setScreenPixel(1, true);
        emulator.setScreenPixel(2, true);

        uint8[] memory program = new uint8[](2);
        program[0] = 0x00;
        program[1] = 0xE0;

        emulator.load(program);
        emulator.tick();

        // Check that the display is cleared
        bool isCleared = emulator.isDisplayCleared();
        assertTrue(isCleared, "Display should be cleared after CLS instruction");
    }

    // Test 3: RET instruction (0x00EE)
    function testExecuteRET() public {
        // To test RET, we need to simulate a CALL first
        uint8[] memory program = new uint8[](4);
        program[0] = 0x22; // CALL to address 0x202
        program[1] = 0x02;
        program[2] = 0x00; // RET instruction
        program[3] = 0xEE;

        emulator.load(program);
        emulator.tick(); // Execute CALL
        emulator.tick(); // Execute RET

        // PC should return to the address after CALL instruction (0x202)
        uint16 pc = emulator.getPC();
        assertEq(pc, 0x202, "Program counter should return to 0x202 after RET instruction");
    }

    // Test 4: JP_ADDR instruction (0x1nnn)
    function testExecuteJP_ADDR() public {
        // 0x1333: Jump to address 0x333
        uint8[] memory program = new uint8[](2);
        program[0] = 0x13;
        program[1] = 0x33;

        emulator.load(program);
        emulator.tick();

        // PC should be set to 0x333
        uint16 pc = emulator.getPC();
        assertEq(pc, 0x0333, "PC should be set to 0x333 after JP instruction");
    }

    // Test 5: CALL_ADDR instruction (0x2nnn)
    function testExecuteCALL_ADDR() public {
        // 0x2062: Call subroutine at address 0x062
        uint8[] memory program = new uint8[](2);
        program[0] = 0x20;
        program[1] = 0x62;

        emulator.load(program);
        emulator.tick();

        // PC should be set to 0x062
        uint16 pc = emulator.getPC();
        assertEq(pc, 0x0062, "PC should be set to 0x062 after CALL instruction");

        // Stack should contain return address (0x202)
        uint16 sp = emulator.getSP();
        uint16 returnAddress = emulator.getStackValue(sp - 1);
        assertEq(returnAddress, 0x202, "Return address should be 0x202 on the stack");
    }

    // Test 6: SE_VX_NN instruction (0x3xnn)
    function testExecuteSE_VX_NN() public {
        // 0x3ABB: Skip next instruction if VA == 0xBB
        uint8[] memory program = new uint8[](4);
        program[0] = 0x3A;
        program[1] = 0xBB;
        program[2] = 0x00; // Dummy instruction
        program[3] = 0x00;

        emulator.load(program);
        emulator.setVRegister(0xA, 0xBB); // Set VA to 0xBB
        emulator.tick();

        // PC should skip the next instruction
        uint16 pc = emulator.getPC();
        assertEq(pc, 0x204, "PC should be advanced by 4 after SE_VX_NN when equal");
    }

    // Test 7: SNE_VX_NN instruction (0x4xnn)
    function testExecuteSNE_VX_NN() public {
        // 0x4ACC: Skip next instruction if VA != 0xCC
        uint8[] memory program = new uint8[](4);
        program[0] = 0x4A;
        program[1] = 0xCC;
        program[2] = 0x00; // Dummy instruction
        program[3] = 0x00;

        emulator.load(program);
        emulator.setVRegister(0xA, 0xBB); // Set VA to 0xBB
        emulator.tick();

        // PC should skip the next instruction
        uint16 pc = emulator.getPC();
        assertEq(pc, 0x204, "PC should be advanced by 4 after SNE_VX_NN when not equal");
    }

    // Test 8: SE_VX_VY instruction (0x5xy0)
    function testExecuteSE_VX_VY() public {
        // 0x5AB0: Skip next instruction if VA == VB
        uint8[] memory program = new uint8[](4);
        program[0] = 0x5A;
        program[1] = 0xB0;
        program[2] = 0x00; // Dummy instruction
        program[3] = 0x00;

        emulator.load(program);
        emulator.setVRegister(0xA, 0x55); // Set VA to 0x55
        emulator.setVRegister(0xB, 0x55); // Set VB to 0x55
        emulator.tick();

        // PC should skip the next instruction
        uint16 pc = emulator.getPC();
        assertEq(pc, 0x204, "PC should be advanced by 4 after SE_VX_VY when equal");
    }

    // Test 9: LD_VX_NN instruction (0x6xnn)
    function testExecuteLD_VX_NN() public {
        // 0x6ABB: Set VA to 0xBB
        uint8[] memory program = new uint8[](2);
        program[0] = 0x6A;
        program[1] = 0xBB;

        emulator.load(program);
        emulator.tick();

        uint8 va = emulator.getVRegister(0xA);
        assertEq(va, 0xBB, "VA should be set to 0xBB after LD_VX_NN instruction");
    }

    // Test 10: ADD_VX_NN instruction (0x7xnn)
    function testExecuteADD_VX_NN() public {
        // 0x7ABB: Add 0xBB to VA
        uint8[] memory program = new uint8[](2);
        program[0] = 0x7A;
        program[1] = 0xBB;

        emulator.load(program);
        emulator.setVRegister(0xA, 0x10); // Set initial value of VA
        emulator.tick();

        uint8 va = emulator.getVRegister(0xA);
        assertEq(va, 0xCB, "VA should be incremented by 0xBB after ADD_VX_NN instruction");
    }

    // Test 11: LD_VX_VY instruction (0x8xy0)
    function testExecuteLD_VX_VY() public {
        // 0x8AB0: Set VA = VB
        uint8[] memory program = new uint8[](2);
        program[0] = 0x8A;
        program[1] = 0xB0;

        emulator.load(program);
        emulator.setVRegister(0xB, 0x55); // Set VB to 0x55
        emulator.tick();

        uint8 va = emulator.getVRegister(0xA);
        assertEq(va, 0x55, "VA should be set to VB after LD_VX_VY instruction");
    }

    // Test 12: OR_VX_VY instruction (0x8xy1)
    function testExecuteOR_VX_VY() public {
        // 0x8AB1: Set VA = VA | VB
        uint8[] memory program = new uint8[](2);
        program[0] = 0x8A;
        program[1] = 0xB1;

        emulator.load(program);
        emulator.setVRegister(0xA, 0xF0); // VA = 0xF0
        emulator.setVRegister(0xB, 0x0F); // VB = 0x0F
        emulator.tick();

        uint8 va = emulator.getVRegister(0xA);
        assertEq(va, 0xFF, "VA should be set to VA | VB after OR_VX_VY instruction");
    }

    // Test 13: AND_VX_VY instruction (0x8xy2)
    function testExecuteAND_VX_VY() public {
        // 0x8AB2: Set VA = VA & VB
        uint8[] memory program = new uint8[](2);
        program[0] = 0x8A;
        program[1] = 0xB2;

        emulator.load(program);
        emulator.setVRegister(0xA, 0xF0); // VA = 0xF0
        emulator.setVRegister(0xB, 0x0F); // VB = 0x0F
        emulator.tick();

        uint8 va = emulator.getVRegister(0xA);
        assertEq(va, 0x00, "VA should be set to VA & VB after AND_VX_VY instruction");
    }

    // Test 14: XOR_VX_VY instruction (0x8xy3)
    function testExecuteXOR_VX_VY() public {
        // 0x8AB3: Set VA = VA ^ VB
        uint8[] memory program = new uint8[](2);
        program[0] = 0x8A;
        program[1] = 0xB3;

        emulator.load(program);
        emulator.setVRegister(0xA, 0xF0); // VA = 0xF0
        emulator.setVRegister(0xB, 0x0F); // VB = 0x0F
        emulator.tick();

        uint8 va = emulator.getVRegister(0xA);
        assertEq(va, 0xFF, "VA should be set to VA ^ VB after XOR_VX_VY instruction");
    }

    // Test 15: ADD_VX_VY instruction (0x8xy4)
    function testExecuteADD_VX_VY() public {
        // 0x8AB4: Set VA = VA + VB
        uint8[] memory program = new uint8[](2);
        program[0] = 0x8A;
        program[1] = 0xB4;

        emulator.load(program);
        emulator.setVRegister(0xA, 0x10); // VA = 0x10
        emulator.setVRegister(0xB, 0x20); // VB = 0x20
        emulator.tick();

        uint8 va = emulator.getVRegister(0xA);
        assertEq(va, 0x30, "VA should be sum of VA and VB after ADD_VX_VY instruction");

        uint8 vf = emulator.getVRegister(0xF);
        assertEq(vf, 0x00, "VF should be 0 when there's no carry");
    }

    // Test 16: SUB_VX_VY instruction (0x8xy5)
    function testExecuteSUB_VX_VY() public {
        // 0x8AB5: Set VA = VA - VB
        uint8[] memory program = new uint8[](2);
        program[0] = 0x8A;
        program[1] = 0xB5;

        emulator.load(program);
        emulator.setVRegister(0xA, 0x30); // VA = 0x30
        emulator.setVRegister(0xB, 0x10); // VB = 0x10
        emulator.tick();

        uint8 va = emulator.getVRegister(0xA);
        assertEq(va, 0x20, "VA should be VA - VB after SUB_VX_VY instruction");

        uint8 vf = emulator.getVRegister(0xF);
        assertEq(vf, 0x01, "VF should be 1 when there's no borrow");
    }

    // Test 17: SHR_VX_VY instruction (0x8xy6)
    function testExecuteSHR_VX_VY() public {
        // 0x8AB6: Set VA = VA >> 1
        uint8[] memory program = new uint8[](2);
        program[0] = 0x8A;
        program[1] = 0xB6;

        emulator.load(program);
        emulator.setVRegister(0xA, 0x05); // VA = 0x05
        emulator.tick();

        uint8 va = emulator.getVRegister(0xA);
        assertEq(va, 0x02, "VA should be shifted right by 1 after SHR_VX_VY instruction");

        uint8 vf = emulator.getVRegister(0xF);
        assertEq(vf, 0x01, "VF should be 1 if least significant bit was 1");
    }

    // Test 18: SUBN_VX_VY instruction (0x8xy7)
    function testExecuteSUBN_VX_VY() public {
        // 0x8AB7: Set VA = VB - VA
        uint8[] memory program = new uint8[](2);
        program[0] = 0x8A;
        program[1] = 0xB7;

        emulator.load(program);
        emulator.setVRegister(0xA, 0x10); // VA = 0x10
        emulator.setVRegister(0xB, 0x30); // VB = 0x30
        emulator.tick();

        uint8 va = emulator.getVRegister(0xA);
        assertEq(va, 0x20, "VA should be VB - VA after SUBN_VX_VY instruction");

        uint8 vf = emulator.getVRegister(0xF);
        assertEq(vf, 0x01, "VF should be 1 when there's no borrow");
    }

    // Test 19: SHL_VX_VY instruction (0x8xyE)
    function testExecuteSHL_VX_VY() public {
        // 0x8ABE: Set VA = VA << 1
        uint8[] memory program = new uint8[](2);
        program[0] = 0x8A;
        program[1] = 0xBE;

        emulator.load(program);
        emulator.setVRegister(0xA, 0x80); // VA = 0x80
        emulator.tick();

        uint8 va = emulator.getVRegister(0xA);
        assertEq(va, 0x00, "VA should be shifted left by 1 after SHL_VX_VY instruction");

        uint8 vf = emulator.getVRegister(0xF);
        assertEq(vf, 0x01, "VF should be 1 if most significant bit was 1");
    }

    // Test 20: SNE_VX_VY instruction (0x9xy0)
    function testExecuteSNE_VX_VY() public {
        // 0x9AB0: Skip next instruction if VA != VB
        uint8[] memory program = new uint8[](4);
        program[0] = 0x9A;
        program[1] = 0xB0;
        program[2] = 0x00; // Dummy instruction
        program[3] = 0x00;

        emulator.load(program);
        emulator.setVRegister(0xA, 0x10); // VA = 0x10
        emulator.setVRegister(0xB, 0x20); // VB = 0x20
        emulator.tick();

        // PC should skip the next instruction
        uint16 pc = emulator.getPC();
        assertEq(pc, 0x204, "PC should be advanced by 4 after SNE_VX_VY when not equal");
    }

    // Test 21: LD_I_ADDR instruction (0xAnnn)
    function testExecuteLD_I_ADDR() public {
        // 0xA999: Set I = 0x999
        uint8[] memory program = new uint8[](2);
        program[0] = 0xA9;
        program[1] = 0x99;

        emulator.load(program);
        emulator.tick();

        uint16 iRegister = emulator.getIRegister();
        assertEq(iRegister, 0x0999, "I should be set to 0x0999 after LD_I_ADDR instruction");
    }

    // Test 22: JP_V0_ADDR instruction (0xBnnn)
    function testExecuteJP_V0_ADDR() public {
        // 0xB400: Jump to V0 + 0x400
        uint8[] memory program = new uint8[](2);
        program[0] = 0xB4;
        program[1] = 0x00;

        emulator.load(program);
        emulator.setVRegister(0x0, 0x10); // V0 = 0x10
        emulator.tick();

        uint16 pc = emulator.getPC();
        assertEq(pc, 0x410, "PC should be set to V0 + 0x400 after JP_V0_ADDR instruction");
    }

    // Test 23: RND_VX_NN instruction (0xCxnn)
    function testExecuteRND_VX_NN() public {
        // 0xCABB: Set VA = rand() & 0xBB
        uint8[] memory program = new uint8[](2);
        program[0] = 0xCA;
        program[1] = 0xBB;

        emulator.load(program);
        emulator.tick();

        uint8 va = emulator.getVRegister(0xA);
        // Since we cannot predict rand(), we can assert that VA <= 0xBB
        assertTrue(va <= 0xBB, "VA should be less than or equal to 0xBB after RND_VX_NN instruction");
    }

    // Test 24: DRW_VX_VY_N instruction (0xDxyn)
    function testExecuteDRW_VX_VY_N() public {
        // 0xDAB9: Draw sprite at (VA, VB) with height 9
        uint8[] memory program = new uint8[](2);
        program[0] = 0xDA;
        program[1] = 0xB9;

        // Prepare sprite data in memory at I
        uint16 i_address = 0x300;
        uint8[9] memory sprite = [0xFF, 0x81, 0xBD, 0xA5, 0xA5, 0xBD, 0x81, 0xFF, 0x00];
        for (uint8 i = 0; i < 9; i++) {
            emulator.setRAMValueAt(i_address + i, sprite[i]);
        }

        emulator.setIRegister(i_address);
        emulator.setVRegister(0xA, 10); // VA = 10 (x coordinate)
        emulator.setVRegister(0xB, 5); // VB = 5 (y coordinate)

        emulator.load(program);
        emulator.tick();

        // Check that VF is set correctly (no collision on clear screen)
        uint8 vf = emulator.getVRegister(0xF);
        assertEq(vf, 0x00, "VF should be 0 after drawing sprite with no collision");
    }

    // Test 25: SKP_VX instruction (0xEx9E)
    function testExecuteSKP_VX() public {
        // 0xEA9E: Skip next instruction if key in VA is pressed
        uint8[] memory program = new uint8[](4);
        program[0] = 0xEA;
        program[1] = 0x9E;
        program[2] = 0x00; // Dummy instruction to be skipped
        program[3] = 0x00;

        emulator.load(program);
        emulator.setVRegister(0xA, 0x05); // VA = 0x05
        emulator.keypress(0x05, true); // Simulate key 5 being pressed

        emulator.tick();

        // PC should skip the next instruction
        uint16 pc = emulator.getPC();
        assertEq(pc, 0x204, "PC should be advanced by 4 after SKP_VX when key is pressed");
    }

    // Test 26: SKNP_VX instruction (0xExA1)
    function testExecuteSKNP_VX() public {
        // 0xEBA1: Skip next instruction if key in VB is not pressed
        uint8[] memory program = new uint8[](4);
        program[0] = 0xEB;
        program[1] = 0xA1;
        program[2] = 0x00; // Dummy instruction to be skipped
        program[3] = 0x00;

        emulator.load(program);
        emulator.setVRegister(0xB, 0x05); // VB = 0x05
        // Do not press any key

        emulator.tick();

        // PC should skip the next instruction
        uint16 pc = emulator.getPC();
        assertEq(pc, 0x204, "PC should be advanced by 4 after SKNP_VX when key is not pressed");
    }

    // Test 27: LD_VX_DT instruction (0xFx07)
    function testExecuteLD_VX_DT() public {
        // 0xFA07: Set VA = DT
        uint8[] memory program = new uint8[](2);
        program[0] = 0xFA;
        program[1] = 0x07;

        emulator.load(program);
        emulator.setDelayTimer(0x55); // Set DT to 0x55
        emulator.tick();

        uint8 va = emulator.getVRegister(0xA);
        assertEq(va, 0x55, "VA should be set to delay timer value after LD_VX_DT instruction");
    }

    // Test 28: LD_VX_K instruction (0xFx0A)
    function testExecuteLD_VX_K() public {
        // 0xFB0A: Wait for key press, store in VB
        uint8[] memory program = new uint8[](2);
        program[0] = 0xFB;
        program[1] = 0x0A;

        emulator.load(program);

        // No key pressed, tick once
        emulator.tick();
        // PC should not advance
        uint16 pc = emulator.getPC();
        assertEq(pc, 0x200, "PC should not advance when no key is pressed");

        // Press a key
        emulator.keypress(0x05, true);
        emulator.tick();

        // PC should now advance
        pc = emulator.getPC();
        assertEq(pc, 0x202, "PC should advance after key is pressed");

        uint8 vb = emulator.getVRegister(0xB);
        assertEq(vb, 0x05, "VB should be set to key value after LD_VX_K instruction");
    }

    // Test 29: LD_DT_VX instruction (0xFx15)
    function testExecuteLD_DT_VX() public {
        // 0xFB15: Set DT = VB
        uint8[] memory program = new uint8[](2);
        program[0] = 0xFB;
        program[1] = 0x15;

        emulator.load(program);
        emulator.setVRegister(0xB, 0x55); // VB = 0x55
        emulator.tick();

        uint8 dt = emulator.getDelayTimer();
        assertEq(dt, 0x55, "Delay timer should be set to VB after LD_DT_VX instruction");
    }

    // Test 30: LD_ST_VX instruction (0xFx18)
    function testExecuteLD_ST_VX() public {
        // 0xFA18: Set ST = VA
        uint8[] memory program = new uint8[](2);
        program[0] = 0xFA;
        program[1] = 0x18;

        emulator.load(program);
        emulator.setVRegister(0xA, 0x33); // VA = 0x33
        emulator.tick();

        uint8 st = emulator.getSoundTimer();
        assertEq(st, 0x33, "Sound timer should be set to VA after LD_ST_VX instruction");
    }

    // Test 31: ADD_I_VX instruction (0xFx1E)
    function testExecuteADD_I_VX() public {
        // 0xFA1E: Set I = I + VA
        uint8[] memory program = new uint8[](2);
        program[0] = 0xFA;
        program[1] = 0x1E;

        emulator.load(program);
        emulator.setIRegister(0x100); // I = 0x100
        emulator.setVRegister(0xA, 0x10); // VA = 0x10
        emulator.tick();

        uint16 i_reg = emulator.getIRegister();
        assertEq(i_reg, 0x110, "I register should be I + VA after ADD_I_VX instruction");
    }

    // Test 32: LD_F_VX instruction (0xFx29)
    function testExecuteLD_F_VX() public {
        // 0xFA29: Set I = location of sprite for digit VA
        uint8[] memory program = new uint8[](2);
        program[0] = 0xFA;
        program[1] = 0x29;

        emulator.load(program);
        emulator.setVRegister(0xA, 0x05); // VA = 0x05
        emulator.tick();

        uint16 i_reg = emulator.getIRegister();
        assertEq(i_reg, 0x0019, "I register should be set to sprite location for digit VA after LD_F_VX instruction");
    }

    // Test 33: LD_B_VX instruction (0xFx33)
    function testExecuteLD_B_VX() public {
        // 0xFA33: Store BCD of VA at I, I+1, I+2
        uint8[] memory program = new uint8[](2);
        program[0] = 0xFA;
        program[1] = 0x33;

        emulator.load(program);
        emulator.setVRegister(0xA, 123); // VA = 123
        emulator.setIRegister(0x300); // I = 0x300
        emulator.tick();

        uint8 hundreds = emulator.getRAMValueAt(0x300);
        uint8 tens = emulator.getRAMValueAt(0x301);
        uint8 ones = emulator.getRAMValueAt(0x302);

        assertEq(hundreds, 1, "Hundreds digit should be 1");
        assertEq(tens, 2, "Tens digit should be 2");
        assertEq(ones, 3, "Ones digit should be 3");
    }

    // Test 34: LD_I_VX instruction (0xFx55)
    function testExecuteLD_I_VX() public {
        // 0xFA55: Store V0 through VA in memory starting at I
        uint8[] memory program = new uint8[](2);
        program[0] = 0xFA;
        program[1] = 0x55;

        emulator.load(program);
        emulator.setIRegister(0x300); // I = 0x300

        // Set V0 through VA to known values
        for (uint8 i = 0; i <= 0xA; i++) {
            emulator.setVRegister(i, i + 1); // V0=1, V1=2, ..., VA=11
        }

        emulator.tick();

        // Check memory from I to I+VA
        for (uint8 i = 0; i <= 0xA; i++) {
            uint8 value = emulator.getRAMValueAt(0x300 + i);
            assertEq(value, i + 1, "Memory should contain value of V registers");
        }
    }

    // Test 35: LD_VX_I instruction (0xFx65)
    function testExecuteLD_VX_I() public {
        // 0xFA65: Read V0 through VA from memory starting at I
        uint8[] memory program = new uint8[](2);
        program[0] = 0xFA;
        program[1] = 0x65;

        emulator.load(program);
        emulator.setIRegister(0x300); // I = 0x300

        // Set memory at I onwards to known values
        for (uint8 i = 0; i <= 0xA; i++) {
            emulator.setRAMValueAt(0x300 + i, i + 1); // Mem[I]=1, Mem[I+1]=2, ..., Mem[I+10]=11
        }

        emulator.tick();

        // Check V0 through VA
        for (uint8 i = 0; i <= 0xA; i++) {
            uint8 value = emulator.getVRegister(i);
            assertEq(value, i + 1, "V registers should contain values from memory");
        }
    }

    // Test 36: All other opcodes should revert with "Opcode not implemented"
    function testExecuteUnknownOpcode() public {
        // 0x5154: Unknown opcode
        uint8[] memory program = new uint8[](2);
        program[0] = 0x51;
        program[1] = 0x54;

        emulator.load(program);

        vm.expectRevert(bytes("Opcode not implemented"));
        emulator.tick();
    }

    // // -------------------------------------------------------------------------
    // // Program tests
    // // -------------------------------------------------------------------------

    // function testSimpleProgram() public {
    //     uint8[] memory program = new uint8[](17);
    //     // 00E0 - CLS
    //     program[0] = 0x00;
    //     program[1] = 0xE0;
    //     // 6000 - LD V0, 0x00
    //     program[2] = 0x60;
    //     program[3] = 0x00;
    //     // 6100 - LD V1, 0x00
    //     program[4] = 0x61;
    //     program[5] = 0x00;
    //     // A20C - LD I, 0x20C
    //     program[6] = 0xA2;
    //     program[7] = 0x0C;
    //     // D015 - DRW V0, V1, 5
    //     program[8] = 0xD0;
    //     program[9] = 0x15;
    //     // 120A - JP 0x20A
    //     program[10] = 0x12;
    //     program[11] = 0x0A;

    //     program[12] = 0xF0;
    //     program[13] = 0x90;
    //     program[14] = 0xF0;
    //     program[15] = 0x90;
    //     program[16] = 0x90;

    //     emulator.load(program);
    //     for (uint256 i = 0; i < 10; i++) {
    //         emulator.tick();
    //     }

    //     bool[64 * 32] memory display = emulator.getDisplay();

    //     // Expected pattern:
    //     // Row 0: 1 1 1 1 0 0 0 0 (0xF0)
    //     // Row 1: 1 0 0 1 0 0 0 0 (0x90)
    //     // Row 2: 1 1 1 1 0 0 0 0 (0xF0)
    //     // Row 3: 1 0 0 1 0 0 0 0 (0x90)
    //     // Row 4: 1 0 0 1 0 0 0 0 (0x90)

    //     // Starting coordinates (V0, V1)
    //     uint8 xPos = emulator.getVRegister(0);
    //     uint8 yPos = emulator.getVRegister(1);
    //     assertEq(xPos, 0, "Should be 0");
    //     assertEq(yPos, 0, "Should be 0");

    //     uint8[5] memory pixelData = [program[12], program[13], program[14], program[15], program[16]];

    //     // Iterate over each row of the pixel
    //     for (uint8 row = 0; row < 5; row++) {
    //         uint8 pixelByte = pixelData[row];
    //         // Iterate over each column (bit) in the pixel row
    //         for (uint8 col = 0; col < 8; col++) {
    //             // Extract the bit at position (7 - col)
    //             bool pixelShouldBeSet = (pixelByte & (0x80 >> col)) != 0;

    //             // Calculate the display index
    //             uint8 x = xPos + col;
    //             uint8 y = yPos + row;
    //             // Ensure coordinates wrap around if they exceed the screen dimensions
    //             x = x % 64;
    //             y = y % 32;

    //             uint256 index = uint256(y) * 64 + uint256(x);
    //             console.log("Index: %s", index);

    //             // Assert that the display pixel matches the expected value
    //             assertEq(display[index], pixelShouldBeSet, "Pixel should be set");
    //         }
    //     }
    // }

    // function testRunSimpleProgram() public {
    //     uint8[] memory program = new uint8[](17);
    //     // 00E0 - CLS
    //     program[0] = 0x00;
    //     program[1] = 0xE0;
    //     // 6000 - LD V0, 0x00
    //     program[2] = 0x60;
    //     program[3] = 0x00;
    //     // 6100 - LD V1, 0x00
    //     program[4] = 0x61;
    //     program[5] = 0x00;
    //     // A20C - LD I, 0x20C
    //     program[6] = 0xA2;
    //     program[7] = 0x0C;
    //     // D015 - DRW V0, V1, 5
    //     program[8] = 0xD0;
    //     program[9] = 0x15;
    //     // 120A - JP 0x20A
    //     program[10] = 0x12;
    //     program[11] = 0x0A;

    //     program[12] = 0xF0;
    //     program[13] = 0x90;
    //     program[14] = 0xF0;
    //     program[15] = 0x90;
    //     program[16] = 0x90;

    //     emulator.load(program);
    //     emulator.run();

    //     bool[64 * 32] memory display = emulator.getDisplay();

    //     // Expected pattern:
    //     // Row 0: 1 1 1 1 0 0 0 0 (0xF0)
    //     // Row 1: 1 0 0 1 0 0 0 0 (0x90)
    //     // Row 2: 1 1 1 1 0 0 0 0 (0xF0)
    //     // Row 3: 1 0 0 1 0 0 0 0 (0x90)
    //     // Row 4: 1 0 0 1 0 0 0 0 (0x90)

    //     // Starting coordinates (V0, V1)
    //     uint8 xPos = emulator.getVRegister(0);
    //     uint8 yPos = emulator.getVRegister(1);
    //     assertEq(xPos, 0, "Should be 0");
    //     assertEq(yPos, 0, "Should be 0");

    //     uint8[5] memory pixelData = [program[12], program[13], program[14], program[15], program[16]];

    //     // Iterate over each row of the pixel
    //     for (uint8 row = 0; row < 5; row++) {
    //         uint8 pixelByte = pixelData[row];
    //         // Iterate over each column (bit) in the pixel row
    //         for (uint8 col = 0; col < 8; col++) {
    //             // Extract the bit at position (7 - col)
    //             bool pixelShouldBeSet = (pixelByte & (0x80 >> col)) != 0;

    //             // Calculate the display index
    //             uint8 x = xPos + col;
    //             uint8 y = yPos + row;
    //             // Ensure coordinates wrap around if they exceed the screen dimensions
    //             x = x % 64;
    //             y = y % 32;

    //             uint256 index = uint256(y) * 64 + uint256(x);
    //             console.log("Index: %s", index);

    //             // Assert that the display pixel matches the expected value
    //             assertEq(display[index], pixelShouldBeSet, "Pixel should be set");
    //         }
    //     }
    // }
}
