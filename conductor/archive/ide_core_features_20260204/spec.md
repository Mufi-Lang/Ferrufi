# Specification: IDE Core: Shortcuts & Basic LSP

## Overview
This track focuses on two core IDE features: a customizable keyboard shortcut system and expanded Language Server Protocol (LSP) integration for the Mufi language. These features are critical for transforming Ferrufi into a professional-grade development environment.

## Requirements

### 1. Customizable Shortcuts
- **Logic:** Complete the `ShortcutsManager` integration to ensure all app actions can be remapped.
- **UI:** Implement a user-friendly settings pane for viewing and editing shortcuts.
- **Recording:** Provide a modal or inline view that captures key presses (including modifiers) for shortcut assignment.
- **Persistence:** Ensure all custom bindings are saved to the user's configuration.

### 2. Basic LSP Features
- **Diagnostics:** Display syntax and semantic errors from the Mufi runtime directly in the editor and in a centralized "Problems" list.
- **Hover:** Show type information and documentation when hovering over symbols in the code.
- **Go to Definition:** Enable jumping to the definition of a variable or function via keyboard shortcut or context menu.

## Success Criteria
- Users can change the shortcut for "New Note" and have it work immediately.
- Syntax errors in Mufi code are highlighted with red squigglies.
- Hovering over a Mufi keyword or function shows a tooltip with its description.
- Cmd+Click or F12 jumps to the definition of a symbol.