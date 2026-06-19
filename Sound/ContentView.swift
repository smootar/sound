import SwiftUI

struct ContentView: View {
    @StateObject private var audioManager = AudioManager()
    @State private var selectedAnimation: AnimationType = .sunGlow
    @State private var showAnimationPicker = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Display selected animation with smooth transitions
            Group {
                switch selectedAnimation {
                case .sunGlow:
                    SunGlowVisualizerView(audioLevel: audioManager.audioLevel)
                        .transition(.opacity)
                case .balls:
                    BallsVisualizerView(audioLevel: audioManager.audioLevel)
                        .transition(.opacity)
                case .fire:
                    FireVisualizerView(frequencyBands: audioManager.frequencyBands)
                        .transition(.opacity)
                case .line:
                    LineVisualizerView(audioLevel: audioManager.audioLevel)
                        .transition(.opacity)
                case .bars:
                    BarsVisualizerView(frequencyBands: audioManager.frequencyBands)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: selectedAnimation)

            VStack {
                // Animation selector at top
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showAnimationPicker.toggle()
                        }
                    }) {
                        HStack {
                            Image(systemName: "sparkles")
                            Text(selectedAnimation.rawValue)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.25))
                        .cornerRadius(20)
                    }
                    .accessibilityLabel("Choose animation type")
                    .accessibilityValue(selectedAnimation.rawValue)
                    .padding(.trailing, 20)
                }
                .padding(.top, 10)

                Spacer()

                Text("Sound Game")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding()

                Text(String(format: "Level: %.2f", audioManager.audioLevel))
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.9))
                    .accessibilityLabel("Audio level")
                    .accessibilityValue(String(format: "%.0f percent", audioManager.audioLevel * 100))
                    .padding(.bottom, 20)

                Button(action: {
                    audioManager.toggleRecording()
                }) {
                    HStack {
                        Image(systemName: audioManager.isRecording ? "mic.fill" : "mic.slash.fill")
                            .font(.title2)
                        Text(audioManager.isRecording ? "Stop" : "Start")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 15)
                    .background(
                        audioManager.isRecording ? Color.red : Color.green
                    )
                    .cornerRadius(30)
                }
                .accessibilityLabel(audioManager.isRecording ? "Stop recording" : "Start recording")
                .padding(.bottom, 50)
            }

            // Animation picker sheet with smooth transition
            if showAnimationPicker {
                animationPickerOverlay
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .onAppear {
            audioManager.requestPermission()
        }
    }

    private var animationPickerOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showAnimationPicker = false
                    }
                }

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 0) {
                    Text("Choose Animation")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.35))

                    ForEach(AnimationType.allCases) { animationType in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                selectedAnimation = animationType
                                showAnimationPicker = false
                            }
                        }) {
                            HStack {
                                Text(animationType.rawValue)
                                    .foregroundColor(.white)
                                    .font(.title3)
                                Spacer()
                                if selectedAnimation == animationType {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding()
                            .background(Color.gray.opacity(0.2))
                        }
                        .accessibilityLabel(animationType.rawValue)
                        .accessibilityHint(selectedAnimation == animationType ? "Currently selected" : "Tap to select")

                        Divider()
                            .background(Color.gray.opacity(0.3))
                    }

                    Button("Cancel") {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showAnimationPicker = false
                        }
                    }
                    .foregroundColor(.blue)
                    .font(.title3)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.2))
                }
                .background(Color(white: 0.15))
                .cornerRadius(16)
                .padding()
            }
        }
    }
}
