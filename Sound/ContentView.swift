import SwiftUI

struct ContentView: View {
    @StateObject private var audioManager = AudioManager()
    @State private var selectedAnimation: AnimationType = .sunGlow
    @State private var showAnimationPicker = false
    @State private var showYouTubePicker = false
    @State private var youtubeVideoID: String = ""
    @State private var showYouTubePlayer = false

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

            VStack(spacing: 0) {
                // Top toolbar with YouTube and animation buttons
                HStack {
                    // YouTube toggle button
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            if showYouTubePlayer {
                                // Hide player
                                showYouTubePlayer = false
                                youtubeVideoID = ""
                            } else {
                                // Show URL picker
                                showYouTubePicker = true
                            }
                        }
                    }) {
                        HStack {
                            Image(systemName: showYouTubePlayer ? "xmark" : "play.rectangle.fill")
                            Text(showYouTubePlayer ? "Close" : "YouTube")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(showYouTubePlayer ? Color.red.opacity(0.7) : Color.white.opacity(0.25))
                        .cornerRadius(20)
                    }
                    .accessibilityLabel(showYouTubePlayer ? "Close YouTube video" : "Open YouTube video")

                    Spacer()

                    // Animation selector
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
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)

                // YouTube player (when active)
                if showYouTubePlayer && !youtubeVideoID.isEmpty {
                    YouTubePlayerView(videoID: youtubeVideoID)
                        .frame(height: 220)
                        .cornerRadius(12)
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

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

            // Animation picker overlay
            if showAnimationPicker {
                animationPickerOverlay
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            // YouTube URL picker overlay
            if showYouTubePicker {
                youtubePickerOverlay
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

    private var youtubePickerOverlay: some View {
        YouTubePickerOverlay(
            isPresented: $showYouTubePicker,
            onSelect: { videoID in
                youtubeVideoID = videoID
                showYouTubePlayer = true
                // Automatically start mic recording so visualizations react
                if !audioManager.isRecording {
                    audioManager.toggleRecording()
                }
            }
        )
    }
}

// Separated to keep ContentView body type-checkable
struct YouTubePickerOverlay: View {
    @Binding var isPresented: Bool
    let onSelect: (String) -> Void

    @State private var urlInput: String = ""
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { close() }

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Watch a Video")
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                        Button(action: close) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.35))

                    // URL input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Paste YouTube URL")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))

                        HStack {
                            TextField("https://youtube.com/watch?v=...", text: $urlInput)
                                .textFieldStyle(.plain)
                                .foregroundColor(.white)
                                .padding(10)
                                .background(Color.black.opacity(0.4))
                                .cornerRadius(8)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)

                            Button(action: playFromInput) {
                                Image(systemName: "play.fill")
                                    .foregroundColor(.white)
                                    .padding(10)
                                    .background(Color.blue)
                                    .cornerRadius(8)
                            }
                            .disabled(urlInput.isEmpty)
                        }

                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }

                        Text("Tip: some videos block embedding. If you see \"Video unavailable\", try a different video.")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.5))
                            .padding(.top, 4)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.2))
                }
                .background(Color(white: 0.15))
                .cornerRadius(16)
                .padding()
            }
        }
    }

    private func playFromInput() {
        if let id = YouTubeURLParser.extractVideoID(from: urlInput) {
            errorMessage = nil
            onSelect(id)
            close()
        } else {
            errorMessage = "Couldn't read that link. Try a youtube.com/watch?v=... or youtu.be/... URL."
        }
    }

    private func close() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isPresented = false
        }
    }
}
