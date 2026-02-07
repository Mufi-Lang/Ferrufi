# Gemini Guide for Ferrufi

This document provides context and instructions for Gemini (and other AI assistants) working on the Ferrufi project.

## 🚀 Project Overview

Ferrufi is a native macOS editor and lightweight IDE for the **Mufi** programming language.
- **Language:** Swift (macOS / AppKit / SwiftUI / Metal).
- **Core Runtime:** `libmufiz.dylib` (C-based runtime for Mufi).
- **Key Features:** Fast text rendering, integrated REPL, project/workspace support, and Metal-accelerated UI.

## 📂 Key Directory Structure

- `Sources/Ferrufi/`: Main Swift source code.
    - `Core/`: Core logic, models (Note, Folder), and storage services.
    - `Features/`: Major feature implementations (Editor, Mufi Runner, Linking).
    - `UI/`: SwiftUI views and components.
    - `Integrations/Mufi/`: Bridging between Swift and the Mufi C runtime.
- `Sources/CMufi/`: C headers and the `libmufiz.dylib` binary.
- `scripts/`: Shell scripts for building, installing, and testing.
- `plans/`: Detailed technical documentation.
- `Tests/`: Swift testing suites.

## 🛠 Critical Workflows

### 1. Building the App
Always use the provided scripts for building to ensure entitlements and dylibs are handled correctly.
```bash
./scripts/build_app.sh --zip
```

### 2. Testing Linking
After building, verify that the `libmufiz.dylib` is correctly linked:
```bash
./scripts/test_linking.sh
```

### 3. File Access & Security
Ferrufi uses security-scoped bookmarks for file access. 
- Relevant files: `Sources/Ferrufi/Core/Storage/SecurityScopedBookmarkManager.swift` and `SecurityScopedFileAccess.swift`.
- Entitlements: `Ferrufi.entitlements`.

### 4. Versioning
Versions are managed in `Sources/Ferrufi/Version.swift`. Use `./scripts/set_version.sh` to update.

## 📜 Coding Standards & Conventions

- **Swift Style:** Follow standard Swift API design guidelines. Use SwiftUI for new UI components where appropriate, but be aware of AppKit integrations (e.g., `EditorCore`).
- **Error Handling:** Use `FerrufiError` for project-specific errors.
- **Concurrency:** Prefer modern Swift concurrency (`async/await`) where possible.
- **Documentation:** Use Triple-slash `///` for documentation comments on public symbols.

## 🧠 AI Assistance Guidelines

- **Safety First:** When modifying file operations, ensure security-scoped access is maintained.
- **Dylib Awareness:** Be cautious when changing anything related to `CMufi` or how `libmufiz.dylib` is loaded.
- **Build Verification:** After making changes that affect the build process or dependencies, suggest running `./scripts/build_app.sh`.
- **Reference Docs:** Consult `QUICK_REFERENCE.md` and `plans/` for deep dives into specific subsystems (e.g., `plans/METAL_IMPLEMENTATION.md`).

## 🧪 Testing Checklist
When adding features, ensure:
1. [ ] New models are codable if they need to be persisted.
2. [ ] UI components support both Light and Dark modes (handled via `ThemeManager`).
3. [ ] File operations handle sandbox/permission constraints.
4. [ ] Unit tests are added to `Tests/IronTests/`.
