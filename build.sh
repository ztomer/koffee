#!/bin/bash
set -e

echo "Building Koffee..."
xcodegen generate
xcodebuild -project Koffee.xcodeproj -scheme Koffee -configuration Debug build
echo "Build complete!"
