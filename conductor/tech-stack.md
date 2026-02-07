# Technology Stack

## Core
- **Primary Language:** Swift
- **Platform:** macOS (Minimum version: 15.0/26.0 as per Package.swift)
- **Runtime Integration:** C-based Mufi runtime (`libmufiz.dylib`) via `CMufi` system library.

## Frontend / UI
- **Frameworks:** SwiftUI (modern UI), AppKit (low-level window and editor management).
- **Rendering:** Metal (GPU-accelerated text and UI rendering via a modular pipeline: `RenderState`, `LayoutEngine`, `ShaderManager`, and `MetalEditorRenderer`).
- **Text Engine:** CoreText-driven glyph positioning with full support for ligatures and complex layout.

## Tools & Dependencies
- **Build System:** Swift Package Manager (SPM).
- **Package Manager (Web):** Bun.
- **Documentation Engine:** Docusaurus (Static Site Generator).
- **File Management:** `Files` (John Sundell), `PathKit` (Kyle Fuller).
- **Version Control:** Git.

## Infrastructure & Architecture
- **Storage:** Unified storage with security-scoped bookmark management for sandboxed file access.
- **Concurrency:** Modern Swift Concurrency (async/await, Actors).
- **Communication:** Internal notification system and integrated Language Server Protocol (LSP) for Mufi language features.