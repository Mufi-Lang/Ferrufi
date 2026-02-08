#!/bin/bash
# Ferrufi Linux Build Script
# Uses Docker to build the project for Linux

set -e

# Change to project root if script is run from scripts/
cd "$(dirname "$0")"/..

echo "🐳 Building Ferrufi for Linux using Official Apple Swift Container..."

if command -v docker-compose &> /dev/null
then
    COMPOSE_CMD="docker-compose"
elif docker compose version &> /dev/null
then
    COMPOSE_CMD="docker compose"
else
    echo "❌ error: Docker Compose not found. Please install it to run Linux builds."
    exit 1
fi

# Build the docker image
$COMPOSE_CMD build builder

# We clean first to avoid version mismatch errors from shared volumes
$COMPOSE_CMD run --rm builder swift package clean
$COMPOSE_CMD run --rm builder swift build

echo "✅ Linux build complete! Binaries are in .build/ (Linux format)."
