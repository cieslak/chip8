@preconcurrency import AVFoundation
import os

nonisolated final class ToneGenerator: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?

    private struct RenderState: Sendable {
        var phase: Float = 0
        var vibratoPhase: Float = 0
        var sampleRate: Double = 48_000
        var elapsedSamples: Int = 0
    }

    private let renderState = OSAllocatedUnfairLock(initialState: RenderState())

    init() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [])
        try session.setActive(true)

        let output = engine.outputNode
        let hwFormat = output.outputFormat(forBus: 0)
        renderState.withLock { $0.sampleRate = hwFormat.sampleRate }

        let sampleRate = hwFormat.sampleRate

        guard let monoFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw NSError(domain: "ToneGenerator", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create format"])
        }

        let state = renderState
        let node = AVAudioSourceNode(format: monoFormat) { _, _, frameCount, audioBufferList -> OSStatus in
            state.withLockUnchecked { s in
                let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
                let twoPi = Float.pi * 2
                let rate = Float(s.sampleRate)

                let meowDuration = Int(rate * 0.45)
                let gapDuration = Int(rate * 0.15)
                let cycleDuration = meowDuration + gapDuration

                for frame in 0..<Int(frameCount) {
                    let posInCycle = s.elapsedSamples % cycleDuration
                    let t = Float(posInCycle) / Float(meowDuration)
                    let inMeow = posInCycle < meowDuration

                    var sample: Float = 0

                    if inMeow {
                        let freq: Float
                        if t < 0.4 {
                            freq = 800 - 350 * (t / 0.4)
                        } else {
                            freq = 450 + 150 * ((t - 0.4) / 0.6)
                        }

                        let vibrato = sin(s.vibratoPhase) * 15
                        s.vibratoPhase += twoPi * 5.5 / rate
                        if s.vibratoPhase >= twoPi { s.vibratoPhase -= twoPi }

                        let phaseInc = twoPi * (freq + vibrato) / rate
                        s.phase += phaseInc
                        if s.phase >= twoPi { s.phase -= twoPi }

                        let env: Float
                        if t < 0.05 {
                            env = t / 0.05
                        } else if t < 0.7 {
                            env = 1.0
                        } else {
                            env = max(0, (1.0 - t) / 0.3)
                        }

                        let fundamental = sin(s.phase)
                        let harmonic2 = 0.3 * sin(s.phase * 2)
                        let harmonic3 = 0.15 * sin(s.phase * 3)
                        sample = (fundamental + harmonic2 + harmonic3) * env * 0.18
                    }

                    s.elapsedSamples += 1

                    for buffer in abl {
                        if let mData = buffer.mData {
                            let ptr = mData.assumingMemoryBound(to: Float.self)
                            ptr[frame] = sample
                        }
                    }
                }
            }
            return noErr
        }

        sourceNode = node
        engine.attach(node)
        engine.connect(node, to: output, format: monoFormat)
    }

    func start() throws {
        renderState.withLock { s in
            s.phase = 0
            s.vibratoPhase = 0
            s.elapsedSamples = 0
        }
        try engine.start()
    }

    func stop() {
        engine.stop()
    }
}
