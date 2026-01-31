import AVFoundation

final class ToneGenerator {
    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?

    private var phase: Float = 0
    private var sampleRate: Double = 48_000

    var frequency: Float = 600.0
    var amplitude: Float = 0.2   // 0.0 ... ~1.0 (keep modest to avoid clipping)

    func start() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [])
        try session.setActive(true)

        let output = engine.outputNode
        let hwFormat = output.outputFormat(forBus: 0)
        sampleRate = hwFormat.sampleRate

        // Create a mono format and let the engine mix to the output format
        guard let monoFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw NSError(domain: "ToneGenerator", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create format"])
        }

        let node = AVAudioSourceNode(format: monoFormat) { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self else { return noErr }

            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let twoPi = Float.pi * 2
            let phaseInc = twoPi * self.frequency / Float(self.sampleRate)

            for frame in 0..<Int(frameCount) {
                let sample = sin(self.phase) * self.amplitude
                self.phase += phaseInc
                if self.phase >= twoPi { self.phase -= twoPi }

                // Write the mono sample into every buffer provided (engine may request multiple)
                for buffer in abl {
                    if let mData = buffer.mData {
                        let ptr = mData.assumingMemoryBound(to: Float.self)
                        ptr[frame] = sample
                    }
                }
            }
            return noErr
        }

        sourceNode = node
        engine.attach(node)
        engine.connect(node, to: output, format: monoFormat)

        try engine.start()
    }

    func stop() {
        engine.stop()
        if let node = sourceNode {
            engine.disconnectNodeInput(engine.outputNode)
            engine.detach(node)
        }
        sourceNode = nil
        phase = 0
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}
