# Architecture

Ferrufi is built with a focus on extreme performance and robust safety. This section details the core architectural components that enable its high-performance macOS experience.

## Core Pillars

### [Metal Pipeline](./architecture/metal-pipeline.md)
Explore how Ferrufi utilizes a modular, GPU-accelerated rendering pipeline designed for high-fidelity text editing and fluid visual effects.
- **Render State:** Immutable snapshots for thread safety.
- **Layout Engine:** CoreText-driven glyph positioning.
- **Metal Editor Renderer:** Batched rendering and GPU animations.

### [Memory Safety](./architecture/memory-safety.md)
Learn about the meticulous memory management strategies used to integrate the C-based Mufi runtime into Swift.
- **String Lifetime:** Managing C-string pointers.
- **Actor Isolation:** Preventing race conditions with Swift Actors.
- **Resource Cleanup:** Preventing leaks with `defer` and explicit cleanup.

### [Linking & Runtime](./architecture/linking.md)
Details on how `libmufiz.dylib` is linked, loaded, and managed within the app bundle.

### [Metal Implementation Details](./architecture/metal-implementation.md)
A deeper dive into specific Metal implementation choices and optimizations.