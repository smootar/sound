# Sound

A SwiftUI iOS app that visualizes microphone input through multiple sound-reactive animations. Filters out background noise and responds to breathing, whispers, voice, and music.

## Features

### 🎨 Five Animations
1. **Sun Glow** - Pulsing sun with rotating gradient bars
2. **Balls** - Bouncing balls that react to sound intensity
3. **Fire** - 16 frequency-mapped flames (low frequencies on left, high on right)
4. **Line** - Heart monitor / EKG style line visualizer
5. **Bars** - Frequency spectrum analyzer with 32 bands

### 🎤 Audio Processing
- Real-time microphone capture via `AVAudioEngine`
- High-pass + band-pass filtering (250 Hz - 8000 Hz) to filter out background noise like lawn mowers
- Adaptive noise floor learning
- 1024-sample FFT analysis with Hann windowing
- 32 logarithmic frequency bands (80 Hz - 8000 Hz)

## Project Structure

```
Sound/
├── SoundApp.swift              # App entry point
├── ContentView.swift           # Main view with animation switcher
├── AudioManager.swift          # Microphone capture, filtering, FFT
├── AnimationType.swift         # Animation enum
├── SunGlowVisualizerView.swift # Sun Glow animation
├── BallsVisualizerView.swift   # Bouncing balls animation
├── FireVisualizerView.swift    # Frequency-reactive fire
├── LineVisualizerView.swift    # Heart monitor line
├── BarsVisualizerView.swift    # Frequency spectrum bars
├── Info.plist                  # Microphone permissions
└── Assets.xcassets/            # App icon and colors
```

## Setup

1. Open `Sound.xcodeproj` in Xcode
2. Select your development team in Signing & Capabilities
3. Choose target device or simulator
4. Build and run (`Cmd+R`)
5. Grant microphone permission when prompted

## Requirements

- iOS 15.0+
- Xcode 13.0+
- Swift 5.5+

## How It Works

1. **Microphone** captures audio in real-time via `AVAudioEngine`
2. **DSP Pipeline** applies high-pass and band-pass IIR filters to isolate human voice frequencies
3. **Adaptive Noise Gate** continuously learns and subtracts background noise
4. **FFT Analysis** computes frequency spectrum across 32 logarithmic bands
5. **Visualizations** render in real-time using SwiftUI, driven by audio level and frequency data

## Privacy

Microphone access is required and explained in the permission prompt. Audio is processed locally on the device and never transmitted or stored.
