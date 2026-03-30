#!/bin/bash
set -e

# Build if needed
if [ ! -d "Koffee.xcodeproj" ]; then
	echo "Generating Xcode project..."
	xcodegen generate
fi

# Build
echo "Building Koffee..."
xcodebuild -project Koffee.xcodeproj -scheme Koffee -configuration Debug build -quiet

# Find and run the built app
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/Koffee-*/Build/Products/Debug -name "Koffee.app" 2>/dev/null | head -1)

if [ -n "$APP_PATH" ]; then
	echo "Running Koffee..."
	open "$APP_PATH"
else
	echo "Build failed - app not found"
	exit 1
fi
