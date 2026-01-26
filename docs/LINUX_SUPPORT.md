# Linux Support (Overview & Build Guide)

This document explains the current approach for supporting Ferrufi on Linux:
- GPU acceleration strategy (OpenGL, GTK + SwiftGtk).
- How to obtain and build the Mufi runtime (`libmufiz`) on Linux (automatically or manually).
- CI integration notes and helpful troubleshooting tips.

Goal
----
Make Ferrufi build and run on Linux with:
- OpenGL-based GPU acceleration (initially a minimal integration).
- GTK + SwiftGtk for the native Linux UI stack (future work).
- Automatic retrieval/build of `libmufiz` so the app can link to the native Mufi runtime.

Status
------
- A conservative, non-invasive scaffolding is in place:
  - `Metal`-based macOS code is guarded with `#if canImport(Metal)` so the codebase can be compiled on Linux.
  - A Linux `GLDeviceManager` stub (detection-only for now) is present under `Sources/Ferrufi/UI/Graphics/`.
  - A small shell helper script `scripts/build_mufiz.sh` was added to download or build `libmufiz` for the host platform.
  - A Linux CI workflow (`.github/workflows/linux-build.yml`) was added to exercise building `libmufiz` and `swift build`.
- Future work: GTK + SwiftGtk UI integration, proper OpenGL rendering via `GLArea` (GTK) or a cross-platform renderer, shader translations, and end-to-end runtime tests.

Prerequisites (dev machine / CI)
--------------------------------
On a typical Debian/Ubuntu-like host install:
- Swift toolchain that matches the package's swift-tools-version.
- A C toolchain: `build-essential`, `cmake` (optional), `pkg-config`.
- OpenGL dev libs: `libgl1-mesa-dev`, `libegl1-mesa-dev` (to compile and link GL code if needed).
- GTK dev libs (for GTK + GLArea integration): `libgtk-3-dev`.
- Optional (for building `mufiz` from source): `zig` (preferred) or `cmake`/`make` depending on upstream build system.
- Helpful utilities: `curl`, `unzip`, `wget`.

Quick start - Local build for Linux
----------------------------------
1. Clone the repository:
   ```bash
   git clone https://github.com/your-org/Ferrufi.git
   cd Ferrufi
   ```

2. Ensure system dependencies are installed (example for Ubuntu):
   ```bash
   sudo apt-get update
   sudo apt-get install -y build-essential curl git libgl1-mesa-dev libegl1-mesa-dev libgtk-3-dev pkg-config unzip
   ```

3. Acquire `libmufiz` (pick one):

   Option A - Download a prebuilt binary (fastest):
   ```bash
   export MUFIZ_PREBUILT_URL="https://example.com/releases/libmufiz-linux-x86_64.so"
   ./scripts/build_mufiz.sh
   ```
   This will download and place the file at `Sources/CMufi/libmufiz.so`.

   Option B - Build `libmufiz` from source (recommended for trustability):
   ```bash
   export MUFIZ_GIT_URL="https://github.com/your-upstream/mufiz.git"
   export MUFIZ_TAG="vX.Y.Z"        # optional, default: main
   # If mufiz builds with Zig (recommended), ensure `zig` is installed.
   ./scripts/build_mufiz.sh
   ```
   The script will attempt a Zig build (if Zig is present), CMake or Make as a fallback, and then copy the built library to `Sources/CMufi/libmufiz.so`.

   Validation (after any acquisition method):
   ```bash
   file Sources/CMufi/libmufiz.so
   ldd Sources/CMufi/libmufiz.so
   ```

4. Build Ferrufi with Swift:
   ```bash
   swift build -c debug
   # Or release:
   swift build -c release
   ```

5. Run tests (where available and applicable):
   ```bash
   swift test
   ```

Notes on `scripts/build_mufiz.sh`
---------------------------------
- Behavior:
  - If `MUFIZ_PREBUILT_URL` is set: downloads the artifact and attempts to extract / copy `libmufiz.*` into `Sources/CMufi/`.
  - Else if `MUFIZ_GIT_URL` is set: clones and attempts a build (zig, cmake/make) and searches for `libmufiz` artifacts.
- Environment variables:
  - `MUFIZ_PREBUILT_URL` — direct URL to an artifact (preferred for CI if upstream publishes binaries).
  - `MUFIZ_GIT_URL` — git repo to clone for building.
  - `MUFIZ_TAG` — branch or tag in the git repo.
  - `MUFIZ_BUILD_CMD` — build command override (if needed).
  - `MUFIZ_OUT_DIR` / `MUFIZ_LIB_NAME` — optional overrides for path/name.

CI Integration
--------------
- A Linux workflow was added: `.github/workflows/linux-build.yml`.
  - It does:
    - Checks out repo.
    - Installs common build deps (GL, GTK headers, build-essential).
    - Tries to install Zig (non-fatal).
    - Runs `scripts/build_mufiz.sh` to build or fetch `libmufiz`.
    - Runs `swift build`.
  - You can provide repository secrets:
    - `MUFIZ_PREBUILT_URL` — recommended when upstream publishes prebuilt artifacts.
    - `MUFIZ_GIT_URL` and `MUFIZ_TAG` — for building from source in CI.
  - The CI uploads `libmufiz.so` as an artifact for debugging (and can be extended to cache or publish prebuilt artifacts).

How the package links `libmufiz`
--------------------------------
- `Sources/CMufi/module.modulemap` declares `link "mufiz"` so SPM uses `-lmufiz` when linking.
- `Package.swift` includes `.unsafeFlags(["-L", "Sources/CMufi"])` so a `libmufiz.so` placed there will be found at link time.
- At runtime you must ensure the dynamic linker can find `libmufiz.so`:
  - Add the directory to `LD_LIBRARY_PATH` or set an appropriate rpath when packaging releases.
  - Example run:
    ```bash
    LD_LIBRARY_PATH=./Sources/CMufi swift run FerrufiApp
    ```

GPU acceleration (OpenGL on Linux)
----------------------------------
- Strategy:
  - Use OpenGL as the initial GPU backend on Linux (GLX/EGL).
  - Add a GTK + `GLArea` (via SwiftGtk) to create contexts and surfaces, then perform GL rendering.
  - Keep a cross-platform adapter layer to let the rest of the app request "GPU acceleration" without depending on Metal.
- Current status:
  - `GLDeviceManager` is implemented as a detection shim that checks for GL libraries (`libGL`, `libEGL`) using `dlopen`.
  - A fuller GL renderer and GTK integration is a follow-up milestone; this repo includes scaffolding to make that integration straightforward.
- How to enable GPU acceleration:
  - The UI config exposes `gpuAccelerationEnabled` (backwards-compatible alias of `metalAccelerationEnabled`).
  - On Linux, the code will use GL when `GraphicsDevice.shared.resolvedBackend` resolves to `.opengl`.

GTK + SwiftGtk plan
-------------------
- Integrate SwiftGtk as an optional dependency for Linux UI:
  - Example SPM dependency (conceptual):
    ```swift
    .package(url: "https://github.com/rhx/SwiftGtk.git", from: "4.0.0")
    ```
  - System dependencies: `libgtk-3-dev` (or appropriate GTK version).
  - Implement a Linux-specific executable target `FerrufiAppLinux` or add conditional compilation so `FerrufiApp` can run on both macOS (SwiftUI) and Linux (GTK) UI backends.
- Rendering:
  - Use GTK's `GLArea` (or similar) to create GL contexts and call into OpenGL-based renderers that mirror the existing Metal renderer's responsibilities.
  - Consider shader format conversions (Metal Shaders → GLSL or SPIR-V) or maintain separate GLSL shader sources for Linux renderers.

libmufiz: fetch vs build
------------------------
- We should prefer a repeatable, auditable flow:
  1. CI builds `libmufiz` from upstream source using Zig (or another buildsystem) and publishes an artifact (recommended for security & reproducibility).
  2. CI can also cache/publish prebuilt artifacts for release packaging.
- Options:
  - Download prebuilt artifact (fastest for CI).
  - Build from source in CI (more trustworthy).
  - Use release assets from upstream (if available) as a shortcut.
- Recommendation:
  - Add CI job to build mufiz on Linux and upload the produced `libmufiz.so` as a build artifact or store it in a release asset for downstream jobs.

Troubleshooting
---------------
- `libmufiz.so` missing error:
  - Ensure `Sources/CMufi/libmufiz.so` exists.
  - Run `./scripts/build_mufiz.sh` (set `MUFIZ_GIT_URL` if needed).
- `dlopen` / GL detection fails:
  - Ensure `libGL` is installed: `ldconfig -p | grep libGL`
  - On Ubuntu: `sudo apt-get install libgl1-mesa-dev`
- Zig build issues:
  - Install Zig or provide a prebuilt artifact.
  - Confirm upstream build instructions (project may require additional flags).
- Swift toolchain issues:
  - Ensure the Swift toolchain on CI/machine matches the `swift-tools-version` in `Package.swift`.
  - Install official releases of Swift for Ubuntu or use a container with Swift preinstalled.

Security & Supply Chain
-----------------------
- Prefer building `libmufiz` from source in CI for reproducibility and security.
- If using prebuilt binaries, only use trusted sources or verify checksums/signatures.
- Document the exact upstream commit/tag used to build the library in CI (store as artifact or release notes).

Next steps (recommended)
------------------------
1. Implement a GTK + SwiftGtk frontend (Linux-targeted executable).
2. Complete GL renderer that maps core Metal renderers to OpenGL (or rewrite GPU renderers cross-platform).
3. Add CI job that builds libmufiz for multiple Linux targets and stores released artifacts.
4. Add integration tests that call `mufiz_init` and `mufiz_interpret` on Linux in CI to validate runtime behavior.
5. Add packaging step to create a Linux tarball / deb / snap that bundles `libmufiz.so` and sets correct rpath.

Appendix: Example commands (summary)
-----------------------------------
```bash
# System deps (example for Ubuntu)
sudo apt-get install -y build-essential curl git libgl1-mesa-dev libegl1-mesa-dev libgtk-3-dev pkg-config unzip

# Build or download libmufiz
MUFIZ_PREBUILT_URL="https://example.com/libmufiz.so" ./scripts/build_mufiz.sh
# or
MUFIZ_GIT_URL="https://github.com/your-upstream/mufiz.git" MUFIZ_TAG="vX.Y.Z" ./scripts/build_mufiz.sh

# Validate library
file Sources/CMufi/libmufiz.so
ldd Sources/CMufi/libmufiz.so

# Build Ferrufi
swift build -c release

# Run (ensure loader can find libmufiz)
LD_LIBRARY_PATH=./Sources/CMufi swift run FerrufiApp
```

Contact / Notes
----------------
If you want, I can:
- Implement a minimal GTK + GLArea example (a small Linux-only UI target) to prove out GL integration.
- Add the Zig build step in CI that builds `libmufiz` and caches/releases the artifact.
- Add more detailed guidance to support additional distros (Fedora, Arch, etc.) and packaging instructions (deb/rpm/snap).

This file is intended as living documentation — I'll update it as we add real GL rendering, GTK UI components, and a robust CI pipeline for `libmufiz`.