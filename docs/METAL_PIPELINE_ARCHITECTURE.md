# Metal Pipeline Architecture

This document describes the architecture of Ferrufi's Metal-based rendering subsystem.

## Current State (Legacy)

The current pipeline is based on `BaseMetalRenderer`, which provides a foundation for specialized renderers:
- `EditorBackgroundRenderer`: Animated background using mesh gradients.
- `MinimapRenderer`: High-level code structure visualization.
- `MetalTextRenderer`: Simplified text rendering (per-character draw loop).

### Hardware Management
`MetalDeviceManager` handles `MTLDevice` and `MTLCommandQueue` initialization and provides robust `MTLLibrary` loading logic.

### Shaders
`Shaders.metal` contains a mix of vertex, fragment, and compute shaders for UI components, animations, and experimental lexing/layout.

### Deficiencies
1. **Coupling:** The renderer is tightly coupled with the editor state.
2. **Inefficiency:** `MetalTextRenderer` performs individual draw calls for each character.
3. **Rigidity:** Adding new visual effects requires modifying the core renderer logic.

## Planned Architecture (Modular)

The enhanced pipeline will decouple responsibilities into modular components.

### 1. Render State (`RenderState`)
A data structure that encapsulates all information required for a single frame, isolated from the editor's live state.

### 2. Layout Engine (`LayoutEngine`)
Responsible for calculating glyph positions, line breaks, and ligature substitutions. It produces a stream of glyph data for the renderer.

### 3. Shader Manager (`ShaderManager`)
Organizes and caches `MTLRenderPipelineState` and `MTLComputePipelineState` objects, providing a clean interface for selecting shaders.

### 4. Modular Renderer
The core renderer will be refactored to consume `RenderState` and use the `LayoutEngine` and `ShaderManager` to encode commands efficiently (using instanced rendering or large vertex buffers for text).

## Component Flow

1. **Input:** Editor state (text, selection, diagnostics).
2. **Snapshot:** Create a `RenderState` snapshot.
3. **Layout:** `LayoutEngine` processes the snapshot to determine glyph positions.
4. **Encoding:** Renderer uses `ShaderManager` and layout data to encode Metal commands.
5. **Display:** `MTKView` presents the rendered frame.
