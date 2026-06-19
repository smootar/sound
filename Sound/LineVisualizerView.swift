import SwiftUI

// ViewModel that manages the heart monitor line simulation
class LineSimulation: ObservableObject {
    @Published var samples: [CGFloat] = []  // Y-offsets from center (rolling buffer)

    var audioLevel: Float = 0.0
    var screenSize: CGSize = .zero

    private var lastUpdateTime = Date()
    private var animationTimer: Timer?
    private var pulsePhase: Double = 0
    private var nextPulseTrigger: Float = 0.05

    private let frameInterval: TimeInterval = 1.0 / 60.0
    private let maxDeltaTime: TimeInterval = 0.05
    private let scrollSpeed: CGFloat = 200    // Pixels per second
    private let sampleSpacing: CGFloat = 2     // Pixels between samples

    deinit {
        stopAnimation()
    }

    func startAnimation(in size: CGSize) {
        screenSize = size
        initializeSamples()

        guard animationTimer == nil else { return }

        lastUpdateTime = Date()
        animationTimer = Timer.scheduledTimer(withTimeInterval: frameInterval, repeats: true) { [weak self] _ in
            self?.updateLine()
        }
    }

    func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }

    func updateScreenSize(_ size: CGSize) {
        screenSize = size
        initializeSamples()
    }

    private func initializeSamples() {
        guard screenSize.width > 0 else { return }
        let count = Int(screenSize.width / sampleSpacing) + 2
        samples = Array(repeating: 0, count: count)
    }

    private func updateLine() {
        let currentTime = Date()
        let rawDeltaTime = currentTime.timeIntervalSince(lastUpdateTime)
        let deltaTime = min(rawDeltaTime, maxDeltaTime)
        lastUpdateTime = currentTime

        guard !samples.isEmpty, screenSize.width > 0 else { return }

        let currentAudioLevel = audioLevel
        pulsePhase += deltaTime

        // Calculate how many samples to scroll
        let pixelsToScroll = scrollSpeed * CGFloat(deltaTime)
        let samplesToShift = Int(pixelsToScroll / sampleSpacing)

        guard samplesToShift > 0 else { return }

        // Generate new samples for the right edge
        var newSamples: [CGFloat] = []
        let maxAmplitude = screenSize.height * 0.4

        for _ in 0..<samplesToShift {
            let yOffset = generateNextSample(
                audioLevel: currentAudioLevel,
                maxAmplitude: maxAmplitude
            )
            newSamples.append(yOffset)
        }

        // Shift the samples array (remove from front, append to back)
        var updatedSamples = samples
        updatedSamples.removeFirst(min(samplesToShift, updatedSamples.count))
        updatedSamples.append(contentsOf: newSamples)

        // Ensure correct count
        let targetCount = Int(screenSize.width / sampleSpacing) + 2
        while updatedSamples.count < targetCount {
            updatedSamples.append(0)
        }
        if updatedSamples.count > targetCount {
            updatedSamples = Array(updatedSamples.suffix(targetCount))
        }

        samples = updatedSamples
    }

    private func generateNextSample(audioLevel: Float, maxAmplitude: CGFloat) -> CGFloat {
        // Below threshold - flat line with very subtle noise
        if audioLevel < 0.01 {
            return CGFloat.random(in: -0.3...0.3)
        }

        // Generate heart-monitor style spikes based on audio level
        // Mix of sine waves and random spikes for organic EKG look
        let level = CGFloat(audioLevel)

        // Base wave - smooth oscillation that scales with level
        let baseFreq1 = sin(pulsePhase * 12.0) * level * maxAmplitude * 0.3
        let baseFreq2 = sin(pulsePhase * 30.0) * level * maxAmplitude * 0.15

        // Random spikes - more frequent and larger with more sound
        let spikeChance = Double(level) * 0.4
        var spike: CGFloat = 0
        if Double.random(in: 0...1) < spikeChance {
            // Heart-monitor style sharp spike
            let spikeDirection: CGFloat = Bool.random() ? 1 : -1
            let spikeMagnitude = CGFloat.random(in: 0.4...1.0) * level * maxAmplitude
            spike = spikeDirection * spikeMagnitude
        }

        // High-frequency jitter for realistic noise
        let jitter = CGFloat.random(in: -1...1) * level * maxAmplitude * 0.15

        return baseFreq1 + baseFreq2 + spike + jitter
    }
}

struct LineVisualizerView: View {
    let audioLevel: Float
    @StateObject private var simulation = LineSimulation()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dark background with subtle grid
                Color(red: 0.02, green: 0.05, blue: 0.05)
                    .ignoresSafeArea()

                // Grid lines for EKG monitor look
                EKGGridView()
                    .opacity(0.15)

                // Center reference line (faint)
                Rectangle()
                    .fill(Color.green.opacity(0.1))
                    .frame(height: 1)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)

                // The animated line itself
                EKGLineShape(samples: simulation.samples, sampleSpacing: 2)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.green,
                                Color(red: 0.0, green: 1.0, blue: 0.5)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(color: .green.opacity(0.8), radius: 8)
                    .shadow(color: .green.opacity(0.5), radius: 16)

                // Bright leading dot at the right edge
                if let lastSample = simulation.samples.last {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)
                        .shadow(color: .green, radius: 10)
                        .shadow(color: .green, radius: 20)
                        .position(
                            x: geometry.size.width - 5,
                            y: geometry.size.height / 2 + lastSample
                        )
                }
            }
            .onAppear {
                simulation.startAnimation(in: geometry.size)
            }
            .onDisappear {
                simulation.stopAnimation()
            }
            .onChange(of: geometry.size) { newSize in
                simulation.updateScreenSize(newSize)
            }
            .onChange(of: audioLevel) { newLevel in
                simulation.audioLevel = newLevel
            }
        }
    }
}

// Custom shape that draws the EKG line from samples
struct EKGLineShape: Shape {
    let samples: [CGFloat]
    let sampleSpacing: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard !samples.isEmpty else { return path }

        let centerY = rect.midY

        // Start from the leftmost point
        path.move(to: CGPoint(x: 0, y: centerY + samples[0]))

        // Draw line through all samples
        for i in 1..<samples.count {
            let x = CGFloat(i) * sampleSpacing
            let y = centerY + samples[i]
            path.addLine(to: CGPoint(x: x, y: y))
        }

        return path
    }
}

// Subtle EKG grid background
struct EKGGridView: View {
    private let smallGridSize: CGFloat = 20
    private let largeGridSize: CGFloat = 100

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Small grid lines
                Path { path in
                    var x: CGFloat = 0
                    while x < geometry.size.width {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                        x += smallGridSize
                    }
                    var y: CGFloat = 0
                    while y < geometry.size.height {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                        y += smallGridSize
                    }
                }
                .stroke(Color.green.opacity(0.3), lineWidth: 0.5)

                // Larger grid lines (brighter)
                Path { path in
                    var x: CGFloat = 0
                    while x < geometry.size.width {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                        x += largeGridSize
                    }
                    var y: CGFloat = 0
                    while y < geometry.size.height {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                        y += largeGridSize
                    }
                }
                .stroke(Color.green.opacity(0.5), lineWidth: 1)
            }
        }
    }
}
