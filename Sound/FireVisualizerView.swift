import SwiftUI

// Each flame source has its own characteristics for variety
struct FlameSource: Identifiable {
    let id: Int
    let xPosition: CGFloat            // Horizontal position (0 to 1, fraction of screen)
    let frequencyBandIndex: Int       // Which frequency band drives this flame
    let baseHeight: CGFloat           // Min flame height multiplier
    let heightMultiplier: CGFloat     // How much it scales with sound
    let particleSizeMultiplier: CGFloat
    let phaseOffset: Double           // Animation phase offset for natural variety
    let hueOffset: Double              // Slight color variation
    var currentHeight: CGFloat = 0    // Current animated height
    var currentLevel: Float = 0       // Current sound level for this flame
}

// ViewModel that owns the fire simulation
class FireSimulation: ObservableObject {
    @Published var particles: [FireParticle] = []
    @Published var flameSources: [FlameSource] = []

    var frequencyBands: [Float] = []
    var screenSize: CGSize = .zero

    private var lastUpdateTime = Date()
    private var animationTimer: Timer?
    private var nextParticleId: Int = 0
    private var elapsedTime: TimeInterval = 0

    private let frameInterval: TimeInterval = 1.0 / 60.0
    private let maxDeltaTime: TimeInterval = 0.05
    private let minFlameHeight: CGFloat = 50    // Birthday candle size
    private let particleLifetime: TimeInterval = 1.5
    private let numberOfFlameSources = 16  // More flames to map to frequencies better

    deinit {
        stopAnimation()
    }

    func startAnimation(in size: CGSize) {
        screenSize = size
        initializeFlameSources()

        guard animationTimer == nil else { return }

        lastUpdateTime = Date()
        animationTimer = Timer.scheduledTimer(withTimeInterval: frameInterval, repeats: true) { [weak self] _ in
            self?.updateFire()
        }
    }

    func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }

    func updateScreenSize(_ size: CGSize) {
        screenSize = size
        if flameSources.isEmpty {
            initializeFlameSources()
        }
    }

    private func initializeFlameSources() {
        // Distribute flame sources across the bottom
        // Map each flame to a specific frequency band
        // Total bands available: 32 (from AudioManager)
        // Left side (low index) = low frequencies, Right side (high index) = high frequencies
        let numberOfBands = 32

        flameSources = (0..<numberOfFlameSources).map { i in
            // Even distribution across the screen
            let basePosition = (CGFloat(i) + 0.5) / CGFloat(numberOfFlameSources)
            let jitter = CGFloat.random(in: -0.01...0.01)

            // Map flame index to frequency band index
            // Spread the flames across all 32 bands
            let bandIndex = Int(Double(i) / Double(numberOfFlameSources) * Double(numberOfBands))

            return FlameSource(
                id: i,
                xPosition: max(0.04, min(0.96, basePosition + jitter)),
                frequencyBandIndex: min(numberOfBands - 1, bandIndex),
                baseHeight: CGFloat.random(in: 0.85...1.15),
                heightMultiplier: CGFloat.random(in: 0.85...1.2),
                particleSizeMultiplier: CGFloat.random(in: 0.9...1.1),
                phaseOffset: Double.random(in: 0...(Double.pi * 2)),
                hueOffset: Double.random(in: -0.02...0.02)
            )
        }
    }

    private func updateFire() {
        let currentTime = Date()
        let rawDeltaTime = currentTime.timeIntervalSince(lastUpdateTime)
        let deltaTime = min(rawDeltaTime, maxDeltaTime)
        lastUpdateTime = currentTime
        elapsedTime += deltaTime

        guard screenSize.height > 0, screenSize.width > 0, !flameSources.isEmpty else { return }

        let maxFlameHeight = screenSize.height * 0.95

        // Update each flame source's current height based on its frequency band
        for i in 0..<flameSources.count {
            let source = flameSources[i]

            // Get the level for this flame's frequency band (with fallback)
            let bandLevel: Float
            if source.frequencyBandIndex < frequencyBands.count {
                // Average with adjacent bands for smoother transitions between flames
                var levels: [Float] = []
                let bandIdx = source.frequencyBandIndex
                if bandIdx > 0 && bandIdx - 1 < frequencyBands.count {
                    levels.append(frequencyBands[bandIdx - 1] * 0.5)
                }
                levels.append(frequencyBands[bandIdx])
                if bandIdx + 1 < frequencyBands.count {
                    levels.append(frequencyBands[bandIdx + 1] * 0.5)
                }
                bandLevel = levels.reduce(0, +) / Float(levels.count)
            } else {
                bandLevel = 0
            }

            flameSources[i].currentLevel = bandLevel

            // Natural flicker using sine waves
            let flicker1 = sin(elapsedTime * 8.0 + source.phaseOffset) * 0.06
            let flicker2 = sin(elapsedTime * 13.0 + source.phaseOffset * 1.3) * 0.04
            let flicker3 = sin(elapsedTime * 21.0 + source.phaseOffset * 0.7) * 0.02
            let flicker = flicker1 + flicker2 + flicker3

            // Apply this flame's frequency band level
            let levelForThisFlame = min(1.0, max(0, CGFloat(bandLevel) * source.heightMultiplier + CGFloat(flicker)))

            let baseFlameHeight = minFlameHeight * source.baseHeight
            let targetHeight = baseFlameHeight + levelForThisFlame * (maxFlameHeight - baseFlameHeight)

            // Smooth transitions but allow quick response
            flameSources[i].currentHeight = flameSources[i].currentHeight * 0.78 + targetHeight * 0.22
        }

        // Spawn particles for each flame source
        var updatedParticles = particles
        let cgDeltaTime = CGFloat(deltaTime)

        for source in flameSources {
            let baseX = source.xPosition * screenSize.width
            let baseY = screenSize.height - 15

            // Particle spawn rate scales with this flame's level and height
            let heightFactor = source.currentHeight / minFlameHeight
            let baseParticleRate = 8.0 * Double(heightFactor)
            let extraParticleRate = Double(source.currentLevel) * 40.0 * Double(source.heightMultiplier)
            let particlesPerFrame = (baseParticleRate + extraParticleRate) * deltaTime

            var particlesToSpawn = Int(particlesPerFrame)
            if Double.random(in: 0...1) < (particlesPerFrame - Double(particlesToSpawn)) {
                particlesToSpawn += 1
            }

            for _ in 0..<particlesToSpawn {
                // Spawn at the base with slight horizontal spread
                let spreadFactor = 1 + CGFloat(source.currentLevel) * 1.5
                let xJitter = CGFloat.random(in: -8...8) * spreadFactor
                let yJitter = CGFloat.random(in: -3...3)

                // Upward velocity scales with desired flame height
                let speedFactor = max(1.0, source.currentHeight / 80)
                let upwardSpeed = CGFloat.random(in: 100...180) * speedFactor
                let sideDrift = CGFloat.random(in: -20...20) * (1 + CGFloat(source.currentLevel))

                let particleSize = CGFloat.random(in: 12...28) * source.particleSizeMultiplier

                updatedParticles.append(FireParticle(
                    id: nextParticleId,
                    sourceId: source.id,
                    x: baseX + xJitter,
                    y: baseY + yJitter,
                    velocityX: sideDrift,
                    velocityY: -upwardSpeed,
                    age: 0,
                    maxAge: particleLifetime * Double.random(in: 0.6...1.3),
                    size: particleSize,
                    hue: Double.random(in: 0.0...0.10) + source.hueOffset
                ))
                nextParticleId += 1
            }
        }

        // Update all existing particles
        for i in 0..<updatedParticles.count {
            updatedParticles[i].age += deltaTime
            updatedParticles[i].x += updatedParticles[i].velocityX * cgDeltaTime
            updatedParticles[i].y += updatedParticles[i].velocityY * cgDeltaTime

            // Particles slow down (air resistance)
            updatedParticles[i].velocityY *= 0.985
            updatedParticles[i].velocityX *= 0.96

            // Buoyancy - heat makes them rise faster
            updatedParticles[i].velocityY -= 50 * cgDeltaTime

            // Horizontal flicker for realistic flame movement
            // Use the source flame's level for individual flicker intensity
            let sourceLevel: Float
            if let source = flameSources.first(where: { $0.id == updatedParticles[i].sourceId }) {
                sourceLevel = source.currentLevel
            } else {
                sourceLevel = 0
            }
            let flickerStrength: CGFloat = 25 + CGFloat(sourceLevel) * 50
            updatedParticles[i].velocityX += CGFloat.random(in: -flickerStrength...flickerStrength) * cgDeltaTime
        }

        // Remove dead particles or those that have risen above their flame's height
        updatedParticles.removeAll { particle in
            // Find the source flame
            guard let source = flameSources.first(where: { $0.id == particle.sourceId }) else {
                return true
            }
            let flameTop = screenSize.height - source.currentHeight
            return particle.age >= particle.maxAge || particle.y < flameTop - 80
        }

        // Limit total particle count for performance
        if updatedParticles.count > 800 {
            updatedParticles.removeFirst(updatedParticles.count - 800)
        }

        particles = updatedParticles
    }
}

struct FireParticle: Identifiable, Equatable {
    let id: Int
    let sourceId: Int
    var x: CGFloat
    var y: CGFloat
    var velocityX: CGFloat
    var velocityY: CGFloat
    var age: TimeInterval
    let maxAge: TimeInterval
    let size: CGFloat
    let hue: Double

    var lifeProgress: Double {
        min(1.0, age / maxAge)
    }

    var opacity: Double {
        let progress = lifeProgress
        // Quick fade in, slow fade out
        if progress < 0.1 {
            return progress / 0.1
        } else if progress < 0.5 {
            return 1.0
        } else {
            return 1.0 - ((progress - 0.5) / 0.5)
        }
    }

    var currentSize: CGFloat {
        let progress = CGFloat(lifeProgress)
        // Particles grow quickly then slowly shrink
        if progress < 0.2 {
            return size * (0.4 + progress / 0.2 * 0.6)
        } else {
            return size * (1.0 - (progress - 0.2) * 0.5)
        }
    }

    var color: Color {
        let progress = lifeProgress

        // Realistic fire color progression:
        // Start: white-yellow (very hot, base of flame)
        // Middle: orange (medium heat)
        // End: red, then dark red (cooling)

        let saturation: Double
        let brightness: Double
        let currentHue: Double

        if progress < 0.15 {
            // White-hot center
            saturation = 0.3 + progress / 0.15 * 0.4
            brightness = 1.0
            currentHue = 0.13  // Yellow
        } else if progress < 0.5 {
            // Yellow to orange
            let t = (progress - 0.15) / 0.35
            saturation = 0.7 + t * 0.25
            brightness = 1.0 - t * 0.05
            currentHue = 0.13 - t * 0.05  // Yellow to orange
        } else {
            // Orange to deep red, then fade
            let t = (progress - 0.5) / 0.5
            saturation = 0.95 - t * 0.2
            brightness = 0.95 - t * 0.5
            currentHue = max(0.0, 0.08 - t * 0.08 + hue)  // Orange to red
        }

        return Color(hue: currentHue, saturation: saturation, brightness: brightness)
    }
}

struct FireVisualizerView: View {
    let frequencyBands: [Float]
    @StateObject private var simulation = FireSimulation()

    // Calculate average level for ambient glow
    private var averageLevel: Double {
        guard !frequencyBands.isEmpty else { return 0 }
        let sum = frequencyBands.reduce(0, +)
        return Double(sum / Float(frequencyBands.count))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                // Glowing base across the entire bottom
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.orange.opacity(0.0),
                                Color.orange.opacity(0.3 + 0.4 * averageLevel),
                                Color.red.opacity(0.5 + 0.4 * averageLevel)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 100)
                    .position(x: geometry.size.width / 2, y: geometry.size.height - 50)
                    .blur(radius: 20)

                // Per-flame glow at each source base
                ForEach(simulation.flameSources) { source in
                    Ellipse()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color.orange.opacity(0.8),
                                    Color.red.opacity(0.4),
                                    Color.clear
                                ]),
                                center: .center,
                                startRadius: 0,
                                endRadius: 60
                            )
                        )
                        .frame(width: 80, height: 40)
                        .position(
                            x: source.xPosition * geometry.size.width,
                            y: geometry.size.height - 15
                        )
                        .blur(radius: 6)
                }

                // Fire particles - rendered with additive blending for realistic glow
                ForEach(simulation.particles) { particle in
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    particle.color.opacity(particle.opacity),
                                    particle.color.opacity(particle.opacity * 0.6),
                                    particle.color.opacity(0)
                                ]),
                                center: .center,
                                startRadius: 0,
                                endRadius: particle.currentSize / 2
                            )
                        )
                        .frame(width: particle.currentSize, height: particle.currentSize)
                        .position(x: particle.x, y: particle.y)
                        .blur(radius: 3)
                        .blendMode(.plusLighter)  // Additive blending for realistic fire glow
                }

                // Wood/log base across the bottom
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.3, green: 0.15, blue: 0.05),
                                Color(red: 0.15, green: 0.07, blue: 0.02),
                                Color.black
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 30)
                    .position(x: geometry.size.width / 2, y: geometry.size.height - 5)
            }
            .onAppear {
                simulation.frequencyBands = frequencyBands
                simulation.startAnimation(in: geometry.size)
            }
            .onDisappear {
                simulation.stopAnimation()
            }
            .onChange(of: geometry.size) { newSize in
                simulation.updateScreenSize(newSize)
            }
            .onChange(of: frequencyBands) { newBands in
                simulation.frequencyBands = newBands
            }
        }
    }
}
