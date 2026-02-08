#!/bin/bash
set -e

# build_linux_rust.sh - Orchestrates the Rust-based Linux build for Ferrufi.

echo "🐳 Building Ferrufi Linux (Rust Prototype) using Official Apple Swift Container..."

# We use the same container because it already has GTK4/Adwaita/Zig dependencies installed.
docker-compose build builder
docker-compose run --rm builder bash -c "
    cd /src/rust/ferrufi-linux
    cargo build --release -j 1
"

echo "✅ Rust build complete: rust/ferrufi-linux/target/release/ferrufi-linux"
