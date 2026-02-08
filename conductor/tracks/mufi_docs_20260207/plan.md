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
- [ ] Task: Create Documentation Browser View
    - [ ] Implement a `DocBrowserView` using SwiftUI.
    - [ ] Setup the side-by-side layout (Search/List on left, Content on right).
    - [ ] Integrate a search bar with real-time updates.
- [ ] Task: Implement Markdown Renderer Integration
    - [ ] Use or adapt existing Markdown rendering logic for the content pane.
    - [ ] Support navigation between documentation pages via links.
    - [ ] Write UI/Unit Tests for `DocBrowserView` and rendering.
- [ ] Task: Conductor - User Manual Verification 'Phase 2: UI Implementation' (Protocol in workflow.md)

## Phase 3: Integration & Polish
- [ ] Task: Integrate Documentation Shortcut
    - [ ] Add `Cmd+Shift+H` shortcut to open the Documentation Browser.
    - [ ] Ensure the browser can be triggered from the main editor.
- [ ] Task: Final Polish & Theme Support
    - [ ] Ensure full support for Light/Dark modes via `ThemeManager`.
    - [ ] Refine animations and transitions for the search results.
    - [ ] Verify non-interactive build/test commands.
- [ ] Task: Conductor - User Manual Verification 'Phase 3: Integration & Polish' (Protocol in workflow.md)
