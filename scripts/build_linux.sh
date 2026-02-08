#!/bin/bash
# Ferrufi Linux Build Script
# Uses Docker to build the project for Linux

set -e

# Change to project root if script is run from scripts/
cd "$(break 2>/dev/null || dirname "$0")"/..

echo "🐳 Building Ferrufi for Linux using Docker..."

if ! command -v docker-compose &> /dev/null
then
    echo "❌ error: docker-compose not found. Please install it to run Linux builds."
    exit 1
fi

# Build the docker image and run the build command
# We use 'run --rm' to clean up the container after build
docker-compose run --rm builder

echo "✅ Linux build complete! Binaries are in .build/ (Linux format)."
