@preconcurrency import AVFoundation
import os

nonisolated final class ToneGenerator: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?

    private struct RenderState: Sendable {
        var phase: Float = 0
        var frequency: Float = 600.0
        var amplitude: Float = 0.2
        var sampleRate: Double = 48_000
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
                let phaseInc = twoPi * s.frequency / Float(s.sampleRate)

                for frame in 0..<Int(frameCount) {
                    let sample = sin(s.phase) * s.amplitude
                    s.phase += phaseInc
                    if s.phase >= twoPi { s.phase -= twoPi }

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
        try engine.start()
    }

    func stop() {
        engine.stop()
    }
}
