import AVFoundation
import Combine
import Accelerate

class AudioManager: ObservableObject {
    @Published var audioLevel: Float = 0.0
    @Published var isRecording = false
    @Published var permissionGranted = false
    @Published var frequencyBands: [Float] = Array(repeating: 0, count: 32)  // 32 frequency bands for spectrum

    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?

    // Thread-safe state accessed from audio processing thread
    private let stateQueue = DispatchQueue(label: "com.sound.audiostate")
    private var _noiseFloorEstimate: Float = 0.0
    private var _currentAudioLevel: Float = 0.0
    private var _smoothedBands: [Float] = Array(repeating: 0, count: 32)

    private let smoothingFactor: Float = 0.85
    private let bandSmoothingFactor: Float = 0.6  // Faster response for bars

    // FFT setup
    private let fftSize: Int = 1024
    private let log2n: vDSP_Length
    private var fftSetup: FFTSetup?
    private var window: [Float] = []
    private var realBuffer: [Float] = []
    private var imagBuffer: [Float] = []
    private var magnitudes: [Float] = []
    private var fftBuffer: [Float] = []  // Buffer for accumulating samples
    private var fftBufferIndex: Int = 0

    // Reusable buffers for filtering to avoid allocations
    private var filterBuffer1: [Float] = []
    private var filterBuffer2: [Float] = []
    private var filterBuffer3: [Float] = []
    private var filterBuffer4: [Float] = []

    init() {
        self.log2n = vDSP_Length(log2(Float(fftSize)))
        self.fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))

        // Hann window for FFT
        self.window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))

        self.realBuffer = [Float](repeating: 0, count: fftSize / 2)
        self.imagBuffer = [Float](repeating: 0, count: fftSize / 2)
        self.magnitudes = [Float](repeating: 0, count: fftSize / 2)
        self.fftBuffer = [Float](repeating: 0, count: fftSize)
    }

    deinit {
        cleanup()
        if let setup = fftSetup {
            vDSP_destroy_fftsetup(setup)
        }
    }

    func requestPermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                self?.permissionGranted = granted
                if granted {
                    print("Microphone permission granted")
                } else {
                    print("Microphone permission denied")
                }
            }
        }
    }

    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        guard permissionGranted else {
            print("Cannot start recording: permission not granted")
            return
        }

        do {
            let audioSession = AVAudioSession.sharedInstance()
            // Use playAndRecord with defaultToSpeaker so YouTube audio plays
            // through the speaker while the mic captures it for visualization
            try audioSession.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers]
            )
            try audioSession.setActive(true)

            let engine = AVAudioEngine()
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)

            // Install tap to process audio in real-time
            input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
                self?.processAudioBuffer(buffer)
            }

            try engine.start()

            audioEngine = engine
            inputNode = input
            isRecording = true

        } catch {
            print("Failed to start recording: \(error.localizedDescription)")
            cleanup()
        }
    }

    private func stopRecording() {
        cleanup()

        isRecording = false
        audioLevel = 0.0
        frequencyBands = Array(repeating: 0, count: 32)

        stateQueue.sync {
            _noiseFloorEstimate = 0.0
            _currentAudioLevel = 0.0
            _smoothedBands = Array(repeating: 0, count: 32)
        }

        fftBufferIndex = 0
    }

    private func cleanup() {
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        inputNode = nil

        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("Failed to deactivate audio session: \(error.localizedDescription)")
        }
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }

        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }

        let samples = UnsafeBufferPointer(start: channelData[0], count: frameLength)

        // Resize reusable buffers if needed
        if filterBuffer1.count != frameLength {
            filterBuffer1 = [Float](repeating: 0, count: frameLength)
            filterBuffer2 = [Float](repeating: 0, count: frameLength)
            filterBuffer3 = [Float](repeating: 0, count: frameLength)
            filterBuffer4 = [Float](repeating: 0, count: frameLength)
        }

        // Copy samples to working buffer
        for i in 0..<frameLength {
            filterBuffer1[i] = samples[i]
        }

        let sampleRate = buffer.format.sampleRate

        // Apply high-pass filter to remove low-frequency rumble (lawn mower)
        // Breathing is typically 200-500 Hz, whispers are 2000-8000 Hz
        applyHighPassFilterInPlace(samples: &filterBuffer1, output: &filterBuffer2, cutoff: 300.0, sampleRate: sampleRate)

        // Apply band-pass emphasis for breathing/whisper range
        // (low-pass at 8000Hz then high-pass at 250Hz)
        applyLowPassFilterInPlace(samples: &filterBuffer2, output: &filterBuffer3, cutoff: 8000.0, sampleRate: sampleRate)
        applyHighPassFilterInPlace(samples: &filterBuffer3, output: &filterBuffer4, cutoff: 250.0, sampleRate: sampleRate)

        // Calculate RMS (Root Mean Square) for amplitude
        var rms: Float = 0.0
        vDSP_rmsqv(filterBuffer4, 1, &rms, vDSP_Length(frameLength))

        // Validate RMS to prevent NaN/Infinity propagation
        if !rms.isFinite {
            rms = 0.0
        }

        // Thread-safe state updates
        let smoothed: Float = stateQueue.sync {
            // Adaptive noise gate - learn and subtract background noise floor
            if _noiseFloorEstimate == 0.0 {
                _noiseFloorEstimate = rms * 0.5
            } else {
                _noiseFloorEstimate = _noiseFloorEstimate * 0.99 + rms * 0.01
            }

            // Subtract noise floor and amplify
            let signalAboveNoise = max(0, rms - _noiseFloorEstimate * 1.2)
            let amplified = signalAboveNoise * 80.0
            let newLevel = min(1.0, amplified)

            // Smooth using thread-safe current level
            _currentAudioLevel = _currentAudioLevel * smoothingFactor + newLevel * (1.0 - smoothingFactor)
            return _currentAudioLevel
        }

        // Compute frequency spectrum using FFT
        let bandLevels = computeFrequencyBands(samples: samples, frameLength: frameLength, sampleRate: sampleRate)

        DispatchQueue.main.async { [weak self] in
            self?.audioLevel = smoothed
            if let bands = bandLevels {
                self?.frequencyBands = bands
            }
        }
    }

    // Compute frequency band magnitudes from samples
    private func computeFrequencyBands(samples: UnsafeBufferPointer<Float>, frameLength: Int, sampleRate: Double) -> [Float]? {
        guard let fftSetup = fftSetup else { return nil }

        // Accumulate samples into FFT buffer
        var samplesProcessed = 0
        while samplesProcessed < frameLength {
            let remainingFftSpace = fftSize - fftBufferIndex
            let remainingSamples = frameLength - samplesProcessed
            let toCopy = min(remainingFftSpace, remainingSamples)

            for i in 0..<toCopy {
                fftBuffer[fftBufferIndex + i] = samples[samplesProcessed + i]
            }
            fftBufferIndex += toCopy
            samplesProcessed += toCopy

            // If buffer full, perform FFT
            if fftBufferIndex >= fftSize {
                performFFT(sampleRate: sampleRate)
                fftBufferIndex = 0
            }
        }

        return stateQueue.sync { _smoothedBands }
    }

    private func performFFT(sampleRate: Double) {
        guard let fftSetup = fftSetup else { return }

        // Apply Hann window
        var windowed = [Float](repeating: 0, count: fftSize)
        vDSP_vmul(fftBuffer, 1, window, 1, &windowed, 1, vDSP_Length(fftSize))

        // Pack real signal into split complex format
        var splitComplex = DSPSplitComplex(realp: &realBuffer, imagp: &imagBuffer)
        windowed.withUnsafeBufferPointer { ptr in
            ptr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: fftSize / 2) { complexPtr in
                vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(fftSize / 2))
            }
        }

        // Perform forward FFT
        vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))

        // Compute magnitudes
        vDSP_zvabs(&splitComplex, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))

        // Normalize magnitudes
        var scale: Float = 1.0 / Float(fftSize)
        vDSP_vsmul(magnitudes, 1, &scale, &magnitudes, 1, vDSP_Length(fftSize / 2))

        // Map FFT bins to logarithmically-spaced bands (low freqs on left, high on right)
        // Audible range we care about: 80 Hz (low) to 8000 Hz (high)
        let numberOfBands = 32
        let minFreq: Double = 80
        let maxFreq: Double = 8000
        let nyquist = sampleRate / 2.0
        let binSize = nyquist / Double(fftSize / 2)

        var newBands = [Float](repeating: 0, count: numberOfBands)

        for band in 0..<numberOfBands {
            // Logarithmic frequency spacing
            let lowFreq = minFreq * pow(maxFreq / minFreq, Double(band) / Double(numberOfBands))
            let highFreq = minFreq * pow(maxFreq / minFreq, Double(band + 1) / Double(numberOfBands))

            let lowBin = max(1, Int(lowFreq / binSize))
            let highBin = min(fftSize / 2 - 1, Int(highFreq / binSize))

            guard lowBin <= highBin else { continue }

            // Sum magnitudes in this band
            var bandMagnitude: Float = 0
            for bin in lowBin...highBin {
                bandMagnitude += magnitudes[bin]
            }

            // Average and normalize
            let binCount = Float(highBin - lowBin + 1)
            let avgMagnitude = bandMagnitude / binCount

            // Apply log scaling for better visualization (decibels-like)
            // Amplify quiet sounds, compress loud sounds
            let scaled = log10(1.0 + avgMagnitude * 1000) / 3.0
            newBands[band] = min(1.0, max(0, scaled))
        }

        // Smooth bands and update thread-safe state
        stateQueue.sync {
            for i in 0..<numberOfBands {
                _smoothedBands[i] = _smoothedBands[i] * bandSmoothingFactor + newBands[i] * (1.0 - bandSmoothingFactor)
            }
        }
    }

    // Simple high-pass IIR filter to remove low-frequency noise (in-place version)
    private func applyHighPassFilterInPlace(samples: inout [Float], output: inout [Float], cutoff: Double, sampleRate: Double) {
        guard !samples.isEmpty, sampleRate > 0 else { return }

        let rc = 1.0 / (cutoff * 2.0 * .pi)
        let dt = 1.0 / sampleRate
        let alpha = Float(rc / (rc + dt))

        var prevInput: Float = 0
        var prevOutput: Float = 0

        for i in 0..<samples.count {
            output[i] = alpha * (prevOutput + samples[i] - prevInput)
            prevInput = samples[i]
            prevOutput = output[i]
        }
    }

    // Simple low-pass IIR filter (in-place version)
    private func applyLowPassFilterInPlace(samples: inout [Float], output: inout [Float], cutoff: Double, sampleRate: Double) {
        guard !samples.isEmpty, sampleRate > 0 else { return }

        let rc = 1.0 / (cutoff * 2.0 * .pi)
        let dt = 1.0 / sampleRate
        let alpha = Float(dt / (rc + dt))

        output[0] = samples[0]

        for i in 1..<samples.count {
            output[i] = output[i-1] + alpha * (samples[i] - output[i-1])
        }
    }
}
