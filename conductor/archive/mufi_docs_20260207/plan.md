# Plan: In-App Mufi Documentation Browser

## Phase 1: Infrastructure & Data Setup [checkpoint: cab5912]
- [x] Task: Create Documentation Storage Structure 0e1ada7
    - [x] Create `Resources/Documentation` directory.
    - [x] Populate `Resources/Documentation/Syntax` with initial Markdown files (e.g., `keywords.md`, `control_flow.md`).
    - [x] Populate `Resources/Documentation/StdLib` with initial Markdown files for core functions.
- [x] Task: Implement Documentation Provider Service c4ce46a
    - [x] Create `DocumentationService` to index and search local Markdown files.
    - [x] Implement search logic with category filtering.
    - [x] Write Unit Tests for `DocumentationService`.
- [x] Task: Conductor - User Manual Verification 'Phase 1: Infrastructure & Data Setup' (Protocol in workflow.md) cab5912

## Phase 2: UI Implementation
- [x] Task: Create Documentation Browser View 33b2a33
    - [x] Implement a `DocBrowserView` using SwiftUI.
    - [x] Setup the side-by-side layout (Search/List on left, Content on right).
    - [x] Integrate a search bar with real-time updates.
- [x] Task: Implement Markdown Renderer Integration 33b2a33
    - [x] Use or adapt existing Markdown rendering logic for the content pane.
    - [x] Support navigation between documentation pages via links.
    - [x] Write UI/Unit Tests for `DocBrowserView` and rendering.
- [ ] Task: Conductor - User Manual Verification 'Phase 2: UI Implementation' (Protocol in workflow.md)

## Phase 3: Integration & Polish [checkpoint: 29d2f3f]
- [x] Task: Integrate Documentation Shortcut 6056b8a
    - [x] Add `Cmd+Shift+H` shortcut to open the Documentation Browser.
    - [x] Ensure the browser can be triggered from the main editor.
- [x] Task: Final Polish & Theme Support 6056b8a
    - [x] Ensure full support for Light/Dark modes via `ThemeManager`.
    - [x] Refine animations and transitions for the search results.
    - [x] Verify non-interactive build/test commands.
- [x] Task: Conductor - User Manual Verification 'Phase 3: Integration & Polish' (Protocol in workflow.md) 5a13a56
