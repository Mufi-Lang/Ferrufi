# Metal Pipeline Architecture

This document describes the architecture of Ferrufi's Metal-based rendering subsystem.

## Overview

Ferrufi uses a modular, GPU-accelerated rendering pipeline designed for high-performance text editing and visual effects. The architecture decouples the editor's live state from the rendering process using immutable snapshots and specialized engines.

## Core Components

### 1. Render State (`RenderState`)
- **Purpose:** Encapsulates all data required to render a single frame.
- **Contents:** Text content, cursor position, selection range, diagnostics, and token-specific metadata (`tokenTypes`).
- **Benefit:** Thread safety. The renderer works on a stable snapshot while the editor state continues to evolve.

### 2. Layout Engine (`LayoutEngine`)
- **Purpose:** Translates text and styling into physical glyph positions.
- **Technology:** Leverages **CoreText** (`CTLine`, `CTRun`) for high-fidelity typography.
- **Features:** 
    - Full support for ligatures and complex scripts.
    - Variable-width font handling.
    - Precise character-to-rect mapping for cursor and selection placement.

### 3. Shader Manager (`ShaderManager`)
- **Purpose:** Centralized management and caching of Metal Pipeline States (PSOs).
- **Functionality:** 
    - Compiles and caches `MTLRenderPipelineState` and `MTLComputePipelineState` objects.
    - Provides a clean interface for specialized renderers to request shaders by name.

### 4. Metal Editor Renderer (`MetalEditorRenderer`)
- **Purpose:** The primary orchestrator for the editor's visual layers.
- **Responsibilities:**
    - **Batched Text Rendering:** Efficiently draws all glyphs in a single draw call using a unified vertex buffer.
    - **Selection Layer:** Renders shimmering highlight overlays for selected text ranges.
    - **GPU-Accelerated Cursor:** Implements fluid, sliding cursor motion using GPU-side interpolation (vertex shader) for 120fps smoothness.
    - **Token Effects:** Applies shader-based visual enhancements (e.g., glow, underlines) based on token types.

## Component Flow

1. **Snapshot:** The editor generates a `RenderState` snapshot.
2. **Layout:** `LayoutEngine` processes the snapshot to determine `CGGlyph` indices and `CGPoint` positions.
3. **Encoding:** `MetalEditorRenderer` consumes the layout data:
    - Batches glyph vertices into a temporary buffer.
    - Encodes commands using PSOs from `ShaderManager`.
    - Passes dynamic data (time, animation progress) to shaders via constants and attributes.
4. **Display:** `MTKView` presents the final rendered frame.

## Performance Optimizations

- **Batching:** Reduces CPU-to-GPU overhead by combining individual character draw calls into a single vertex array.
- **GPU Interpolation:** Moves cursor animation math from the Main Thread to the GPU, ensuring visual fluidness even during heavy system load.
- **PSO Caching:** Eliminates runtime compilation stutters by reusing pipeline states.

## Future Roadmap

- **Compute Lexing:** Moving syntax highlighting from CPU regular expressions to Metal compute kernels.
- **SDF Text:** Implementing Signed Distance Field rendering for infinite zoom clarity and advanced text effects.