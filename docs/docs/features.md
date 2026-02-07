# Features

Ferrufi provides a modern, high-performance environment for Mufi development.

## High-Performance Editor

At the heart of Ferrufi is a custom text engine built from the ground up for speed and visual fluidness.

-   **Metal Acceleration:** Text rendering, cursor movement, and selection are offloaded to the GPU using Metal, ensuring a consistent 60+ FPS experience.
-   **Fluid Animations:** Experience a smooth, sliding cursor and shimmering selection highlights that make the editor feel alive.
-   **Ligature Support:** Full support for programming ligatures (e.g., `==`, `!=`, `->`) provided by the CoreText-driven layout engine.

## Integrated Mufi REPL

Write and test Mufi code instantly with the built-in Read-Eval-Print Loop.

-   **Interactive Coding:** Execute Mufi expressions line-by-line with immediate results.
-   **Script Execution:** Run entire notes as Mufi scripts with a single click.
-   **Editor Integration:** Seamlessly send code snippets from your editor directly to the REPL for testing.
-   **Persistent State:** The REPL maintains variable and function state between commands, allowing for iterative development.

## Language Server Protocol (LSP)

Ferrufi includes an integrated LSP service specifically for the Mufi language.

-   **Real-time Diagnostics:** Catch syntax and semantic errors as you type with prominent visual feedback.
-   **Context-Aware Hover:** View documentation and type information for symbols under your cursor.
-   **Autocomplete:** Speed up your workflow with intelligent code completion (experimental).

## Native macOS Experience

Ferrufi is designed to feel like a permanent part of your macOS workflow.

-   **Security-Scoped Access:** Safely work with files and folders using Apple's recommended sandboxing practices.
-   **Native Shortcuts:** Fully customizable keyboard shortcuts that adhere to standard macOS patterns.
-   **Unified Storage:** Efficient management of your notes and projects.
