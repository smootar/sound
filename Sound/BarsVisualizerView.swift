import SwiftUI

struct BarsVisualizerView: View {
    let frequencyBands: [Float]

    private let barSpacing: CGFloat = 4
    private let bottomPadding: CGFloat = 40
    private let topPadding: CGFloat = 60

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dark background with subtle gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.1),
                        Color.black
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // Bars
                HStack(alignment: .bottom, spacing: barSpacing) {
                    ForEach(0..<frequencyBands.count, id: \.self) { index in
                        FrequencyBar(
                            level: frequencyBands[index],
                            colorPosition: Double(index) / Double(max(1, frequencyBands.count - 1)),
                            availableHeight: geometry.size.height - topPadding - bottomPadding
                        )
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, bottomPadding)
                .frame(maxHeight: .infinity, alignment: .bottom)

                // Frequency labels at the bottom
                VStack {
                    Spacer()
                    HStack {
                        Text("LOW")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                            .fontWeight(.semibold)
                        Spacer()
                        Text("HIGH")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
            }
        }
    }
}

struct FrequencyBar: View {
    let level: Float
    let colorPosition: Double  // 0.0 (left/low) to 1.0 (right/high)
    let availableHeight: CGFloat

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Spacer(minLength: 0)

                // The actual bar - bouncing rectangle
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                topColor,
                                middleColor,
                                bottomColor
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(
                        width: geometry.size.width,
                        height: max(4, CGFloat(level) * availableHeight)
                    )
                    .shadow(color: bottomColor.opacity(0.6), radius: 4)
            }
        }
    }

    // Color based on horizontal position (low=blue/purple, high=red/orange)
    private var bottomColor: Color {
        Color(
            hue: 0.6 - colorPosition * 0.6,  // Blue (0.6) → Red (0.0)
            saturation: 0.9,
            brightness: 0.9
        )
    }

    private var middleColor: Color {
        Color(
            hue: 0.6 - colorPosition * 0.6,
            saturation: 0.85,
            brightness: 1.0
        )
    }

    private var topColor: Color {
        Color(
            hue: 0.6 - colorPosition * 0.6,
            saturation: 0.5,
            brightness: 1.0
        )
    }
}
