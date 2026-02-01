# Metal Acceleration Roadmap 🚀

This document tracks the progress of Metal-based optimizations in Ferrufi. The goal is to transition from standard CPU-bound rendering to a high-performance GPU-accelerated IDE.

## 📊 Progress Tracker

| Feature | Complexity | Status | Target Phase |
| :--- | :---: | :---: | :---: |
| **Metal Background Layer** | Low | ✅ Completed | Phase 1 |
| **GPU-Accelerated Cursor** | Medium | 🚧 In Progress | Phase 1 |
| **Metal Minimap** | Medium | ✅ Completed | Phase 2 |
| **Parallel Lexing (Syntax)** | High | 🚧 In Progress | Phase 3 |
| **Glyph Rendering (Atlas)** | Very High | 🚧 In Progress | Phase 4 |

---

## 🛠 Detailed Implementation Plan

### Phase 1: Visual Polish & Feedback (Immediate)
*   **Background Shaders:** Implement animated mesh gradients or vibrancy overlays in `Shaders.metal` to provide a modern "glass" aesthetic behind the text.
*   **Fluid Cursor:** Create a `MetalCursorView` that renders a smooth, sliding caret using spring physics. This replaces the standard blinking block.
*   **Active Line Highlight:** Use a fragment shader to render a subtle glow or gradient on the current line being edited.

### Phase 2: Navigation & Overview (Short-term)
*   **Metal Minimap:**
    *   Downsample the text buffer into a small Metal texture.
    *   Render a bird's-eye view of the code on the right gutter.
    *   Utilize GPU for instant updates during fast scrolling.

### Phase 3: Performance Core (Medium-term)
*   **GPU-Accelerated Lexer:**
    *   Move `Mufi` and `Markdown` syntax tokenization from `NSRegularExpression` (CPU) to a **Metal Compute Shader**.
    *   Output a "Style Buffer" that tells the renderer which colors/fonts to apply to each character range.
    *   *Benefit:* Near-instant highlighting for 100MB+ files.

### Phase 4: Full Rendering Engine (Long-term)
*   **Metal Texture Atlas:**
    *   Pre-render all font glyphs into a single large texture (Atlas).
    *   Implement a custom `MetalTextView` that draws text by positioning quads on the GPU.
    *   *Benefit:* Locked 120fps scrolling regardless of file size; zero CPU usage for rendering.

---

## 📓 Technical Notes

### Current Foundation
- ✅ `MetalDeviceManager` (Singleton setup)
- ✅ `BaseMetalRenderer` (Pipeline foundation)
- ✅ `MetalPerformanceMonitor` (FPS/Frame timing)
- ✅ `SmoothScrollView` (Metal-accelerated scroll container)

### Useful Metal Shaders to Implement
```metal
// Example: Fluid Cursor Shader Concept
fragment float4 cursor_fragment(VertexOut in [[stage_in]], 
                               constant float &time [[buffer(0)]]) {
    float alpha = 0.5 + 0.5 * sin(time * 5.0); // Smooth pulse
    return float4(0.0, 0.5, 1.0, alpha); 
}
```

---

## ✅ Completed Tasks
*   [x] Initial Metal Foundation created.
*   [x] Metal Performance Monitor integrated.
*   [x] Smooth physics-based scrolling implemented.
