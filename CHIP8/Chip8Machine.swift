//
//  File.swift
//  CHIP8
//
//  Created by Chris Cieslak on 1/29/26.
//

import Foundation
import UIKit

protocol Chip8DisplayDelegate: AnyObject {
    func update(video: [UInt8])
}

class Chip8Machine {
    weak var display: Chip8DisplayDelegate?
    var shiftVXVY = false
    var incrementI = false
    var registers = [UInt8](repeating: 0, count: 16)
    var pc: UInt16 = 0
    var memory = [UInt8](repeating: 0, count: 4096)
    var i: UInt16 = 0
    var stack = [UInt16](repeating: 0, count: 16)
    var sp: UInt8 = 0
    var video = [UInt8](repeating: 0, count: 64 * 32)
    var opcode: UInt16 = 0
    var delayTimer: UInt8 = 0
    var soundTimer: UInt8 = 0 {
        willSet {
            if soundTimer == 0 && newValue > 0 {
                try? toneGenerator?.start()
            } else if newValue == 0 {
                toneGenerator?.stop()
            }
        }
    }
    var keyboard = [Bool](repeating: false, count: 16)
    var keyDown = false
    let font: [UInt8] = [
        0xF0, 0x90, 0x90, 0x90, 0xF0, // 0
        0x20, 0x60, 0x20, 0x20, 0x70, // 1
        0xF0, 0x10, 0xF0, 0x80, 0xF0, // 2
        0xF0, 0x10, 0xF0, 0x10, 0xF0, // 3
        0x90, 0x90, 0xF0, 0x10, 0x10, // 4
        0xF0, 0x80, 0xF0, 0x10, 0xF0, // 5
        0xF0, 0x80, 0xF0, 0x90, 0xF0, // 6
        0xF0, 0x10, 0x20, 0x40, 0x40, // 7
        0xF0, 0x90, 0xF0, 0x90, 0xF0, // 8
        0xF0, 0x90, 0xF0, 0x10, 0xF0, // 9
        0xF0, 0x90, 0xF0, 0x90, 0x90, // A
        0xE0, 0x90, 0xE0, 0x90, 0xE0, // B
        0xF0, 0x80, 0x80, 0x80, 0xF0, // C
        0xE0, 0x90, 0x90, 0x90, 0xE0, // D
        0xF0, 0x80, 0xF0, 0x80, 0xF0, // E
        0xF0, 0x80, 0xF0, 0x80, 0x80  // F
    ]
    let startAddress = 0x200
    let instructionQueue = DispatchQueue(label: "com.chip8.cpu")
    var instructionTimer: DispatchSourceTimer?
    var displayLink: CADisplayLink?
    let toneGenerator: ToneGenerator?
    
    init() {
        self.toneGenerator = try? ToneGenerator()
        let url = Bundle.main.url(forResource: "6-keypad", withExtension: "ch8")!
        try! load(url: url)
        self.pc = UInt16(startAddress)
    }
    
    func reset() {
        registers = [UInt8](repeating: 0, count: 16)
        pc = 0
        memory = [UInt8](repeating: 0, count: 4096)
        i = 0
        stack = [UInt16](repeating: 0, count: 16)
        sp = 0
        video = [UInt8](repeating: 0, count: 64 * 32)
        opcode = 0
        delayTimer = 0
        soundTimer = 0
        memory.replaceSubrange(0x50...0x9f, with: font)
    }
    
    func load(url: URL) throws {
        let data = try Data(contentsOf: url)
        var bytes = Array<UInt8>(repeating: 0, count: data.count / MemoryLayout<UInt8>.stride)
        _ = bytes.withUnsafeMutableBytes { data.copyBytes(to: $0) }
        self.memory.replaceSubrange(startAddress..<startAddress + bytes.count, with: bytes)
    }
    
    func start() {
        instructionTimer = DispatchSource.makeTimerSource(queue: instructionQueue)
        instructionTimer?.schedule(deadline: .now(), repeating: .milliseconds(2))
        instructionTimer?.setEventHandler {
            self.step()
        }
        instructionTimer?.resume()
        createDisplayLink()
    }
    
    func createDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(updateUI))
        displayLink?.add(to: .current, forMode: .default)
    }
    
    @objc func updateUI(displayLink: CADisplayLink) {
        self.display?.update(video: self.video)
        self.updateTimers()
    }
    
    func stop() {
        instructionTimer?.cancel()
        instructionTimer = nil
        displayLink?.remove(from: .current, forMode: .default)
        displayLink = nil
        reset()
    }
    
    func updateTimers() {
        if soundTimer > 0 {
            soundTimer = soundTimer - 1
        }
        if delayTimer > 0 {
            delayTimer = delayTimer - 1
        }
    }
    
    func randomByte() -> UInt8 {
        return UInt8.random(in: 0...255)
    }
    
    func op00E0() {
        video = [UInt8](repeating: 0, count: 64 * 32)
    }
    
    func op00EE() {
        sp = sp - 1
        pc = stack[Int(sp)]
    }
    
    func op1nnn() {
        //print("loading opcode \(String(opcode, radix: 16)) jump to \(String(opcode & 0x0fff, radix: 16))")
        pc = opcode & 0x0fff
    }
    
    func op2nnn() {
        let address = opcode & 0x0fff
        stack[Int(sp)] = pc
        sp = sp + 1
        pc = address
    }
    
    func op3xkk() {
        let vx = Int((opcode & 0x0F00) >> 8)
        let byte = opcode & 0x00FF
        if registers[vx] == byte {
            pc = pc + 2
        }
    }
    
    func op4xkk() {
        let vx = Int((opcode & 0x0F00) >> 8)
        let byte = opcode & 0x00FF
        if registers[vx] != byte {
            pc = pc + 2
        }
    }
    
    func op5xy0() {
        let vx = Int((opcode & 0x0F00) >> 8)
        let vy = Int((opcode & 0x00F0) >> 4)
        if registers[vx] == registers[vy] {
            pc = pc + 2
        }
    }
    
    func op6xkk() {
        let vx = Int((opcode & 0x0F00) >> 8)
        let byte = opcode & 0x00FF
        //print("loading opcode \(String(opcode, radix: 16)) \(String(byte, radix: 16)) into vx \(vx)")
        registers[vx] = UInt8(byte)
    }
    
    func op7xkk() {
        let vx = Int((opcode & 0x0F00) >> 8)
        let byte = opcode & 0x00FF
        registers[vx] = registers[vx] &+ UInt8(byte)
    }
    
    func op8xy0() {
        let vx = Int((opcode & 0x0F00) >> 8)
        let vy = Int((opcode & 0x00F0) >> 4)
        registers[vx] = registers[vy]
    }
    
    func op8xy1() {
        let vx = Int((opcode & 0x0F00) >> 8)
        let vy = Int((opcode & 0x00F0) >> 4)
        registers[vx] |= registers[vy]
        registers[0xF] = 0
    }
    
    func op8xy2() {
        let vx = Int((opcode & 0x0F00) >> 8)
        let vy = Int((opcode & 0x00F0) >> 4)
        registers[vx] &= registers[vy]
        registers[0xF] = 0
    }
    
    func op8xy3() {
        let vx = Int((opcode & 0x0F00) >> 8)
        let vy = Int((opcode & 0x00F0) >> 4)
        registers[vx] ^= registers[vy]
        registers[0xF] = 0
    }
    
    func op8xy4() {
        let vx = Int((opcode & 0x0F00) >> 8)
        let vy = Int((opcode & 0x00F0) >> 4)
        let (result, overflow) = registers[vx].addingReportingOverflow(registers[vy])
        registers[vx] = result
        registers[0xF] = overflow ? 1 : 0
    }
    
    func op8xy5() {
        let vx = Int((opcode & 0x0F00) >> 8)
        let vy = Int((opcode & 0x00F0) >> 4)
        let (result, overflow) = registers[vx].subtractingReportingOverflow(registers[vy])
        registers[Int(vx)] = result
        registers[0xF] = overflow ? 0 : 1
    }
    
    func op8xy6() {
        let vx = Int((opcode & 0x0F00) >> 8)
        let vy = Int((opcode & 0x00F0) >> 4)
        if shiftVXVY {
            registers[vx] = registers[vy]
        }
        let flag = registers[vx] & 0x01
        registers[vx] >>= 1
        registers[0xF] = flag
    }
    
    func op8xy7() {
        let vx = Int((opcode & 0x0F00) >> 8)
        let vy = Int((opcode & 0x00F0) >> 4)
        registers[vx] = registers[Int(vy)] &- registers[vx]
        if registers[vy] > registers[vx] {
            registers[0xF] = 1
        } else {
            registers[0xF] = 0
        }
    }
    
    func op8xye() {
        let vx = Int((opcode & 0x0F00)) >> 8
        let vy = Int((opcode & 0x00F0) >> 4)
        if shiftVXVY {
            registers[vx] = registers[vy]
        }
        let flag = (registers[vx] & 0x80) >> 7
        registers[vx] <<= 1;
        registers[0xF] = flag
    }
    
    func op9xy0() {
        let vx = Int((opcode & 0x0F00) >> 8)
        let vy = Int((opcode & 0x00F0) >> 4)
        if registers[vx] != registers[vy] {
            pc = pc + 2
        }
    }
    
    func opAnnn() {
        //print("opcode \(String(opcode, radix: 16)) loading \(String(opcode & 0x0fff, radix: 16)) into i")
        i = opcode & 0x0fff
    }
    
    func opBnnn() {
        let address = opcode & 0x0fff
        pc = UInt16(registers[0]) + address
    }
    
    func opCxkk() {
        let vx = Int((opcode & 0x0F00) >> 8)
        let byte = opcode & 0x00FF
        registers[vx] = randomByte() & UInt8(byte)
    }
    
    func opDxyn() {
        let x = Int((opcode & 0x0F00)) >> 8
        let y = Int((opcode & 0x00F0)) >> 4
        let height = Int(opcode & 0x000F)
        let vx = Int(registers[Int(x)] % 64)
        let vy = Int(registers[Int(y)] % 32)
        registers[0xF] = 0
        
        for row in 0..<height {
            let spriteRow = memory[Int(i) + row]
            for col in 0..<8 {
                if spriteRow & (0x80 >> col) != 0 {
                    if vx + col >= 64 || vy + row >= 32 {
                        continue
                    }
                    let idx = (vx + col + (vy + row) * 64) % (64 * 32)
                    if video[idx] == 1 {
                        //print("setting 0xF")
                        registers[0xF] = 1
                    }
                    //print("\(idx) was \(video[idx])")
                    video[idx] ^= 1
                    //print("\(idx) now \(video[idx])")

                }
            }
        }
    }
    
    func opEx9e() {
        let vx = Int((opcode & 0x0F00) >> 8)
        let key = Int(registers[vx])
        if keyboard[key] == true {
            pc = pc + 2
        }
    }
    
    func opExa1() {
        let vx = Int((opcode & 0x0F00) >> 8)
        let key = Int(registers[vx])
        if keyboard[key] == false {
            pc = pc + 2
        }
    }
    
    func opFx07() {
        let vx = Int((opcode & 0x0F00) >> 8)
        registers[vx] = delayTimer
    }
    
    func opFx0a() {
        let vx = Int((opcode & 0x0F00) >> 8)
        if let idx = keyboard.firstIndex(of: true) {
            keyDown = true
            registers[vx] = UInt8(idx)
            pc = pc - 2
        } else {
            if keyDown {
                keyDown = false
            } else {
                pc = pc - 2
            }
        }
    }
    
    func opFx15() {
        let vx = Int((opcode & 0x0F00) >> 8)
        delayTimer = registers[vx]
    }
    
    func opFx18() {
        let vx = Int((opcode & 0x0F00) >> 8)
        soundTimer = registers[vx]
    }
    
    func opFx1E() {
        let vx = Int((opcode & 0x0F00) >> 8)
        i = i + UInt16(registers[vx])
    }
    
    func opFx29() {
        let vx = Int((opcode & 0x0F00) >> 8)
        let digit = registers[vx]
        i = 0x50 + UInt16(5 * digit)
    }
    
    func opFx33() {
        let vx = Int((opcode & 0x0F00) >> 8)
        var value = registers[vx]
        // Ones-place
        memory[Int(i) + 2] = value % 10;
        value /= 10;
        // Tens-place
        memory[Int(i) + 1] = value % 10;
        value /= 10;
        // Hundreds-place
        memory[Int(i)] = value % 10;
    }
    
    func opFx55() {
        let vx = Int((opcode & 0x0F00) >> 8)
        for j in 0...vx {
            memory[Int(i) + j] = registers[j]
        }
        if incrementI {
            i = i + UInt16(vx) + 1
        }
    }
    
    func opFx65() {
        let vx = Int((opcode & 0x0F00) >> 8)
        for j in 0...vx {
            registers[j] = memory[Int(i) + j]
        }
        if incrementI {
            i = i + UInt16(vx) + 1
        }
    }

    func printScreen() {
        for (idx, pixel) in video.enumerated() {
            if pixel == 1 {
                print("*", terminator: "")
            } else {
                print("_", terminator: "")
            }
            if idx != 0 && idx % 64 == 0 {
                print("")
            }
        }
    }
    
    func set(key: Int, state: Bool) {
        instructionQueue.async {
            self.keyboard[key] = state
        }
    }
    
    func step() {
        let highByte = UInt16(memory[Int(pc)])
        let lowByte = UInt16(memory[Int(pc + 1)])
        opcode = UInt16(highByte) << 8 | lowByte
        pc = pc + 2
        let prefix = (opcode & 0xf000) >> 12
        switch prefix {
        case 0x0:
            if opcode == 0x00E0 {
                op00E0()
            } else if opcode == 0x00EE {
                op00EE()
            }
        case 0x1:
            op1nnn()
        case 0x2:
            op2nnn()
        case 0x3:
            op3xkk()
        case 0x4:
            op4xkk()
        case 0x5:
            op5xy0()
        case 0x6:
            op6xkk()
        case 0x7:
            op7xkk()
        case 0x8:
            let suffix = opcode & 0x000F
            switch suffix {
            case 0x0:
                op8xy0()
            case 0x1:
                op8xy1()
            case 0x2:
                op8xy2()
            case 0x3:
                op8xy3()
            case 0x4:
                op8xy4()
            case 0x5:
                op8xy5()
            case 0x6:
                op8xy6()
            case 0x7:
                op8xy7()
            case 0xE:
                op8xye()
            default:
                print("unimplemented 0x8 opcode")
            }
        case 0x9:
            op9xy0()
        case 0xA:
            opAnnn()
        case 0xB:
            opBnnn()
        case 0xC:
            opCxkk()
        case 0xD:
            opDxyn()
        case 0xE:
            let suffix = opcode & 0x00FF
            switch suffix {
            case 0x9E:
                opEx9e()
            case 0xA1:
                opExa1()
            default:
                print("unimplemented 0xe opcode")
            }
        case 0xF:
            let suffix = opcode & 0x00FF
            switch suffix {
            case 0x07:
                opFx07()
            case 0x0A:
                opFx0a()
            case 0x15:
                opFx15()
            case 0x18:
                opFx18()
            case 0x1E:
                opFx1E()
            case 0x29:
                opFx29()
            case 0x33:
                opFx33()
            case 0x55:
                opFx55()
            case 0x65:
                opFx65()
            default:
                print("unimplemented 0xF opcode")
            }
        default:
            print("unimplemented opcode: \(opcode)")
        }
    }
}
