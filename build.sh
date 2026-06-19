#!/bin/bash

# Build script for Sound app

echo "Building Sound app..."

xcodebuild -project Sound.xcodeproj \
    -scheme Sound \
    -configuration Debug \
    -destination 'platform=iOS Simulator,name=iPhone 15' \
    clean build

echo "Build complete!"
