// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/// @title Solchip8 - The first 100% on-chain CHIP-8 emulator
/// @author @rkdud007
/// @notice A standard CHIP-8 emulator supporting a 64x32 monochrome display, sixteen 8-bit general-purpose registers, and 4096 bytes of RAM.
/// @dev This contract is optimized for CHIP-8 emulation within the EVM environment.

/**
 * ====================================== Display Representation ======================================
 * The display has a width of 64 pixels and a height of 32 pixels, totaling 2048 pixels.
 * Each pixel is either black (0) or white (1). To optimize storage, each pixel is represented as a bit.
 * Using EVM's base unit of bytes32, we compress the display into a `uint256[8]` array:
 *
 * Example:
 *       |-----8 bits (1 byte) * 32 = bytes32-----|
 *       00000000 00000000 ..... 00000000 00000000 -|
 *       00000000 00000000 ..... 00000000 00000000  |
 *       ...                                        8 rows
 *       00000000 00000000 ..... 00000000 00000000  |
 *       00000000 00000000 ..... 00000000 00000000 -|
 *
 * This representation efficiently stores all 2048 pixels within a `uint256[8]` array.
 *
 * ====================================== Keyboard Representation =====================================
 * The keyboard supports 16 keys, with indices ranging from 0x0 to 0xF.
 * Each key state is either pressed (1) or not pressed (0), represented as a `uint16` bitfield.
 *
 * Keyboard Layout:
 *     Keyboard                    CHIP-8
 *     +---+---+---+---+           +---+---+---+---+
 *     | 1 | 2 | 3 | 4 |           | 1 | 2 | 3 | C |
 *     +---+---+---+---+           +---+---+---+---+
 *     | Q | W | E | R |           | 4 | 5 | 6 | D |
 *     +---+---+---+---+    =>     +---+---+---+---+
 *     | A | S | D | F |           | 7 | 8 | 9 | E |
 *     +---+---+---+---+           +---+---+---+---+
 *     | Z | X | C | V |           | A | 0 | B | F |
 *     +---+---+---+---+           +---+---+---+---+
 *
 * Example:
 *     Pressing the `Q` key results in:
 *     00010000 00000000 (binary representation of the `uint16` keys field).
 */
contract Solchip8 {
    // -------------------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------------------

    /// @notice Screen width in pixels.
    uint16 constant SCREEN_WIDTH = 64;
    /// @notice Screen height in pixels.
    uint16 constant SCREEN_HEIGHT = 32;

    /// @notice Size of RAM in bytes.
    uint16 constant RAM_SIZE = 4096;
    /// @notice Number of general-purpose registers.
    uint8 constant NUM_REGS = 16;
    /// @notice Number of stack entries.
    uint8 constant STACK_SIZE = 16;
    /// @notice Number of keys on the CHIP-8 keyboard.
    uint8 constant NUM_KEYS = 16;

    // -------------------------------------------------------------------------
    // Display
    // -------------------------------------------------------------------------

    /// @notice Size of the font set.
    uint8 constant FONTSET_SIZE = 80;

    /// @notice Font set containing the sprite data for hexadecimal digits (0-9 and A-F).
    /// @dev Each character sprite consists of 5 bytes, representing an 8x5 monochrome grid.
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
        /// @notice 16-bit program counter.
        uint16 pc;
        /// @notice 4KB of RAM.
        uint8[RAM_SIZE] ram;
        /// @notice Display as a bitfield (8 rows of 256 bits each).
        uint256[8] screen;
        /// @notice Sixteen 8-bit general-purpose registers (V0 to VF).
        uint8[NUM_REGS] v_reg;
        /// @notice A 16-bit register for memory access (I register).
        uint16 i_reg;
        /// @notice Stack pointer.
        uint16 sp;
        /// @notice Stack for subroutine calls.
        uint16[STACK_SIZE] stack;
        /// @notice Keyboard state as a 16-bit bitfield.
        uint16 keys;
        /// @notice Delay timer.
        uint8 dt;
        /// @notice Sound timer.
        uint8 st;
        /// @notice Size of the loaded program.
        uint256 program_size;
    }

    /// @dev Instance of the CHIP-8 emulator.
    Emulator emu;

    // -------------------------------------------------------------------------
    // Initialization
    // -------------------------------------------------------------------------

    /// @notice The starting address for programs (typically 0x200).
    uint16 constant START_ADDR = 0x200;

    /// @notice Constructor that initializes the emulator with the font set.
    constructor() {
        emu.pc = START_ADDR;
        for (uint256 i = 0; i < FONTSET_SIZE; i++) {
            emu.ram[i] = FONTSET[i];
        }
    }

    /// @notice Resets the emulator to its initial state.
    function reset() public {
        emu.pc = START_ADDR;
        for (uint256 i = 0; i < 8; i++) {
            emu.screen[i] = 0;
        }
        for (uint256 i = 0; i < NUM_REGS; i++) {
            emu.v_reg[i] = 0;
        }
        emu.i_reg = 0;
        emu.sp = 0;
        for (uint256 i = 0; i < STACK_SIZE; i++) {
            emu.stack[i] = 0;
        }
        emu.keys = 0;
        emu.dt = 0;
        emu.st = 0;

        // Reload font set into RAM
        for (uint256 i = 0; i < FONTSET_SIZE; i++) {
            emu.ram[i] = FONTSET[i];
        }
    }

    // -------------------------------------------------------------------------
    // Emulation functions
    // -------------------------------------------------------------------------

    /// @notice Push a value onto the stack
    function push(uint16 val) internal {
        require(emu.sp < STACK_SIZE, "Stack overflow");
        emu.stack[emu.sp] = val;
        emu.sp += 1;
    }

    /// @notice Pop a value from the stack
    function pop() internal returns (uint16) {
        require(emu.sp > 0, "Stack underflow");
        emu.sp -= 1;
        return emu.stack[emu.sp];
    }

    /// @notice CPU processing loop
    /// @dev This function is called once per tick of the CPU.
    /// Fetch the next instruction, decode and execute it.
    function tick() public {
        // Fetch
        uint16 op = fetch();
        // Decode & execute
        execute(op);

        _tickTimers();
    }

    function _tickTimers() internal {
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

    /// @notice Fetch the next instruction
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
            for (uint256 i = 0; i < 8; i++) {
                emu.screen[i] = 0;
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
            unchecked {
                emu.v_reg[digit2] += nn;
            }
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
                    // Get the sprite pixel (bit) at the current column
                    uint8 sprite_pixel = (sprite_byte >> (7 - col)) & 0x1;
                    uint32 screen_x = uint32((x + col) % SCREEN_WIDTH);
                    uint32 screen_y = uint32((y + row) % SCREEN_HEIGHT);

                    // Calculate the index in the display buffer
                    uint32 pixel_index = screen_y * SCREEN_WIDTH + screen_x; // Range: 0 to 2047

                    // Calculate the display array index and bit position
                    uint256 display_index = pixel_index / 256; // Index in emu.screen[]
                    uint256 bit_position = pixel_index % 256; // Bit position within emu.screen[display_index]

                    // Get the current pixel value from the display
                    bool pixel_before = ((emu.screen[display_index] >> (255 - bit_position)) & 0x1) != 0;

                    // Calculate the new pixel value using XOR (as per CHIP-8 drawing behavior)
                    bool new_pixel = pixel_before != (sprite_pixel == 1);

                    // Update the collision flag VF if a pixel is erased
                    if (pixel_before && !new_pixel) {
                        emu.v_reg[0xF] = 1;
                    }

                    // Update the display with the new pixel value
                    if (new_pixel) {
                        // Set the bit to 1
                        emu.screen[display_index] |= (1 << (255 - bit_position));
                    } else {
                        // Set the bit to 0
                        emu.screen[display_index] &= ~(1 << (255 - bit_position));
                    }
                }
            }
            return;
        }
        // EX9E - SKIP if key[VX] pressed
        else if (digit1 == 0xE && digit3 == 0x9 && digit4 == 0xE) {
            uint8 x = digit2;
            uint8 key = emu.v_reg[x];
            require(key < NUM_KEYS, "Invalid key");
            if ((emu.keys & (1 << key)) != 0) {
                emu.pc += 2;
            }
            return;
        }
        // EXA1 - SKIP if key[VX] not pressed
        else if (digit1 == 0xE && digit3 == 0xA && digit4 == 0x1) {
            uint8 x = digit2;
            uint8 key = emu.v_reg[x];
            require(key < NUM_KEYS, "Invalid key");
            if ((emu.keys & (1 << key)) == 0) {
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
                if ((emu.keys & (1 << i)) != 0) {
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

    // -------------------------------------------------------------------------
    // Frontend functions
    // -------------------------------------------------------------------------

    /// @notice Get display
    function getDisplay() public view returns (uint256[8] memory) {
        return emu.screen;
    }

    /// @notice Handle keypress event
    /// @param idx Index of the key (0-15)
    /// @param pressed Whether the key is pressed (true) or released (false)
    function keypress(uint256 idx, bool pressed) public {
        require(idx < 16, "Invalid key index");

        if (pressed) {
            // Set the bit at position `idx` to 1
            emu.keys |= uint16(1 << idx);
        } else {
            // Clear the bit at position `idx` to 0
            emu.keys &= ~uint16(1 << idx);
        }
    }

    /// @notice Load program into memory
    function load(uint8[] memory data) public {
        uint256 start = START_ADDR;
        uint256 end = START_ADDR + data.length;
        require(end <= RAM_SIZE, "Data too large to fit in RAM");
        for (uint256 i = start; i < end; i++) {
            emu.ram[i] = data[i - start];
        }
        emu.program_size = data.length;
    }

    // -------------------------------------------------------------------------
    // Utility functions
    // -------------------------------------------------------------------------

    function getPC() public view returns (uint16) {
        return emu.pc;
    }

    function getKeys() public view returns (uint16) {
        return emu.keys;
    }

    function getRAMValueAt(uint256 index) public view returns (uint8) {
        require(index < RAM_SIZE, "RAM index out of bounds");
        return emu.ram[index];
    }

    function getVRegister(uint256 index) public view returns (uint8) {
        require(index < NUM_REGS, "V register index out of bounds");
        return emu.v_reg[index];
    }

    function setVRegister(uint8 index, uint8 value) public {
        require(index < NUM_REGS, "V register index out of bounds");
        emu.v_reg[index] = value;
    }

    function getIRegister() public view returns (uint16) {
        return emu.i_reg;
    }

    function setIRegister(uint16 value) public {
        emu.i_reg = value;
    }

    function setRAMValueAt(uint256 index, uint8 value) public {
        require(index < RAM_SIZE, "RAM index out of bounds");
        emu.ram[index] = value;
    }

    function getDelayTimer() public view returns (uint8) {
        return emu.dt;
    }

    function setDelayTimer(uint8 value) public {
        emu.dt = value;
    }

    function getSoundTimer() public view returns (uint8) {
        return emu.st;
    }

    function setSoundTimer(uint8 value) public {
        emu.st = value;
    }

    function getSP() public view returns (uint16) {
        return emu.sp;
    }

    function getStackValue(uint256 index) public view returns (uint16) {
        require(index < STACK_SIZE, "Stack index out of bounds");
        return emu.stack[index];
    }

    function setStackValue(uint256 index, uint16 value) public {
        require(index < STACK_SIZE, "Stack index out of bounds");
        emu.stack[index] = value;
    }

    function setSP(uint16 value) public {
        emu.sp = value;
    }

    function setScreenPixel(uint256 index, bool value) public {
        unchecked {
            require(index < SCREEN_WIDTH * SCREEN_HEIGHT, "Index out of bounds");
            if (value) {
                // Set the bit to 1
                emu.screen[index >> 8] |= 1 << (index & 255);
            } else {
                // Set the bit to 0
                emu.screen[index >> 8] &= ~(1 << (index & 255));
            }
        }
    }

    function isDisplayCleared() public view returns (bool) {
        return (
            emu.screen[0] == 0 && emu.screen[1] == 0 && emu.screen[2] == 0 && emu.screen[3] == 0 && emu.screen[4] == 0
                && emu.screen[5] == 0 && emu.screen[6] == 0 && emu.screen[7] == 0
        );
    }
}
