// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

contract Emu {
    uint256 constant SCREEN_WIDTH = 64;
    uint256 constant SCREEN_HEIGHT = 32;

    uint16 constant START_ADDR = 0x200;
    uint256 constant RAM_SIZE = 4096;
    uint256 constant NUM_REGS = 16;
    uint256 constant STACK_SIZE = 16;
    uint256 constant NUM_KEYS = 16;
    uint256 constant FONTSET_SIZE = 80;

    uint8[FONTSET_SIZE] FONTSET = [
        0xF0,
        0x90,
        0x90,
        0x90,
        0xF0, // 0
        0x20,
        0x60,
        0x20,
        0x20,
        0x70, // 1
        0xF0,
        0x10,
        0xF0,
        0x80,
        0xF0, // 2
        0xF0,
        0x10,
        0xF0,
        0x10,
        0xF0, // 3
        0x90,
        0x90,
        0xF0,
        0x10,
        0x10, // 4
        0xF0,
        0x80,
        0xF0,
        0x10,
        0xF0, // 5
        0xF0,
        0x80,
        0xF0,
        0x90,
        0xF0, // 6
        0xF0,
        0x10,
        0x20,
        0x40,
        0x40, // 7
        0xF0,
        0x90,
        0xF0,
        0x90,
        0xF0, // 8
        0xF0,
        0x90,
        0xF0,
        0x10,
        0xF0, // 9
        0xF0,
        0x90,
        0xF0,
        0x90,
        0x90, // A
        0xE0,
        0x90,
        0xE0,
        0x90,
        0xE0, // B
        0xF0,
        0x80,
        0x80,
        0x80,
        0xF0, // C
        0xE0,
        0x90,
        0x90,
        0x90,
        0xE0, // D
        0xF0,
        0x80,
        0xF0,
        0x80,
        0xF0, // E
        0xF0,
        0x80,
        0xF0,
        0x80,
        0x80 // F
    ];

    struct Emulator {
        uint16 pc;
        uint8[RAM_SIZE] ram;
        bool[SCREEN_WIDTH * SCREEN_HEIGHT] screen;
        uint8[NUM_REGS] v_reg;
        uint16 i_reg;
        uint16 sp;
        uint16[STACK_SIZE] stack;
        bool[NUM_KEYS] keys;
        uint8 dt;
        uint8 st;
        uint256 program_size;
    }

    Emulator emu;

    constructor() {
        emu.pc = START_ADDR;
        for (uint256 i = 0; i < FONTSET_SIZE; i++) {
            emu.ram[i] = FONTSET[i];
        }
    }

    function reset() public {
        emu.pc = START_ADDR;
        for (uint256 i = 0; i < SCREEN_WIDTH * SCREEN_HEIGHT; i++) {
            emu.screen[i] = false;
        }
        for (uint256 i = 0; i < NUM_REGS; i++) {
            emu.v_reg[i] = 0;
        }
        emu.i_reg = 0;
        emu.sp = 0;
        for (uint256 i = 0; i < STACK_SIZE; i++) {
            emu.stack[i] = 0;
        }
        for (uint256 i = 0; i < NUM_KEYS; i++) {
            emu.keys[i] = false;
        }
        emu.dt = 0;
        emu.st = 0;
        // Copy FONTSET
        for (uint256 i = 0; i < FONTSET_SIZE; i++) {
            emu.ram[i] = FONTSET[i];
        }
    }

    function push(uint16 val) internal {
        require(emu.sp < STACK_SIZE, "Stack overflow");
        emu.stack[emu.sp] = val;
        emu.sp += 1;
    }

    function pop() internal returns (uint16) {
        require(emu.sp > 0, "Stack underflow");
        emu.sp -= 1;
        return emu.stack[emu.sp];
    }

    function tick() public {
        // Fetch
        uint16 op = fetch();
        // Decode & execute
        execute(op);
    }

    function getDisplay() public view returns (bool[SCREEN_WIDTH * SCREEN_HEIGHT] memory) {
        return emu.screen;
    }

    function keypress(uint256 idx, bool pressed) public {
        require(idx < NUM_KEYS, "Invalid key index");
        emu.keys[idx] = pressed;
    }

    function load(uint8[] memory data) public {
        uint256 start = START_ADDR;
        uint256 end = START_ADDR + data.length;
        require(end <= RAM_SIZE, "Data too large to fit in RAM");
        for (uint256 i = start; i < end; i++) {
            emu.ram[i] = data[i - start];
        }
        emu.program_size = data.length;
    }

    function tickTimers() public {
        if (emu.dt > 0) {
            emu.dt -= 1;
        }

        if (emu.st > 0) {
            if (emu.st == 1) {
                // BEEP
            }
            emu.st -= 1;
        }
    }

    function fetch() public returns (uint16) {
        require(emu.pc + 1 < RAM_SIZE, "Program counter out of bounds");
        uint16 higher_byte = uint16(emu.ram[emu.pc]);
        uint16 lower_byte = uint16(emu.ram[emu.pc + 1]);
        uint16 op = (higher_byte << 8) | lower_byte;
        emu.pc += 2;
        return op;
    }

    function run() public {
        require(emu.program_size > 0, "Program size is 0");
        for (uint256 i = 0; i < emu.program_size; i++) {
            require(emu.pc < RAM_SIZE - 1, "Program counter out of bounds");
            // Fetch the opcode
            uint16 op = fetch();
            // Execute the opcode
            execute(op);
        }
    }

    function execute(uint16 op) internal {
        // 0000 - Nop - NOP
        if (op == 0x0000) return;

        uint8 digit1 = uint8((op & 0xF000) >> 12);
        uint8 digit2 = uint8((op & 0x0F00) >> 8);
        uint8 digit3 = uint8((op & 0x00F0) >> 4);
        uint8 digit4 = uint8(op & 0x000F);

        //  00E0 - CLS
        if (digit1 == 0x0 && digit2 == 0x0 && digit3 == 0xE && digit4 == 0) {
            for (uint256 i = 0; i < SCREEN_WIDTH * SCREEN_HEIGHT; i++) {
                emu.screen[i] = false;
            }
            return;
        }
        // 00EE - RET
        else if (digit1 == 0x0 && digit2 == 0x0 && digit3 == 0xE && digit4 == 0xE) {
            emu.pc = pop();
            return;
        }
        //  1NNN - JMP NNN
        else if (digit1 == 0x1) {
            uint16 nnn = op & 0x0FFF;
            emu.pc = nnn;
            return;
        }
        //  2NNN - CALL NNN
        else if (digit1 == 0x2) {
            uint16 nnn = op & 0x0FFF;
            push(emu.pc);
            emu.pc = nnn;
            return;
        }
        //  3NNN - SKIP VX == NN
        else if (digit1 == 0x3) {
            uint8 nn = uint8(op & 0xFF);
            if (emu.v_reg[digit2] == nn) {
                emu.pc += 2;
            }
            return;
        }
        //  4NNN - SKIP VX != NN
        else if (digit1 == 0x4) {
            uint8 nn = uint8(op & 0xFF);
            if (emu.v_reg[digit2] != nn) {
                emu.pc += 2;
            }
            return;
        }
        //  5NNN - SKIP VX == VY
        else if (digit1 == 0x5 && digit4 == 0x0) {
            if (emu.v_reg[digit2] == emu.v_reg[digit3]) {
                emu.pc += 2;
            }
            return;
        }
        //  6NNN - VX = NN
        else if (digit1 == 0x6) {
            uint8 nn = uint8(op & 0xFF);
            emu.v_reg[digit2] = nn;
            return;
        }
        //  7NNN - VX += NN
        else if (digit1 == 0x7) {
            uint8 nn = uint8(op & 0xFF);
            emu.v_reg[digit2] += nn;
            return;
        }
        // 8XY0 - VX = VY
        else if (digit1 == 0x8 && digit4 == 0x0) {
            emu.v_reg[digit2] = emu.v_reg[digit3];
            return;
        }
        // 8XY1 - VX |= VY
        else if (digit1 == 0x8 && digit4 == 0x1) {
            emu.v_reg[digit2] |= emu.v_reg[digit3];
            return;
        }
        // 8XY2 - VX &= VY
        else if (digit1 == 0x8 && digit4 == 0x2) {
            emu.v_reg[digit2] &= emu.v_reg[digit3];
            return;
        }
        // 8XY3 - VX ^= VY
        else if (digit1 == 0x8 && digit4 == 0x3) {
            emu.v_reg[digit2] ^= emu.v_reg[digit3];
            return;
        }
        // 8XY4 - VX += VY (with carry)
        else if (digit1 == 0x8 && digit4 == 0x4) {
            uint8 x = digit2;
            uint8 y = digit3;
            uint16 sum = uint16(emu.v_reg[x]) + uint16(emu.v_reg[y]);
            emu.v_reg[0xF] = sum > 0xFF ? 1 : 0;
            emu.v_reg[x] = uint8(sum);
            return;
        }
        // 8XY5 - VX -= VY (with borrow)
        else if (digit1 == 0x8 && digit4 == 0x5) {
            uint8 x = digit2;
            uint8 y = digit3;
            emu.v_reg[0xF] = emu.v_reg[x] >= emu.v_reg[y] ? 1 : 0;
            unchecked {
                emu.v_reg[x] -= emu.v_reg[y];
            }
            return;
        }
        // 8XY6 - VX >>= 1
        else if (digit1 == 0x8 && digit4 == 0x6) {
            uint8 x = digit2;
            emu.v_reg[0xF] = emu.v_reg[x] & 0x1;
            emu.v_reg[x] >>= 1;
            return;
        }
        // 8XY7 - VX = VY - VX (with borrow)
        else if (digit1 == 0x8 && digit4 == 0x7) {
            uint8 x = digit2;
            uint8 y = digit3;
            emu.v_reg[0xF] = emu.v_reg[y] >= emu.v_reg[x] ? 1 : 0;
            unchecked {
                emu.v_reg[x] = emu.v_reg[y] - emu.v_reg[x];
            }
            return;
        }
        // 8XYE - VX <<= 1
        else if (digit1 == 0x8 && digit4 == 0xE) {
            uint8 x = digit2;
            emu.v_reg[0xF] = (emu.v_reg[x] >> 7) & 0x1;
            emu.v_reg[x] <<= 1;
            return;
        }
        // 9XY0 - SKIP VX != VY
        else if (digit1 == 0x9 && digit4 == 0x0) {
            uint8 x = digit2;
            uint8 y = digit3;
            if (emu.v_reg[x] != emu.v_reg[y]) {
                emu.pc += 2;
            }
            return;
        }
        // ANNN - I = NNN
        else if (digit1 == 0xA) {
            uint16 nnn = op & 0x0FFF;
            emu.i_reg = nnn;
            return;
        }
        // BNNN - PC = V0 + NNN
        else if (digit1 == 0xB) {
            uint16 nnn = op & 0x0FFF;
            emu.pc = uint16(emu.v_reg[0]) + nnn;
            return;
        }
        // CXNN - VX = rand() & NN
        else if (digit1 == 0xC) {
            uint8 x = digit2;
            uint8 nn = uint8(op & 0x00FF);
            // Pseudo-random number generation (not secure)
            uint8 rand =
                uint8(uint256(keccak256(abi.encodePacked(block.timestamp, blockhash(block.number - 1), emu.pc))) % 256);
            emu.v_reg[x] = rand & nn;
            return;
        }
        // DXYN - DRAW
        else if (digit1 == 0xD) {
            uint8 x = emu.v_reg[digit2] % uint8(SCREEN_WIDTH);
            uint8 y = emu.v_reg[digit3] % uint8(SCREEN_HEIGHT);
            uint8 height = digit4;
            emu.v_reg[0xF] = 0; // Reset VF

            for (uint8 row = 0; row < height; row++) {
                uint8 sprite_byte = emu.ram[emu.i_reg + row];
                for (uint8 col = 0; col < 8; col++) {
                    uint8 sprite_pixel = (sprite_byte >> (7 - col)) & 0x1;
                    uint32 screen_x = uint32((x + col) % SCREEN_WIDTH);
                    uint32 screen_y = uint32((y + row) % SCREEN_HEIGHT);
                    uint256 index = screen_y * SCREEN_WIDTH + screen_x;

                    bool pixel_before = emu.screen[index];
                    bool new_pixel = pixel_before != (sprite_pixel == 1);
                    if (pixel_before && !new_pixel) {
                        emu.v_reg[0xF] = 1;
                    }
                    emu.screen[index] = new_pixel;
                }
            }
            return;
        }
        // EX9E - SKIP if key[VX] pressed
        else if (digit1 == 0xE && digit3 == 0x9 && digit4 == 0xE) {
            uint8 x = digit2;
            uint8 key = emu.v_reg[x];
            require(key < NUM_KEYS, "Invalid key");
            if (emu.keys[key]) {
                emu.pc += 2;
            }
            return;
        }
        // EXA1 - SKIP if key[VX] not pressed
        else if (digit1 == 0xE && digit3 == 0xA && digit4 == 0x1) {
            uint8 x = digit2;
            uint8 key = emu.v_reg[x];
            require(key < NUM_KEYS, "Invalid key");
            if (!emu.keys[key]) {
                emu.pc += 2;
            }
            return;
        }
        // FX07 - VX = DT
        else if (digit1 == 0xF && digit3 == 0x0 && digit4 == 0x7) {
            uint8 x = digit2;
            emu.v_reg[x] = emu.dt;
            return;
        }
        // FX0A - Wait for key press
        else if (digit1 == 0xF && digit3 == 0x0 && digit4 == 0xA) {
            uint8 x = digit2;
            bool key_pressed = false;
            for (uint8 i = 0; i < NUM_KEYS; i++) {
                if (emu.keys[i]) {
                    emu.v_reg[x] = i;
                    key_pressed = true;
                    break;
                }
            }
            if (!key_pressed) {
                // Repeat this opcode
                emu.pc -= 2;
            }
            return;
        }
        // FX15 - DT = VX
        else if (digit1 == 0xF && digit3 == 0x1 && digit4 == 0x5) {
            uint8 x = digit2;
            emu.dt = emu.v_reg[x];
            return;
        }
        // FX18 - ST = VX
        else if (digit1 == 0xF && digit3 == 0x1 && digit4 == 0x8) {
            uint8 x = digit2;
            emu.st = emu.v_reg[x];
            return;
        }
        // FX1E - I += VX
        else if (digit1 == 0xF && digit3 == 0x1 && digit4 == 0xE) {
            uint8 x = digit2;
            emu.i_reg += uint16(emu.v_reg[x]);
            return;
        }
        // FX29 - I = location of sprite for digit VX
        else if (digit1 == 0xF && digit3 == 0x2 && digit4 == 0x9) {
            uint8 x = digit2;
            uint8 digit = emu.v_reg[x];
            emu.i_reg = uint16(digit) * 5; // Each sprite is 5 bytes
            return;
        }
        // FX33 - Store BCD representation of VX in memory locations I, I+1, and I+2
        else if (digit1 == 0xF && digit3 == 0x3 && digit4 == 0x3) {
            uint8 x = digit2;
            uint8 value = emu.v_reg[x];
            emu.ram[emu.i_reg] = value / 100;
            emu.ram[emu.i_reg + 1] = (value / 10) % 10;
            emu.ram[emu.i_reg + 2] = value % 10;
            return;
        }
        // FX55 - Store V0 to VX in memory starting at address I
        else if (digit1 == 0xF && digit3 == 0x5 && digit4 == 0x5) {
            uint8 x = digit2;
            for (uint8 i = 0; i <= x; i++) {
                emu.ram[emu.i_reg + i] = emu.v_reg[i];
            }
            return;
        }
        // FX65 - Read V0 to VX from memory starting at address I
        else if (digit1 == 0xF && digit3 == 0x6 && digit4 == 0x5) {
            uint8 x = digit2;
            for (uint8 i = 0; i <= x; i++) {
                emu.v_reg[i] = emu.ram[emu.i_reg + i];
            }
            return;
        } else {
            revert("Opcode not implemented");
        }
    }

    function getPC() public view returns (uint16) {
        return emu.pc;
    }

    function getRAMValueAt(uint256 index) public view returns (uint8) {
        require(index < RAM_SIZE, "RAM index out of bounds");
        return emu.ram[index];
    }

    function getVRegister(uint256 index) public view returns (uint8) {
        require(index < NUM_REGS, "V register index out of bounds");
        return emu.v_reg[index];
    }
}
