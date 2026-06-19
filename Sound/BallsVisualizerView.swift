import SwiftUI

// ViewModel that owns the simulation state - reference type so timer always reads latest audioLevel
class BallsSimulation: ObservableObject {
    @Published var balls: [Ball] = []

    var audioLevel: Float = 0.0  // Updated externally on every frame
    var screenSize: CGSize = .zero

    private var lastUpdateTime = Date()
    private var animationTimer: Timer?

    let numberOfBalls = 40
    let ballSize: CGFloat = 20
    private let gravity: CGFloat = 0.5
    private let minBounceVelocity: CGFloat = 150
    private let maxBounceVelocity: CGFloat = 1200
    private let frameInterval: TimeInterval = 1.0 / 60.0
    private let maxDeltaTime: TimeInterval = 0.05

    deinit {
        stopAnimation()
    }

    func initializeBalls(in size: CGSize) {
        guard size.width > ballSize * 2, size.height > ballSize * 2 else { return }
        screenSize = size

        balls = (0..<numberOfBalls).map { index in
            Ball(
                id: index,
                x: CGFloat.random(in: ballSize...(size.width - ballSize)),
                y: size.height - ballSize,
                velocityY: 0,
                color: Color(
                    hue: Double.random(in: 0...1),
                    saturation: 0.8,
                    brightness: 0.9
                )
            )
        }
    }

    func updateScreenSize(_ size: CGSize) {
        guard size.width > ballSize * 2, size.height > ballSize * 2 else { return }
        screenSize = size

        for i in 0..<balls.count {
            balls[i].x = min(max(balls[i].x, ballSize), size.width - ballSize)
            balls[i].y = min(balls[i].y, size.height - ballSize)
        }
    }

    func startAnimation() {
        guard animationTimer == nil else { return }

        lastUpdateTime = Date()
        animationTimer = Timer.scheduledTimer(withTimeInterval: frameInterval, repeats: true) { [weak self] _ in
            self?.updateBalls()
        }
    }

    func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }

    private func updateBalls() {
        let currentTime = Date()
        let rawDeltaTime = currentTime.timeIntervalSince(lastUpdateTime)
        let deltaTime = min(rawDeltaTime, maxDeltaTime)
        lastUpdateTime = currentTime

        guard !balls.isEmpty, screenSize.height > 0, screenSize.width > 0 else { return }

        // Read the current audio level (updated externally each frame)
        let currentAudioLevel = audioLevel
        let cgDeltaTime = CGFloat(deltaTime)
        let timeScale = cgDeltaTime * 60

        // Build new array to trigger SwiftUI update
        var updatedBalls = balls

        for i in 0..<updatedBalls.count {
            let isNearFloor = updatedBalls[i].y >= screenSize.height - ballSize - 50

            if currentAudioLevel > 0.01 {
                if isNearFloor {
                    let bounceChance = min(1.0, Double(currentAudioLevel) * 50.0 * deltaTime * 100)

                    if Double.random(in: 0...1) < bounceChance {
                        let bounceStrength = minBounceVelocity + (CGFloat(currentAudioLevel) * (maxBounceVelocity - minBounceVelocity))
                        updatedBalls[i].velocityY = -bounceStrength * CGFloat.random(in: 0.95...1.05)
                    }
                }
            } else {
                if isNearFloor && abs(updatedBalls[i].velocityY) < 10 {
                    updatedBalls[i].velocityY *= 0.5
                }
            }

            // Apply gravity
            updatedBalls[i].velocityY += gravity * timeScale

            // Update position
            updatedBalls[i].y += updatedBalls[i].velocityY * timeScale

            // Bounce off floor
            let floorY = screenSize.height - ballSize
            if updatedBalls[i].y >= floorY {
                updatedBalls[i].y = floorY
                updatedBalls[i].velocityY *= -0.6

                if abs(updatedBalls[i].velocityY) < 3 {
                    updatedBalls[i].velocityY = 0
                }
            }

            // Keep balls on screen
            if updatedBalls[i].y < ballSize {
                updatedBalls[i].y = ballSize
                updatedBalls[i].velocityY *= -0.5
            }
        }

        balls = updatedBalls
    }
}

struct BallsVisualizerView: View {
    let audioLevel: Float
    @StateObject private var simulation = BallsSimulation()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                ForEach(simulation.balls) { ball in
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    ball.color.opacity(0.9),
                                    ball.color.opacity(0.6)
                                ]),
                                center: .center,
                                startRadius: 0,
                                endRadius: simulation.ballSize / 2
                            )
                        )
                        .frame(width: simulation.ballSize, height: simulation.ballSize)
                        .position(x: ball.x, y: ball.y)
                        .shadow(color: ball.color.opacity(0.5), radius: 10)
                }
            }
            .onAppear {
                simulation.initializeBalls(in: geometry.size)
                simulation.startAnimation()
            }
            .onDisappear {
                simulation.stopAnimation()
            }
            .onChange(of: geometry.size) { newSize in
                simulation.updateScreenSize(newSize)
            }
            .onChange(of: audioLevel) { newLevel in
                // Push the latest audio level into the simulation
                simulation.audioLevel = newLevel
            }
        }
    }
}

struct Ball: Identifiable, Equatable {
    let id: Int
    var x: CGFloat
    var y: CGFloat
    var velocityY: CGFloat
    let color: Color
}
