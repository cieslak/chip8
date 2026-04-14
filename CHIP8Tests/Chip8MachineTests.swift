@testable import CHIP8
import XCTest

@MainActor
final class Chip8MachineTests: XCTestCase {

    var machine: Chip8Machine!

    override func setUp() {
        super.setUp()
        machine = Chip8Machine()
    }

    // MARK: - Helpers

    private func load(_ opcodes: UInt16...) {
        var bytes = [UInt8]()
        for op in opcodes {
            bytes.append(UInt8(op >> 8))
            bytes.append(UInt8(op & 0xFF))
        }
        machine.loadProgram(bytes)
    }

    private var startPC: UInt16 { 0x200 }

    // MARK: - 00E0: Clear screen

    func testOp00E0_clearsDisplay() {
        load(0x00E0)
        machine.video[0] = 1
        machine.video[500] = 1
        machine.step()
        XCTAssertTrue(machine.video.allSatisfy { $0 == 0 })
    }

    // MARK: - 00EE: Return from subroutine

    func testOp00EE_returnsFromSubroutine() {
        load(0x00EE)
        machine.stack[0] = 0x400
        machine.sp = 1
        machine.step()
        XCTAssertEqual(machine.pc, 0x400)
        XCTAssertEqual(machine.sp, 0)
    }

    // MARK: - 1nnn: Jump to address

    func testOp1nnn_jumpsToAddress() {
        load(0x1ABC)
        machine.step()
        XCTAssertEqual(machine.pc, 0xABC)
    }

    // MARK: - 2nnn: Call subroutine

    func testOp2nnn_callsSubroutine() {
        load(0x2300)
        machine.step()
        XCTAssertEqual(machine.pc, 0x300)
        XCTAssertEqual(machine.sp, 1)
        XCTAssertEqual(machine.stack[0], startPC + 2)
    }

    // MARK: - 3xkk: Skip if Vx == kk

    func testOp3xkk_skipsWhenEqual() {
        load(0x3042)
        machine.registers[0] = 0x42
        machine.step()
        XCTAssertEqual(machine.pc, startPC + 4)
    }

    func testOp3xkk_noSkipWhenNotEqual() {
        load(0x3042)
        machine.registers[0] = 0x00
        machine.step()
        XCTAssertEqual(machine.pc, startPC + 2)
    }

    // MARK: - 4xkk: Skip if Vx != kk

    func testOp4xkk_skipsWhenNotEqual() {
        load(0x4042)
        machine.registers[0] = 0x00
        machine.step()
        XCTAssertEqual(machine.pc, startPC + 4)
    }

    func testOp4xkk_noSkipWhenEqual() {
        load(0x4042)
        machine.registers[0] = 0x42
        machine.step()
        XCTAssertEqual(machine.pc, startPC + 2)
    }

    // MARK: - 5xy0: Skip if Vx == Vy

    func testOp5xy0_skipsWhenEqual() {
        load(0x5010)
        machine.registers[0] = 0x55
        machine.registers[1] = 0x55
        machine.step()
        XCTAssertEqual(machine.pc, startPC + 4)
    }

    func testOp5xy0_noSkipWhenNotEqual() {
        load(0x5010)
        machine.registers[0] = 0x55
        machine.registers[1] = 0x56
        machine.step()
        XCTAssertEqual(machine.pc, startPC + 2)
    }

    // MARK: - 6xkk: Set Vx = kk

    func testOp6xkk_setsRegister() {
        load(0x6A42)
        machine.step()
        XCTAssertEqual(machine.registers[0xA], 0x42)
    }

    // MARK: - 7xkk: Add kk to Vx (no carry flag)

    func testOp7xkk_adds() {
        load(0x7105)
        machine.registers[1] = 10
        machine.step()
        XCTAssertEqual(machine.registers[1], 15)
    }

    func testOp7xkk_wrapsWithoutSettingVF() {
        load(0x7001)
        machine.registers[0] = 0xFF
        machine.step()
        XCTAssertEqual(machine.registers[0], 0x00)
        XCTAssertEqual(machine.registers[0xF], 0)
    }

    // MARK: - 8xy0: Set Vx = Vy

    func testOp8xy0_copiesRegister() {
        load(0x8010)
        machine.registers[1] = 0x77
        machine.step()
        XCTAssertEqual(machine.registers[0], 0x77)
    }

    // MARK: - 8xy1: Set Vx |= Vy, VF reset to 0

    func testOp8xy1_ORsRegisters() {
        load(0x8011)
        machine.registers[0] = 0b10101010
        machine.registers[1] = 0b01010101
        machine.step()
        XCTAssertEqual(machine.registers[0], 0xFF)
        XCTAssertEqual(machine.registers[0xF], 0)
    }

    func testOp8xy1_resetsVF() {
        // VF is always set to 0 regardless of prior value
        load(0x8F11)
        machine.registers[0xF] = 1
        machine.registers[1] = 0x0F
        machine.step()
        XCTAssertEqual(machine.registers[0xF], 0)
    }

    // MARK: - 8xy2: Set Vx &= Vy, VF reset to 0

    func testOp8xy2_ANDsRegisters() {
        load(0x8012)
        machine.registers[0] = 0b11110000
        machine.registers[1] = 0b10101010
        machine.step()
        XCTAssertEqual(machine.registers[0], 0b10100000)
        XCTAssertEqual(machine.registers[0xF], 0)
    }

    func testOp8xy2_resetsVF() {
        load(0x8F12)
        machine.registers[0xF] = 1
        machine.registers[1] = 0xFF
        machine.step()
        XCTAssertEqual(machine.registers[0xF], 0)
    }

    // MARK: - 8xy3: Set Vx ^= Vy, VF reset to 0

    func testOp8xy3_XORsRegisters() {
        load(0x8013)
        machine.registers[0] = 0b11110000
        machine.registers[1] = 0b10101010
        machine.step()
        XCTAssertEqual(machine.registers[0], 0b01011010)
        XCTAssertEqual(machine.registers[0xF], 0)
    }

    func testOp8xy3_resetsVF() {
        load(0x8F13)
        machine.registers[0xF] = 1
        machine.registers[1] = 0xFF
        machine.step()
        XCTAssertEqual(machine.registers[0xF], 0)
    }

    // MARK: - 8xy4: Add Vy to Vx, VF = carry

    func testOp8xy4_addsWithCarry() {
        load(0x8014)
        machine.registers[0] = 0xFF
        machine.registers[1] = 0x01
        machine.step()
        XCTAssertEqual(machine.registers[0], 0x00)
        XCTAssertEqual(machine.registers[0xF], 1)
    }

    func testOp8xy4_addsWithoutCarry() {
        load(0x8014)
        machine.registers[0] = 0x05
        machine.registers[1] = 0x03
        machine.step()
        XCTAssertEqual(machine.registers[0], 0x08)
        XCTAssertEqual(machine.registers[0xF], 0)
    }

    func testOp8xy4_VFasDestination_storesCarry() {
        // When Vx is VF the carry flag overwrites the result
        load(0x8F14)
        machine.registers[0xF] = 0xFF
        machine.registers[1] = 0x02
        machine.step()
        XCTAssertEqual(machine.registers[0xF], 1)
    }

    // MARK: - 8xy5: Subtract Vy from Vx, VF = NOT borrow

    func testOp8xy5_subtractsNoBorrow() {
        load(0x8015)
        machine.registers[0] = 0x05
        machine.registers[1] = 0x03
        machine.step()
        XCTAssertEqual(machine.registers[0], 0x02)
        XCTAssertEqual(machine.registers[0xF], 1)
    }

    func testOp8xy5_subtractsWithBorrow() {
        load(0x8015)
        machine.registers[0] = 0x03
        machine.registers[1] = 0x05
        machine.step()
        XCTAssertEqual(machine.registers[0], 0xFE)
        XCTAssertEqual(machine.registers[0xF], 0)
    }

    func testOp8xy5_equalValues_noBorrow() {
        load(0x8015)
        machine.registers[0] = 0x05
        machine.registers[1] = 0x05
        machine.step()
        XCTAssertEqual(machine.registers[0], 0x00)
        XCTAssertEqual(machine.registers[0xF], 1)
    }

    // MARK: - 8xy6: Shift Vx right by 1, VF = shifted-out bit

    func testOp8xy6_shiftsRight_LSBSet() {
        load(0x8006)
        machine.registers[0] = 0b00000011
        machine.step()
        XCTAssertEqual(machine.registers[0], 0b00000001)
        XCTAssertEqual(machine.registers[0xF], 1)
    }

    func testOp8xy6_shiftsRight_LSBClear() {
        load(0x8006)
        machine.registers[0] = 0b00000100
        machine.step()
        XCTAssertEqual(machine.registers[0], 0b00000010)
        XCTAssertEqual(machine.registers[0xF], 0)
    }

    func testOp8xy6_shiftVXVY_disabled_shiftsVxInPlace() {
        load(0x8016)
        machine.shiftVXVY = false
        machine.registers[0] = 0b00000110
        machine.registers[1] = 0b11111111
        machine.step()
        XCTAssertEqual(machine.registers[0], 0b00000011)
        XCTAssertEqual(machine.registers[0xF], 0)
    }

    func testOp8xy6_shiftVXVY_enabled_copiesVyFirst() {
        load(0x8016)
        machine.shiftVXVY = true
        machine.registers[0] = 0b00000110
        machine.registers[1] = 0b00001111
        machine.step()
        // Vy (0b00001111) was copied into Vx, then shifted right: 0b00000111
        XCTAssertEqual(machine.registers[0], 0b00000111)
        XCTAssertEqual(machine.registers[0xF], 1) // LSB of Vy was 1
    }

    // MARK: - 8xy7: Set Vx = Vy - Vx, VF = NOT borrow

    func testOp8xy7_subtractsNoBorrow() {
        load(0x8017)
        machine.registers[0] = 0x03
        machine.registers[1] = 0x05
        machine.step()
        XCTAssertEqual(machine.registers[0], 0x02)
        XCTAssertEqual(machine.registers[0xF], 1)
    }

    func testOp8xy7_subtractsWithBorrow() {
        load(0x8017)
        machine.registers[0] = 0x05
        machine.registers[1] = 0x03
        machine.step()
        XCTAssertEqual(machine.registers[0], 0xFE)
        XCTAssertEqual(machine.registers[0xF], 0)
    }

    func testOp8xy7_equalValues_noBorrow() {
        load(0x8017)
        machine.registers[0] = 0x05
        machine.registers[1] = 0x05
        machine.step()
        XCTAssertEqual(machine.registers[0], 0x00)
        XCTAssertEqual(machine.registers[0xF], 1)
    }

    func testOp8xy7_VXzero_noBorrow() {
        // VY - 0 always has no borrow; VF must be 1
        load(0x8017)
        machine.registers[0] = 0x00
        machine.registers[1] = 0x05
        machine.step()
        XCTAssertEqual(machine.registers[0], 0x05)
        XCTAssertEqual(machine.registers[0xF], 1)
    }

    // MARK: - 8xyE: Shift Vx left by 1, VF = shifted-out bit

    func testOp8xye_shiftsLeft_MSBSet() {
        load(0x800E)
        machine.registers[0] = 0b11000000
        machine.step()
        XCTAssertEqual(machine.registers[0], 0b10000000)
        XCTAssertEqual(machine.registers[0xF], 1)
    }

    func testOp8xye_shiftsLeft_MSBClear() {
        load(0x800E)
        machine.registers[0] = 0b00000010
        machine.step()
        XCTAssertEqual(machine.registers[0], 0b00000100)
        XCTAssertEqual(machine.registers[0xF], 0)
    }

    // MARK: - 9xy0: Skip if Vx != Vy

    func testOp9xy0_skipsWhenNotEqual() {
        load(0x9010)
        machine.registers[0] = 0x01
        machine.registers[1] = 0x02
        machine.step()
        XCTAssertEqual(machine.pc, startPC + 4)
    }

    func testOp9xy0_noSkipWhenEqual() {
        load(0x9010)
        machine.registers[0] = 0x05
        machine.registers[1] = 0x05
        machine.step()
        XCTAssertEqual(machine.pc, startPC + 2)
    }

    // MARK: - Annn: Set I = nnn

    func testOpAnnn_setsI() {
        load(0xA123)
        machine.step()
        XCTAssertEqual(machine.i, 0x123)
    }

    // MARK: - Bnnn: Jump to V0 + nnn

    func testOpBnnn_jumps() {
        load(0xB100)
        machine.registers[0] = 0x10
        machine.step()
        XCTAssertEqual(machine.pc, 0x110)
    }

    // MARK: - Cxkk: Set Vx = rand & kk

    func testOpCxkk_masksRandom() {
        load(0xC00F)
        machine.step()
        XCTAssertEqual(machine.registers[0] & 0xF0, 0, "Upper nibble must be zero due to mask")
    }

    func testOpCxkk_zeroMaskAlwaysProducesZero() {
        load(0xC000)
        machine.registers[0] = 0xFF
        machine.step()
        XCTAssertEqual(machine.registers[0], 0)
    }

    // MARK: - Dxyn: Draw sprite

    func testOpDxyn_drawsSprite() {
        load(0xD001)
        machine.i = 0x300
        machine.memory[0x300] = 0xFF // 8 pixels all on
        machine.registers[0] = 0
        machine.registers[1] = 0
        machine.step()
        for col in 0..<8 {
            XCTAssertEqual(machine.video[col], 1, "Pixel at column \(col) should be on")
        }
        XCTAssertEqual(machine.registers[0xF], 0)
    }

    func testOpDxyn_detectsCollision() {
        load(0xD001)
        machine.i = 0x300
        machine.memory[0x300] = 0xFF
        machine.registers[0] = 0
        machine.registers[1] = 0
        machine.video[0] = 1 // pixel already set
        machine.step()
        XCTAssertEqual(machine.registers[0xF], 1)
    }

    func testOpDxyn_XORsExistingPixels() {
        load(0xD001)
        machine.i = 0x300
        machine.memory[0x300] = 0xFF
        machine.registers[0] = 0
        machine.registers[1] = 0
        for col in 0..<8 { machine.video[col] = 1 } // all pixels on
        machine.step()
        for col in 0..<8 {
            XCTAssertEqual(machine.video[col], 0, "Pixel at column \(col) should be off after XOR")
        }
        XCTAssertEqual(machine.registers[0xF], 1)
    }

    // MARK: - Ex9E: Skip if key Vx is pressed

    func testOpEx9E_skipsWhenKeyPressed() {
        load(0xE09E)
        machine.registers[0] = 5
        machine.keyboard[5] = true
        machine.step()
        XCTAssertEqual(machine.pc, startPC + 4)
    }

    func testOpEx9E_noSkipWhenKeyNotPressed() {
        load(0xE09E)
        machine.registers[0] = 5
        machine.keyboard[5] = false
        machine.step()
        XCTAssertEqual(machine.pc, startPC + 2)
    }

    // MARK: - ExA1: Skip if key Vx is NOT pressed

    func testOpExA1_skipsWhenKeyNotPressed() {
        load(0xE0A1)
        machine.registers[0] = 3
        machine.keyboard[3] = false
        machine.step()
        XCTAssertEqual(machine.pc, startPC + 4)
    }

    func testOpExA1_noSkipWhenKeyPressed() {
        load(0xE0A1)
        machine.registers[0] = 3
        machine.keyboard[3] = true
        machine.step()
        XCTAssertEqual(machine.pc, startPC + 2)
    }

    // MARK: - Fx07: Set Vx = delay timer value

    func testOpFx07_readsDelayTimer() {
        load(0xF007)
        machine.delayTimer = 42
        machine.step()
        XCTAssertEqual(machine.registers[0], 42)
    }

    // MARK: - Fx0A: Wait for key press

    func testOpFx0A_loopsWhenNoKeyPressed() {
        load(0xF00A)
        machine.step()
        XCTAssertEqual(machine.pc, startPC)
    }

    func testOpFx0A_storesKeyAndLoopsUntilRelease() {
        load(0xF00A)
        machine.keyboard[7] = true
        machine.step()
        XCTAssertEqual(machine.registers[0], 7)
        XCTAssertEqual(machine.pc, startPC) // still waiting for release
    }

    func testOpFx0A_advancesAfterKeyRelease() {
        load(0xF00A)
        machine.keyDown = true // key was previously detected as pressed
        machine.step()
        XCTAssertEqual(machine.pc, startPC + 2)
    }

    // MARK: - Fx15: Set delay timer = Vx

    func testOpFx15_setsDelayTimer() {
        load(0xF015)
        machine.registers[0] = 60
        machine.step()
        XCTAssertEqual(machine.delayTimer, 60)
    }

    // MARK: - Fx18: Set sound timer = Vx

    func testOpFx18_setsSoundTimer() {
        load(0xF018)
        machine.registers[0] = 10
        machine.step()
        XCTAssertEqual(machine.soundTimer, 10)
    }

    // MARK: - Fx1E: Set I += Vx

    func testOpFx1E_incrementsI() {
        load(0xF01E)
        machine.i = 0x100
        machine.registers[0] = 0x10
        machine.step()
        XCTAssertEqual(machine.i, 0x110)
    }

    // MARK: - Fx29: Set I = address of small font sprite for digit Vx

    func testOpFx29_pointsToSmallFontDigit0() {
        load(0xF029)
        machine.registers[0] = 0
        machine.step()
        XCTAssertEqual(machine.i, 0x50)
    }

    func testOpFx29_pointsToCorrectDigit() {
        load(0xF029)
        machine.registers[0] = 3
        machine.step()
        XCTAssertEqual(machine.i, 0x50 + 5 * 3)
    }

    // MARK: - Fx30: Set I = address of big font sprite for digit Vx

    func testOpFx30_pointsToBigFontDigit0() {
        load(0xF030)
        machine.registers[0] = 0
        machine.step()
        XCTAssertEqual(machine.i, 0xA0)
    }

    func testOpFx30_pointsToCorrectBigDigit() {
        load(0xF030)
        machine.registers[0] = 2
        machine.step()
        XCTAssertEqual(machine.i, 0xA0 + 10 * 2)
    }

    // MARK: - Fx33: Store BCD representation of Vx

    func testOpFx33_storesBCD() {
        load(0xF033)
        machine.i = 0x300
        machine.registers[0] = 234
        machine.step()
        XCTAssertEqual(machine.memory[0x300], 2)
        XCTAssertEqual(machine.memory[0x301], 3)
        XCTAssertEqual(machine.memory[0x302], 4)
    }

    func testOpFx33_storesBCD_singleDigit() {
        load(0xF033)
        machine.i = 0x300
        machine.registers[0] = 7
        machine.step()
        XCTAssertEqual(machine.memory[0x300], 0)
        XCTAssertEqual(machine.memory[0x301], 0)
        XCTAssertEqual(machine.memory[0x302], 7)
    }

    // MARK: - Fx55: Store V0 through Vx in memory

    func testOpFx55_storesRegisters() {
        load(0xF355)
        machine.i = 0x300
        machine.registers[0] = 0xAA
        machine.registers[1] = 0xBB
        machine.registers[2] = 0xCC
        machine.registers[3] = 0xDD
        machine.step()
        XCTAssertEqual(machine.memory[0x300], 0xAA)
        XCTAssertEqual(machine.memory[0x301], 0xBB)
        XCTAssertEqual(machine.memory[0x302], 0xCC)
        XCTAssertEqual(machine.memory[0x303], 0xDD)
    }

    func testOpFx55_incrementsI_whenEnabled() {
        load(0xF255)
        machine.i = 0x300
        machine.incrementI = true
        machine.step()
        XCTAssertEqual(machine.i, 0x300 + 3) // I + Vx + 1
    }

    func testOpFx55_preservesI_whenDisabled() {
        load(0xF255)
        machine.i = 0x300
        machine.incrementI = false
        machine.step()
        XCTAssertEqual(machine.i, 0x300)
    }

    // MARK: - Fx65: Read V0 through Vx from memory

    func testOpFx65_loadsRegisters() {
        load(0xF365)
        machine.i = 0x300
        machine.memory[0x300] = 0x11
        machine.memory[0x301] = 0x22
        machine.memory[0x302] = 0x33
        machine.memory[0x303] = 0x44
        machine.step()
        XCTAssertEqual(machine.registers[0], 0x11)
        XCTAssertEqual(machine.registers[1], 0x22)
        XCTAssertEqual(machine.registers[2], 0x33)
        XCTAssertEqual(machine.registers[3], 0x44)
    }

    func testOpFx65_incrementsI_whenEnabled() {
        load(0xF265)
        machine.i = 0x300
        machine.incrementI = true
        machine.step()
        XCTAssertEqual(machine.i, 0x300 + 3)
    }

    // MARK: - Fx75: Store V0 through Vx in HP48 registers

    func testOpFx75_storesInHP48() {
        load(0xF275)
        machine.registers[0] = 0x10
        machine.registers[1] = 0x20
        machine.registers[2] = 0x30
        machine.step()
        XCTAssertEqual(machine.hp48[0], 0x10)
        XCTAssertEqual(machine.hp48[1], 0x20)
        XCTAssertEqual(machine.hp48[2], 0x30)
    }

    func testOpFx75_doesNotStoreToMemory() {
        // Fx75 stores to hp48, not to memory[I]
        load(0xF075)
        machine.i = 0x300
        machine.registers[0] = 0xAB
        machine.step()
        XCTAssertEqual(machine.hp48[0], 0xAB)
        XCTAssertEqual(machine.memory[0x300], 0) // memory untouched
    }

    // MARK: - Fx85: Read V0 through Vx from HP48 registers

    func testOpFx85_loadsFromHP48() {
        load(0xF285)
        machine.hp48[0] = 0xAA
        machine.hp48[1] = 0xBB
        machine.hp48[2] = 0xCC
        machine.step()
        XCTAssertEqual(machine.registers[0], 0xAA)
        XCTAssertEqual(machine.registers[1], 0xBB)
        XCTAssertEqual(machine.registers[2], 0xCC)
    }

    func testOpFx85_doesNotReadFromMemory() {
        // Fx85 reads from hp48, not from memory[I]
        load(0xF085)
        machine.i = 0x300
        machine.memory[0x300] = 0xFF
        machine.hp48[0] = 0x42
        machine.step()
        XCTAssertEqual(machine.registers[0], 0x42) // from hp48, not memory
    }

    // MARK: - 00Cx: Scroll display down x rows

    func testOp00Cx_scrollsDown() {
        // Standard mode: 64 pixels wide
        load(0x00C2) // scroll down 2 rows
        for col in 0..<64 { machine.video[col] = 1 } // row 0 all on
        machine.step()
        // First 2 rows (128 pixels at 64-wide) must be empty
        for idx in 0..<128 {
            XCTAssertEqual(machine.video[idx], 0, "Index \(idx) should be empty after scroll")
        }
        // Original row 0 should now be at row 2
        for col in 0..<64 {
            XCTAssertEqual(machine.video[128 + col], 1, "Column \(col) of row 2 should have row 0's content")
        }
    }

    // MARK: - 00FB: Scroll display right 4 pixels

    func testOp00FB_scrollsRight() {
        machine.displayType = .extended
        load(0x00FB)
        machine.video[0] = 1
        machine.video[1] = 1
        machine.video[2] = 1
        machine.video[3] = 1
        machine.step()
        XCTAssertEqual(machine.video[0], 0)
        XCTAssertEqual(machine.video[1], 0)
        XCTAssertEqual(machine.video[2], 0)
        XCTAssertEqual(machine.video[3], 0)
        XCTAssertEqual(machine.video[4], 1)
        XCTAssertEqual(machine.video[5], 1)
        XCTAssertEqual(machine.video[6], 1)
        XCTAssertEqual(machine.video[7], 1)
    }

    // MARK: - 00FC: Scroll display left 4 pixels

    func testOp00FC_scrollsLeft() {
        machine.displayType = .extended
        load(0x00FC)
        machine.video[4] = 1
        machine.video[5] = 1
        machine.video[6] = 1
        machine.video[7] = 1
        machine.step()
        XCTAssertEqual(machine.video[0], 1)
        XCTAssertEqual(machine.video[1], 1)
        XCTAssertEqual(machine.video[2], 1)
        XCTAssertEqual(machine.video[3], 1)
    }

    // MARK: - 00FD: Exit (halt by looping the PC)

    func testOp00FD_halts() {
        load(0x00FD)
        machine.step()
        XCTAssertEqual(machine.pc, startPC)
    }

    // MARK: - 00FE: Switch to standard display mode

    func testOp00FE_setsStandardMode() {
        machine.displayType = .extended
        load(0x00FE)
        machine.step()
        XCTAssertEqual(machine.displayType, .standard)
    }

    // MARK: - 00FF: Switch to extended display mode

    func testOp00FF_setsExtendedMode() {
        load(0x00FF)
        machine.step()
        XCTAssertEqual(machine.displayType, .extended)
    }
}
