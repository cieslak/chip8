@testable import CHIP8
import XCTest

nonisolated final class Chip8MachineTests: XCTestCase {

    var machine: Chip8Machine!

    override func setUp() {
        super.setUp()
        machine = Chip8Machine()
    }

    // MARK: - Helpers

    private func load(_ opcodes: UInt16...) async {
        var bytes = [UInt8]()
        for op in opcodes {
            bytes.append(UInt8(op >> 8))
            bytes.append(UInt8(op & 0xFF))
        }
        await machine.loadProgram(bytes)
    }

    private var startPC: UInt16 { 0x200 }

    // MARK: - 00E0: Clear screen

    func testOp00E0_clearsDisplay() async {
        await load(0x00E0)
        await machine.setVideo(0, 1)
        await machine.setVideo(500, 1)
        await machine.step()
        let video = await machine.video
        XCTAssertTrue(video.allSatisfy { $0 == 0 })
    }

    // MARK: - 00EE: Return from subroutine

    func testOp00EE_returnsFromSubroutine() async {
        await load(0x00EE)
        await machine.setStack(0, 0x400)
        await machine.setSP(1)
        await machine.step()
        let pc = await machine.pc
        let sp = await machine.sp
        XCTAssertEqual(pc, 0x400)
        XCTAssertEqual(sp, 0)
    }

    // MARK: - 1nnn: Jump to address

    func testOp1nnn_jumpsToAddress() async {
        await load(0x1ABC)
        await machine.step()
        let pc = await machine.pc
        XCTAssertEqual(pc, 0xABC)
    }

    // MARK: - 2nnn: Call subroutine

    func testOp2nnn_callsSubroutine() async {
        await load(0x2300)
        await machine.step()
        let pc = await machine.pc
        let sp = await machine.sp
        let stack0 = await machine.stack[0]
        XCTAssertEqual(pc, 0x300)
        XCTAssertEqual(sp, 1)
        XCTAssertEqual(stack0, startPC + 2)
    }

    // MARK: - 3xkk: Skip if Vx == kk

    func testOp3xkk_skipsWhenEqual() async {
        await load(0x3042)
        await machine.setRegister(0, 0x42)
        await machine.step()
        let pc = await machine.pc
        XCTAssertEqual(pc, startPC + 4)
    }

    func testOp3xkk_noSkipWhenNotEqual() async {
        await load(0x3042)
        await machine.setRegister(0, 0x00)
        await machine.step()
        let pc = await machine.pc
        XCTAssertEqual(pc, startPC + 2)
    }

    // MARK: - 4xkk: Skip if Vx != kk

    func testOp4xkk_skipsWhenNotEqual() async {
        await load(0x4042)
        await machine.setRegister(0, 0x00)
        await machine.step()
        let pc = await machine.pc
        XCTAssertEqual(pc, startPC + 4)
    }

    func testOp4xkk_noSkipWhenEqual() async {
        await load(0x4042)
        await machine.setRegister(0, 0x42)
        await machine.step()
        let pc = await machine.pc
        XCTAssertEqual(pc, startPC + 2)
    }

    // MARK: - 5xy0: Skip if Vx == Vy

    func testOp5xy0_skipsWhenEqual() async {
        await load(0x5010)
        await machine.setRegister(0, 0x55)
        await machine.setRegister(1, 0x55)
        await machine.step()
        let pc = await machine.pc
        XCTAssertEqual(pc, startPC + 4)
    }

    func testOp5xy0_noSkipWhenNotEqual() async {
        await load(0x5010)
        await machine.setRegister(0, 0x55)
        await machine.setRegister(1, 0x56)
        await machine.step()
        let pc = await machine.pc
        XCTAssertEqual(pc, startPC + 2)
    }

    // MARK: - 6xkk: Set Vx = kk

    func testOp6xkk_setsRegister() async {
        await load(0x6A42)
        await machine.step()
        let reg = await machine.registers[0xA]
        XCTAssertEqual(reg, 0x42)
    }

    // MARK: - 7xkk: Add kk to Vx (no carry flag)

    func testOp7xkk_adds() async {
        await load(0x7105)
        await machine.setRegister(1, 10)
        await machine.step()
        let reg = await machine.registers[1]
        XCTAssertEqual(reg, 15)
    }

    func testOp7xkk_wrapsWithoutSettingVF() async {
        await load(0x7001)
        await machine.setRegister(0, 0xFF)
        await machine.step()
        let reg0 = await machine.registers[0]
        let regF = await machine.registers[0xF]
        XCTAssertEqual(reg0, 0x00)
        XCTAssertEqual(regF, 0)
    }

    // MARK: - 8xy0: Set Vx = Vy

    func testOp8xy0_copiesRegister() async {
        await load(0x8010)
        await machine.setRegister(1, 0x77)
        await machine.step()
        let reg = await machine.registers[0]
        XCTAssertEqual(reg, 0x77)
    }

    // MARK: - 8xy1: Set Vx |= Vy, VF reset to 0

    func testOp8xy1_ORsRegisters() async {
        await load(0x8011)
        await machine.setRegister(0, 0b10101010)
        await machine.setRegister(1, 0b01010101)
        await machine.step()
        let reg0 = await machine.registers[0]
        let regF = await machine.registers[0xF]
        XCTAssertEqual(reg0, 0xFF)
        XCTAssertEqual(regF, 0)
    }

    func testOp8xy1_resetsVF() async {
        await load(0x8F11)
        await machine.setRegister(0xF, 1)
        await machine.setRegister(1, 0x0F)
        await machine.step()
        let regF = await machine.registers[0xF]
        XCTAssertEqual(regF, 0)
    }

    // MARK: - 8xy2: Set Vx &= Vy, VF reset to 0

    func testOp8xy2_ANDsRegisters() async {
        await load(0x8012)
        await machine.setRegister(0, 0b11110000)
        await machine.setRegister(1, 0b10101010)
        await machine.step()
        let reg0 = await machine.registers[0]
        let regF = await machine.registers[0xF]
        XCTAssertEqual(reg0, 0b10100000)
        XCTAssertEqual(regF, 0)
    }

    func testOp8xy2_resetsVF() async {
        await load(0x8F12)
        await machine.setRegister(0xF, 1)
        await machine.setRegister(1, 0xFF)
        await machine.step()
        let regF = await machine.registers[0xF]
        XCTAssertEqual(regF, 0)
    }

    // MARK: - 8xy3: Set Vx ^= Vy, VF reset to 0

    func testOp8xy3_XORsRegisters() async {
        await load(0x8013)
        await machine.setRegister(0, 0b11110000)
        await machine.setRegister(1, 0b10101010)
        await machine.step()
        let reg0 = await machine.registers[0]
        let regF = await machine.registers[0xF]
        XCTAssertEqual(reg0, 0b01011010)
        XCTAssertEqual(regF, 0)
    }

    func testOp8xy3_resetsVF() async {
        await load(0x8F13)
        await machine.setRegister(0xF, 1)
        await machine.setRegister(1, 0xFF)
        await machine.step()
        let regF = await machine.registers[0xF]
        XCTAssertEqual(regF, 0)
    }

    // MARK: - 8xy4: Add Vy to Vx, VF = carry

    func testOp8xy4_addsWithCarry() async {
        await load(0x8014)
        await machine.setRegister(0, 0xFF)
        await machine.setRegister(1, 0x01)
        await machine.step()
        let reg0 = await machine.registers[0]
        let regF = await machine.registers[0xF]
        XCTAssertEqual(reg0, 0x00)
        XCTAssertEqual(regF, 1)
    }

    func testOp8xy4_addsWithoutCarry() async {
        await load(0x8014)
        await machine.setRegister(0, 0x05)
        await machine.setRegister(1, 0x03)
        await machine.step()
        let reg0 = await machine.registers[0]
        let regF = await machine.registers[0xF]
        XCTAssertEqual(reg0, 0x08)
        XCTAssertEqual(regF, 0)
    }

    func testOp8xy4_VFasDestination_storesCarry() async {
        await load(0x8F14)
        await machine.setRegister(0xF, 0xFF)
        await machine.setRegister(1, 0x02)
        await machine.step()
        let regF = await machine.registers[0xF]
        XCTAssertEqual(regF, 1)
    }

    // MARK: - 8xy5: Subtract Vy from Vx, VF = NOT borrow

    func testOp8xy5_subtractsNoBorrow() async {
        await load(0x8015)
        await machine.setRegister(0, 0x05)
        await machine.setRegister(1, 0x03)
        await machine.step()
        let reg0 = await machine.registers[0]
        let regF = await machine.registers[0xF]
        XCTAssertEqual(reg0, 0x02)
        XCTAssertEqual(regF, 1)
    }

    func testOp8xy5_subtractsWithBorrow() async {
        await load(0x8015)
        await machine.setRegister(0, 0x03)
        await machine.setRegister(1, 0x05)
        await machine.step()
        let reg0 = await machine.registers[0]
        let regF = await machine.registers[0xF]
        XCTAssertEqual(reg0, 0xFE)
        XCTAssertEqual(regF, 0)
    }

    func testOp8xy5_equalValues_noBorrow() async {
        await load(0x8015)
        await machine.setRegister(0, 0x05)
        await machine.setRegister(1, 0x05)
        await machine.step()
        let reg0 = await machine.registers[0]
        let regF = await machine.registers[0xF]
        XCTAssertEqual(reg0, 0x00)
        XCTAssertEqual(regF, 1)
    }

    // MARK: - 8xy6: Shift Vx right by 1, VF = shifted-out bit

    func testOp8xy6_shiftsRight_LSBSet() async {
        await load(0x8006)
        await machine.setRegister(0, 0b00000011)
        await machine.step()
        let reg0 = await machine.registers[0]
        let regF = await machine.registers[0xF]
        XCTAssertEqual(reg0, 0b00000001)
        XCTAssertEqual(regF, 1)
    }

    func testOp8xy6_shiftsRight_LSBClear() async {
        await load(0x8006)
        await machine.setRegister(0, 0b00000100)
        await machine.step()
        let reg0 = await machine.registers[0]
        let regF = await machine.registers[0xF]
        XCTAssertEqual(reg0, 0b00000010)
        XCTAssertEqual(regF, 0)
    }

    func testOp8xy6_shiftVXVY_disabled_shiftsVxInPlace() async {
        await load(0x8016)
        await machine.setShiftVXVY(false)
        await machine.setRegister(0, 0b00000110)
        await machine.setRegister(1, 0b11111111)
        await machine.step()
        let reg0 = await machine.registers[0]
        let regF = await machine.registers[0xF]
        XCTAssertEqual(reg0, 0b00000011)
        XCTAssertEqual(regF, 0)
    }

    func testOp8xy6_shiftVXVY_enabled_copiesVyFirst() async {
        await load(0x8016)
        await machine.setShiftVXVY(true)
        await machine.setRegister(0, 0b00000110)
        await machine.setRegister(1, 0b00001111)
        await machine.step()
        let reg0 = await machine.registers[0]
        let regF = await machine.registers[0xF]
        XCTAssertEqual(reg0, 0b00000111)
        XCTAssertEqual(regF, 1)
    }

    // MARK: - 8xy7: Set Vx = Vy - Vx, VF = NOT borrow

    func testOp8xy7_subtractsNoBorrow() async {
        await load(0x8017)
        await machine.setRegister(0, 0x03)
        await machine.setRegister(1, 0x05)
        await machine.step()
        let reg0 = await machine.registers[0]
        let regF = await machine.registers[0xF]
        XCTAssertEqual(reg0, 0x02)
        XCTAssertEqual(regF, 1)
    }

    func testOp8xy7_subtractsWithBorrow() async {
        await load(0x8017)
        await machine.setRegister(0, 0x05)
        await machine.setRegister(1, 0x03)
        await machine.step()
        let reg0 = await machine.registers[0]
        let regF = await machine.registers[0xF]
        XCTAssertEqual(reg0, 0xFE)
        XCTAssertEqual(regF, 0)
    }

    func testOp8xy7_equalValues_noBorrow() async {
        await load(0x8017)
        await machine.setRegister(0, 0x05)
        await machine.setRegister(1, 0x05)
        await machine.step()
        let reg0 = await machine.registers[0]
        let regF = await machine.registers[0xF]
        XCTAssertEqual(reg0, 0x00)
        XCTAssertEqual(regF, 1)
    }

    func testOp8xy7_VXzero_noBorrow() async {
        await load(0x8017)
        await machine.setRegister(0, 0x00)
        await machine.setRegister(1, 0x05)
        await machine.step()
        let reg0 = await machine.registers[0]
        let regF = await machine.registers[0xF]
        XCTAssertEqual(reg0, 0x05)
        XCTAssertEqual(regF, 1)
    }

    // MARK: - 8xyE: Shift Vx left by 1, VF = shifted-out bit

    func testOp8xye_shiftsLeft_MSBSet() async {
        await load(0x800E)
        await machine.setRegister(0, 0b11000000)
        await machine.step()
        let reg0 = await machine.registers[0]
        let regF = await machine.registers[0xF]
        XCTAssertEqual(reg0, 0b10000000)
        XCTAssertEqual(regF, 1)
    }

    func testOp8xye_shiftsLeft_MSBClear() async {
        await load(0x800E)
        await machine.setRegister(0, 0b00000010)
        await machine.step()
        let reg0 = await machine.registers[0]
        let regF = await machine.registers[0xF]
        XCTAssertEqual(reg0, 0b00000100)
        XCTAssertEqual(regF, 0)
    }

    // MARK: - 9xy0: Skip if Vx != Vy

    func testOp9xy0_skipsWhenNotEqual() async {
        await load(0x9010)
        await machine.setRegister(0, 0x01)
        await machine.setRegister(1, 0x02)
        await machine.step()
        let pc = await machine.pc
        XCTAssertEqual(pc, startPC + 4)
    }

    func testOp9xy0_noSkipWhenEqual() async {
        await load(0x9010)
        await machine.setRegister(0, 0x05)
        await machine.setRegister(1, 0x05)
        await machine.step()
        let pc = await machine.pc
        XCTAssertEqual(pc, startPC + 2)
    }

    // MARK: - Annn: Set I = nnn

    func testOpAnnn_setsI() async {
        await load(0xA123)
        await machine.step()
        let i = await machine.i
        XCTAssertEqual(i, 0x123)
    }

    // MARK: - Bnnn: Jump to V0 + nnn

    func testOpBnnn_jumps() async {
        await load(0xB100)
        await machine.setRegister(0, 0x10)
        await machine.step()
        let pc = await machine.pc
        XCTAssertEqual(pc, 0x110)
    }

    // MARK: - Cxkk: Set Vx = rand & kk

    func testOpCxkk_masksRandom() async {
        await load(0xC00F)
        await machine.step()
        let reg0 = await machine.registers[0]
        XCTAssertEqual(reg0 & 0xF0, 0, "Upper nibble must be zero due to mask")
    }

    func testOpCxkk_zeroMaskAlwaysProducesZero() async {
        await load(0xC000)
        await machine.setRegister(0, 0xFF)
        await machine.step()
        let reg0 = await machine.registers[0]
        XCTAssertEqual(reg0, 0)
    }

    // MARK: - Dxyn: Draw sprite

    func testOpDxyn_drawsSprite() async {
        await load(0xD001)
        await machine.setI(0x300)
        await machine.setMemoryByte(0x300, 0xFF)
        await machine.setRegister(0, 0)
        await machine.setRegister(1, 0)
        await machine.step()
        let video = await machine.video
        for col in 0..<8 {
            XCTAssertEqual(video[col], 1, "Pixel at column \(col) should be on")
        }
        let regF = await machine.registers[0xF]
        XCTAssertEqual(regF, 0)
    }

    func testOpDxyn_detectsCollision() async {
        await load(0xD001)
        await machine.setI(0x300)
        await machine.setMemoryByte(0x300, 0xFF)
        await machine.setRegister(0, 0)
        await machine.setRegister(1, 0)
        await machine.setVideo(0, 1)
        await machine.step()
        let regF = await machine.registers[0xF]
        XCTAssertEqual(regF, 1)
    }

    func testOpDxyn_XORsExistingPixels() async {
        await load(0xD001)
        await machine.setI(0x300)
        await machine.setMemoryByte(0x300, 0xFF)
        await machine.setRegister(0, 0)
        await machine.setRegister(1, 0)
        for col in 0..<8 { await machine.setVideo(col, 1) }
        await machine.step()
        let video = await machine.video
        for col in 0..<8 {
            XCTAssertEqual(video[col], 0, "Pixel at column \(col) should be off after XOR")
        }
        let regF = await machine.registers[0xF]
        XCTAssertEqual(regF, 1)
    }

    // MARK: - Ex9E: Skip if key Vx is pressed

    func testOpEx9E_skipsWhenKeyPressed() async {
        await load(0xE09E)
        await machine.setRegister(0, 5)
        await machine.setKeyboard(5, true)
        await machine.step()
        let pc = await machine.pc
        XCTAssertEqual(pc, startPC + 4)
    }

    func testOpEx9E_noSkipWhenKeyNotPressed() async {
        await load(0xE09E)
        await machine.setRegister(0, 5)
        await machine.setKeyboard(5, false)
        await machine.step()
        let pc = await machine.pc
        XCTAssertEqual(pc, startPC + 2)
    }

    // MARK: - ExA1: Skip if key Vx is NOT pressed

    func testOpExA1_skipsWhenKeyNotPressed() async {
        await load(0xE0A1)
        await machine.setRegister(0, 3)
        await machine.setKeyboard(3, false)
        await machine.step()
        let pc = await machine.pc
        XCTAssertEqual(pc, startPC + 4)
    }

    func testOpExA1_noSkipWhenKeyPressed() async {
        await load(0xE0A1)
        await machine.setRegister(0, 3)
        await machine.setKeyboard(3, true)
        await machine.step()
        let pc = await machine.pc
        XCTAssertEqual(pc, startPC + 2)
    }

    // MARK: - Fx07: Set Vx = delay timer value

    func testOpFx07_readsDelayTimer() async {
        await load(0xF007)
        await machine.setDelayTimer(42)
        await machine.step()
        let reg0 = await machine.registers[0]
        XCTAssertEqual(reg0, 42)
    }

    // MARK: - Fx0A: Wait for key press

    func testOpFx0A_loopsWhenNoKeyPressed() async {
        await load(0xF00A)
        await machine.step()
        let pc = await machine.pc
        XCTAssertEqual(pc, startPC)
    }

    func testOpFx0A_storesKeyAndLoopsUntilRelease() async {
        await load(0xF00A)
        await machine.setKeyboard(7, true)
        await machine.step()
        let reg0 = await machine.registers[0]
        let pc = await machine.pc
        XCTAssertEqual(reg0, 7)
        XCTAssertEqual(pc, startPC)
    }

    func testOpFx0A_advancesAfterKeyRelease() async {
        await load(0xF00A)
        await machine.setKeyDown(true)
        await machine.step()
        let pc = await machine.pc
        XCTAssertEqual(pc, startPC + 2)
    }

    // MARK: - Fx15: Set delay timer = Vx

    func testOpFx15_setsDelayTimer() async {
        await load(0xF015)
        await machine.setRegister(0, 60)
        await machine.step()
        let timer = await machine.delayTimer
        XCTAssertEqual(timer, 60)
    }

    // MARK: - Fx18: Set sound timer = Vx

    func testOpFx18_setsSoundTimer() async {
        await load(0xF018)
        await machine.setRegister(0, 10)
        await machine.step()
        let timer = await machine.soundTimer
        XCTAssertEqual(timer, 10)
    }

    // MARK: - Fx1E: Set I += Vx

    func testOpFx1E_incrementsI() async {
        await load(0xF01E)
        await machine.setI(0x100)
        await machine.setRegister(0, 0x10)
        await machine.step()
        let i = await machine.i
        XCTAssertEqual(i, 0x110)
    }

    // MARK: - Fx29: Set I = address of small font sprite for digit Vx

    func testOpFx29_pointsToSmallFontDigit0() async {
        await load(0xF029)
        await machine.setRegister(0, 0)
        await machine.step()
        let i = await machine.i
        XCTAssertEqual(i, 0x50)
    }

    func testOpFx29_pointsToCorrectDigit() async {
        await load(0xF029)
        await machine.setRegister(0, 3)
        await machine.step()
        let i = await machine.i
        XCTAssertEqual(i, 0x50 + 5 * 3)
    }

    // MARK: - Fx30: Set I = address of big font sprite for digit Vx

    func testOpFx30_pointsToBigFontDigit0() async {
        await load(0xF030)
        await machine.setRegister(0, 0)
        await machine.step()
        let i = await machine.i
        XCTAssertEqual(i, 0xA0)
    }

    func testOpFx30_pointsToCorrectBigDigit() async {
        await load(0xF030)
        await machine.setRegister(0, 2)
        await machine.step()
        let i = await machine.i
        XCTAssertEqual(i, 0xA0 + 10 * 2)
    }

    // MARK: - Fx33: Store BCD representation of Vx

    func testOpFx33_storesBCD() async {
        await load(0xF033)
        await machine.setI(0x300)
        await machine.setRegister(0, 234)
        await machine.step()
        let memory = await machine.memory
        XCTAssertEqual(memory[0x300], 2)
        XCTAssertEqual(memory[0x301], 3)
        XCTAssertEqual(memory[0x302], 4)
    }

    func testOpFx33_storesBCD_singleDigit() async {
        await load(0xF033)
        await machine.setI(0x300)
        await machine.setRegister(0, 7)
        await machine.step()
        let memory = await machine.memory
        XCTAssertEqual(memory[0x300], 0)
        XCTAssertEqual(memory[0x301], 0)
        XCTAssertEqual(memory[0x302], 7)
    }

    // MARK: - Fx55: Store V0 through Vx in memory

    func testOpFx55_storesRegisters() async {
        await load(0xF355)
        await machine.setI(0x300)
        await machine.setRegister(0, 0xAA)
        await machine.setRegister(1, 0xBB)
        await machine.setRegister(2, 0xCC)
        await machine.setRegister(3, 0xDD)
        await machine.step()
        let memory = await machine.memory
        XCTAssertEqual(memory[0x300], 0xAA)
        XCTAssertEqual(memory[0x301], 0xBB)
        XCTAssertEqual(memory[0x302], 0xCC)
        XCTAssertEqual(memory[0x303], 0xDD)
    }

    func testOpFx55_incrementsI_whenEnabled() async {
        await load(0xF255)
        await machine.setI(0x300)
        await machine.setIncrementI(true)
        await machine.step()
        let i = await machine.i
        XCTAssertEqual(i, 0x300 + 3)
    }

    func testOpFx55_preservesI_whenDisabled() async {
        await load(0xF255)
        await machine.setI(0x300)
        await machine.setIncrementI(false)
        await machine.step()
        let i = await machine.i
        XCTAssertEqual(i, 0x300)
    }

    // MARK: - Fx65: Read V0 through Vx from memory

    func testOpFx65_loadsRegisters() async {
        await load(0xF365)
        await machine.setI(0x300)
        await machine.setMemoryByte(0x300, 0x11)
        await machine.setMemoryByte(0x301, 0x22)
        await machine.setMemoryByte(0x302, 0x33)
        await machine.setMemoryByte(0x303, 0x44)
        await machine.step()
        let regs = await machine.registers
        XCTAssertEqual(regs[0], 0x11)
        XCTAssertEqual(regs[1], 0x22)
        XCTAssertEqual(regs[2], 0x33)
        XCTAssertEqual(regs[3], 0x44)
    }

    func testOpFx65_incrementsI_whenEnabled() async {
        await load(0xF265)
        await machine.setI(0x300)
        await machine.setIncrementI(true)
        await machine.step()
        let i = await machine.i
        XCTAssertEqual(i, 0x300 + 3)
    }

    // MARK: - Fx75: Store V0 through Vx in HP48 registers

    func testOpFx75_storesInHP48() async {
        await load(0xF275)
        await machine.setRegister(0, 0x10)
        await machine.setRegister(1, 0x20)
        await machine.setRegister(2, 0x30)
        await machine.step()
        let hp48 = await machine.hp48
        XCTAssertEqual(hp48[0], 0x10)
        XCTAssertEqual(hp48[1], 0x20)
        XCTAssertEqual(hp48[2], 0x30)
    }

    func testOpFx75_doesNotStoreToMemory() async {
        await load(0xF075)
        await machine.setI(0x300)
        await machine.setRegister(0, 0xAB)
        await machine.step()
        let hp48 = await machine.hp48
        let memory = await machine.memory
        XCTAssertEqual(hp48[0], 0xAB)
        XCTAssertEqual(memory[0x300], 0)
    }

    // MARK: - Fx85: Read V0 through Vx from HP48 registers

    func testOpFx85_loadsFromHP48() async {
        await machine.loadProgram([0xF2, 0x75, 0xF2, 0x85])
        await machine.setRegister(0, 0xAA)
        await machine.setRegister(1, 0xBB)
        await machine.setRegister(2, 0xCC)
        await machine.step()
        // Clear registers
        await machine.setRegister(0, 0)
        await machine.setRegister(1, 0)
        await machine.setRegister(2, 0)
        // Step Fx85 to load back
        await machine.step()
        let regs = await machine.registers
        XCTAssertEqual(regs[0], 0xAA)
        XCTAssertEqual(regs[1], 0xBB)
        XCTAssertEqual(regs[2], 0xCC)
    }

    func testOpFx85_doesNotReadFromMemory() async {
        // Fx85 reads from hp48, not from memory[I]
        // First store a known value to HP48 via Fx75
        await machine.loadProgram([0xF0, 0x75, 0xF0, 0x85])
        await machine.setRegister(0, 0x42)
        await machine.step() // Fx75: store V0 to hp48[0]
        await machine.setRegister(0, 0x00) // clear register
        await machine.setI(0x300)
        await machine.setMemoryByte(0x300, 0xFF)
        await machine.step() // Fx85: load from hp48[0]
        let reg0 = await machine.registers[0]
        XCTAssertEqual(reg0, 0x42)
    }

    // MARK: - 00Cx: Scroll display down x rows

    func testOp00Cx_scrollsDown() async {
        await load(0x00C2)
        for col in 0..<64 { await machine.setVideo(col, 1) }
        await machine.step()
        let video = await machine.video
        for idx in 0..<128 {
            XCTAssertEqual(video[idx], 0, "Index \(idx) should be empty after scroll")
        }
        for col in 0..<64 {
            XCTAssertEqual(video[128 + col], 1, "Column \(col) of row 2 should have row 0's content")
        }
    }

    // MARK: - 00FB: Scroll display right 4 pixels

    func testOp00FB_scrollsRight() async {
        await machine.setDisplayType(.extended)
        await load(0x00FB)
        await machine.setVideo(0, 1)
        await machine.setVideo(1, 1)
        await machine.setVideo(2, 1)
        await machine.setVideo(3, 1)
        await machine.step()
        let video = await machine.video
        XCTAssertEqual(video[0], 0)
        XCTAssertEqual(video[1], 0)
        XCTAssertEqual(video[2], 0)
        XCTAssertEqual(video[3], 0)
        XCTAssertEqual(video[4], 1)
        XCTAssertEqual(video[5], 1)
        XCTAssertEqual(video[6], 1)
        XCTAssertEqual(video[7], 1)
    }

    // MARK: - 00FC: Scroll display left 4 pixels

    func testOp00FC_scrollsLeft() async {
        await machine.setDisplayType(.extended)
        await load(0x00FC)
        await machine.setVideo(4, 1)
        await machine.setVideo(5, 1)
        await machine.setVideo(6, 1)
        await machine.setVideo(7, 1)
        await machine.step()
        let video = await machine.video
        XCTAssertEqual(video[0], 1)
        XCTAssertEqual(video[1], 1)
        XCTAssertEqual(video[2], 1)
        XCTAssertEqual(video[3], 1)
    }

    // MARK: - 00FD: Exit (halt by looping the PC)

    func testOp00FD_halts() async {
        await load(0x00FD)
        await machine.step()
        let pc = await machine.pc
        XCTAssertEqual(pc, startPC)
    }

    // MARK: - 00FE: Switch to standard display mode

    func testOp00FE_setsStandardMode() async {
        await machine.setDisplayType(.extended)
        await load(0x00FE)
        await machine.step()
        let dt = await machine.displayType
        XCTAssertEqual(dt, .standard)
    }

    // MARK: - 00FF: Switch to extended display mode

    func testOp00FF_setsExtendedMode() async {
        await load(0x00FF)
        await machine.step()
        let dt = await machine.displayType
        XCTAssertEqual(dt, .extended)
    }
}
