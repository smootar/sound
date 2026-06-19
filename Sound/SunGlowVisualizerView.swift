import SwiftUI

struct SunGlowVisualizerView: View {
    let audioLevel: Float
    @State private var phase: CGFloat = 0
    @State private var animationTimer: Timer?

    private let numberOfBars = 12
    private let twoPi: CGFloat = .pi * 2

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Outer pulsing circle
                Circle()
                    .stroke(
                        Color.blue.opacity(0.3),
                        lineWidth: 3
                    )
                    .frame(
                        width: baseSize(geometry) * CGFloat(1 + audioLevel * 2),
                        height: baseSize(geometry) * CGFloat(1 + audioLevel * 2)
                    )
                    .blur(radius: 10)

                // Middle circle
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color.purple.opacity(0.6),
                                Color.blue.opacity(0.3),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: max(1, baseSize(geometry) / 2)
                        )
                    )
                    .frame(
                        width: baseSize(geometry) * CGFloat(1 + audioLevel),
                        height: baseSize(geometry) * CGFloat(1 + audioLevel)
                    )

                // Animated bars around center
                ForEach(0..<numberOfBars, id: \.self) { index in
                    BarView(
                        audioLevel: audioLevel,
                        angle: Angle(degrees: Double(index) * 360.0 / Double(numberOfBars)),
                        radius: baseSize(geometry) / 2.5,
                        phase: phase
                    )
                }

                // Center core
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.cyan,
                                Color.blue
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .scaleEffect(CGFloat(1 + audioLevel * 0.5))
                    .shadow(color: .cyan, radius: 20 * CGFloat(audioLevel))
            }
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .onAppear {
            startAnimationIfNeeded()
        }
        .onDisappear {
            stopAnimation()
        }
    }

    private func baseSize(_ geometry: GeometryProxy) -> CGFloat {
        max(1, min(geometry.size.width, geometry.size.height) * 0.6)
    }

    private func startAnimationIfNeeded() {
        guard animationTimer == nil else { return }

        let timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            withAnimation(.linear(duration: 0.05)) {
                // Wrap phase to prevent unbounded growth
                phase = (phase + 0.1).truncatingRemainder(dividingBy: twoPi)
            }
        }
        animationTimer = timer
    }

    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
}

struct BarView: View {
    let audioLevel: Float
    let angle: Angle
    let radius: CGFloat
    let phase: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.cyan,
                        Color.purple
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(
                width: 6,
                height: max(5, 20 + CGFloat(audioLevel) * 80 + sin(phase + angle.radians) * 20)
            )
            .offset(y: -radius)
            .rotationEffect(angle)
    }
}
