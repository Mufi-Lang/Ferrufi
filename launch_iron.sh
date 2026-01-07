#!/bin/bash

# Iron Note-Taking App Launcher
# Builds and launches the Iron knowledge management application

set -e

echo "🔧 Building Iron..."
swift build

echo "🚀 Launching Iron..."
echo "   Notes directory: ~/.iron/notes"
echo "   Press Ctrl+C to quit"
echo ""

# Launch the app
swift run IronApp

echo ""
echo "👋 Iron has closed"
