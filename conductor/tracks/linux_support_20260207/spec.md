# Specification: Initial Linux Support (Full IDE Port)

## Overview
This track initiates the porting of Ferrufi to Linux. The goal is to transform the macOS-exclusive IDE into a cross-platform application by abstracting platform-specific dependencies and introducing Linux-compatible alternatives for UI and rendering.

## Functional Requirements
- **Platform Agnostic Core:** Refactor `Sources/Ferrufi/Core` to remove any AppKit/Foundation-specific dependencies that are not available on Linux.
- **Linux UI Layer:** Introduce a Linux-compatible UI implementation using a Swift wrapper for GTK or Adwaita (replacing SwiftUI/AppKit on Linux).
- **Vulkan Rendering:** Implement a Vulkan-based rendering backend to replace Metal on Linux, maintaining high-performance text rendering.
- **Mufi Runtime:** Update the build system to compile the Mufi runtime (Zig) as a shared object (`libmufiz.so`) on Linux.

## Non-Functional Requirements
- **Performance:** The Linux version should aim for the same "Extreme Performance" goals as the macOS version, leveraging Vulkan.
- **Maintainability:** The project structure must cleanly separate macOS-specific code from Linux-specific code to avoid regression on the primary platform.

## Acceptance Criteria
- [ ] The project builds successfully on Linux (verified via CI or Docker).
- [ ] Core logic (Core/Models, Core/LSP, Core/Search) compiles and runs on Linux.
- [ ] A basic window can be launched on Linux using the chosen UI framework.
- [ ] The Mufi runtime (`libmufiz.so`) is successfully linked and callable from the Linux build.
- [ ] Basic text rendering is visible using the Vulkan backend (even if incomplete).

## Out of Scope
- Full feature parity with the macOS version in this first phase (e.g., advanced shortcuts, native file system integration specifics like bookmarks might be simplified).
- **Windows support will not be implemented.**
