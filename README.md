# SolChip8

[Chip8](https://en.wikipedia.org/wiki/CHIP-8) Emulator written in Solidity.

Got helped alot from [An Introduction to Chip-8 Emulation using the Rust Programming Language](https://aquova.net/chip8/chip8.pdf).

- A 64x32 monochrome display
- Sixteen 8-bit general purpose registers
- 4096 bytes of RAM
- Example [ROM games](./c8games/) from [Chip-8 Games Pack](https://www.zophar.net/pdroms/chip8/chip-8-games-pack.html)

### **Supported CHIP-8 Opcodes**

| Opcode | Mnemonic          | Description                                                         |
| ------ | ----------------- | ------------------------------------------------------------------- |
| 0000   | **NOP**           | Nothing                                                             |
| 00E0   | **CLS**           | Clear the display                                                   |
| 00EE   | **RET**           | Return from a subroutine                                            |
| 1NNN   | **JP NNN**        | Jump to address `NNN`                                               |
| 2NNN   | **CALL NNN**      | Call subroutine at `NNN`                                            |
| 3XNN   | **SE Vx, NN**     | Skip next instruction if `Vx` equals `NN`                           |
| 4XNN   | **SNE Vx, NN**    | Skip next instruction if `Vx` does not equal `NN`                   |
| 5XY0   | **SE Vx, Vy**     | Skip next instruction if `Vx` equals `Vy`                           |
| 6XNN   | **LD Vx, NN**     | Load value `NN` into register `Vx`                                  |
| 7XNN   | **ADD Vx, NN**    | Add value `NN` to register `Vx`                                     |
| 8XY0   | **LD Vx, Vy**     | Set `Vx` equal to `Vy`                                              |
| 8XY1   | **OR Vx, Vy**     | Set `Vx` to `Vx` OR `Vy`                                            |
| 8XY2   | **AND Vx, Vy**    | Set `Vx` to `Vx` AND `Vy`                                           |
| 8XY3   | **XOR Vx, Vy**    | Set `Vx` to `Vx` XOR `Vy`                                           |
| 8XY4   | **ADD Vx, Vy**    | Add `Vy` to `Vx`, set VF to carry                                   |
| 8XY5   | **SUB Vx, Vy**    | Subtract `Vy` from `Vx`, set VF to NOT borrow                       |
| 8XY6   | **SHR Vx**        | Shift `Vx` right by 1, set VF to least significant bit              |
| 8XY7   | **SUBN Vx, Vy**   | Set `Vx` to `Vy` minus `Vx`, set VF to NOT borrow                   |
| 8XYE   | **SHL Vx**        | Shift `Vx` left by 1, set VF to most significant bit                |
| 9XY0   | **SNE Vx, Vy**    | Skip next instruction if `Vx` does not equal `Vy`                   |
| ANNN   | **LD I, NNN**     | Set `I` to address `NNN`                                            |
| BNNN   | **JP V0, NNN**    | Jump to address `V0 + NNN`                                          |
| CXNN   | **RND Vx, NN**    | Set `Vx` to random byte AND `NN`                                    |
| DXYN   | **DRW Vx, Vy, N** | Draw sprite at (`Vx`, `Vy`) with height `N`, set VF on collision    |
| EX9E   | **SKP Vx**        | Skip next instruction if key `Vx` is pressed                        |
| EXA1   | **SKNP Vx**       | Skip next instruction if key `Vx` is not pressed                    |
| FX07   | **LD Vx, DT**     | Set `Vx` to the value of the delay timer                            |
| FX0A   | **LD Vx, K**      | Wait for a key press, store the value in `Vx`                       |
| FX15   | **LD DT, Vx**     | Set the delay timer to `Vx`                                         |
| FX18   | **LD ST, Vx**     | Set the sound timer to `Vx`                                         |
| FX1E   | **ADD I, Vx**     | Add `Vx` to `I`                                                     |
| FX29   | **LD F, Vx**      | Set `I` to the location of the sprite for digit `Vx`                |
| FX33   | **LD B, Vx**      | Store BCD representation of `Vx` in memory at `I`, `I+1`, and `I+2` |
| FX55   | **LD [I], Vx**    | Store registers `V0` to `Vx` in memory starting at `I`              |
| FX65   | **LD Vx, [I]**    | Read registers `V0` to `Vx` from memory starting at `I`             |
