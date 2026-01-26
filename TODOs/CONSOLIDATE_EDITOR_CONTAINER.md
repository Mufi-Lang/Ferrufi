# TODO: Consolidate editor surfaces into a single `EditorContainer` and migration checklist

Status: Draft — ready to implement
Owner: @you (assign as needed)
Branch: create `feature/editor-container` for all changes

Purpose
- Replace multiple editor entry-points with one single public component: `EditorContainer` (implementing `EditorHost` API).
- Internally compose existing, well-scoped modules (editor core, preview host, processors) — do not collapse responsibilities.
- Migrate call sites incrementally so behavior is preserved during the transition.
- Maintain toolbar functionality via a hidden backing editor during migration.
- Make Mufi (.mufi) the default file type and persist layout preferences.
- Sweep and unify fonts/themes across editor and preview.

High-level approach
- Implement a small, stable public API surface (`EditorHost`) + a new SwiftUI view `EditorContainer` that composes:
  - `EditorCore` (AppKit `NSTextView` wrapper around `UnifiedTextView`)
  - `Renderer` (optional renderer wrapper; preview-related behaviors removed)
  - `LayoutContainer` (splitter + split/editor/preview modes)
  - `Tooling` (line number ruler, toolbar router, hidden backing editor adapter)
- Migrate existing UI screens to use `EditorContainer` via adapters. Keep old types as thin shims while migrating.
- Deliver a tested migration in small PRs that are easy to review and revert if necessary.

Design / API (minimal)
- Protocol: `EditorHost` (public)
  - open(document: Document) async
  - save() async throws
  - getSelection() -> NSRange?
  - setSelection(_ range: NSRange)
  - applyFormattingCommand(_ command: EditorCommand) // bold/italic/code/block/heading

  - toolbarTarget: AnyObject? // returns object toolbar should send actions to
- View: `EditorContainer: SwiftUI.View`
  - init(document: Binding<Document>)
  - exposes publishers/handlers for selection and run requests
  - persists split ratio (optional persistence store)

Migration phases (checklist)

Phase 0 — Setup
- [ ] Create branch `feature/editor-container`.
- [ ] Add this file to the branch: `Ferrufi/TODOs/CONSOLIDATE_EDITOR_CONTAINER.md`.
- [ ] Ensure CI runs `swift build` for PRs (if not present, add minimal CI).

Phase 1 — Scaffolding & specs
- [ ] Create `EditorHost` protocol in `Ferrufi/Sources/Ferrufi/Features/Editor/EditorHost.swift`.
- [ ] Create `EditorContainer` stub in `Ferrufi/Sources/Ferrufi/Features/Editor/EditorContainer.swift` (thin: compile-time stub with TODOs).
- [ ] Add `EditorViewMode` enum (`.split`, `.editorOnly`, `.previewOnly`) and `EditorCommand` enum.
- [ ] Add unit tests for the `EditorHost` API surface (sanity compile-only tests allowed temporarily).
- [ ] Add a short design doc / comment block near `EditorContainer` describing responsibilities.

Phase 2 — EditorCore adapter
- [ ] Create `EditorCore.swift` wrapping the existing `UnifiedTextView` and Coordinator:
  - Expose methods: bindDocument, get/set selection, apply formatting commands.
  - Keep incremental syntax-highlighting and defensive guards unchanged.
- [ ] Ensure `EditorCore` exposes a `FirstResponder` target for toolbar commands.
- [ ] Write small unit tests for EditorCore selection and formatting calls.

Phase 3 — PreviewHost adapter
- [ ] Create `PreviewHost.swift` that wraps the platform preview renderer and exposes preview/update/run APIs.
  - Expose: update(document/ast), getScrollPosition, syncScrollTo(range).
- [ ] Ensure preview uses `ThemeManager` fonts for consistency.
- [ ] Add basic tests to ensure preview receives document updates.

Phase 4 — EditorContainer composition + UI
- [ ] Implement `EditorContainer` SwiftUI view that composes `EditorCore` + `PreviewHost`.
  - Implement split view with draggable splitter.
  - Support layout configuration and show/hide subviews accordingly (editor-first; no dedicated secondary-pane layout).
  - Propagate `ThemeManager.editorFontName` and `editorFontSize` to both subviews.
- [ ] Add split-by-default logic for Mufi documents:
  - When opening a `.mufi` document, default `EditorContainer(mode: .split)`.
  - Make this behavior explicit in the open flow (do not mutate global defaults).
- [ ] Add a compact toggle control that switches between split/editor/preview modes (mimic existing native controls).

Phase 5 — Hidden backing editor & toolbar routing (B1)
- [ ] Implement optional hidden `NSTextView` instance inside `EditorContainer`:
  - Not in view hierarchy; used as toolbar action target when the visible editor is not the first responder.
  - Keep it in sync with the visible editor's document and selection.
  - Expose `toolbarTarget` to toolbar wiring.
- [ ] Update toolbar command routing to use `EditorContainer.toolbarTarget` instead of assuming a specific view.
- [ ] Add tests ensuring toolbar formatting commands apply to the model when the visible editor is not the first responder.

Phase 6 — Font sweep & visual parity (C)
- [ ] Audit preview, renderer, and code-block font usages across:
  - `PreviewHost.swift`
  - `UnifiedEditor.swift` / `UnifiedTextView`
  - `LineNumberRulerView.swift`
  - Any custom rendering pipelines (Metal, WebView)
- [ ] Replace hard-coded fonts with `ThemeManager.editorFontName` + `editorFontSize` where appropriate.
- [ ] Decide on code-block policy:
  - Option A (recommended): Code blocks remain monospaced; body text uses editor font.
  - Option B: Everything (including code blocks) uses the same editor font.
- [ ] Add UI toggle preference if product wants to switch code-block behavior.

Phase 7 — Persistence (split ratio) (E)
- [ ] Add persistence key(s) for:
  - Last split ratio (per-note optional; fallback to global)
- [ ] Wire persistence to `EditorContainer` so it restores state on reopen.
- [ ] Add small animation for toggling layouts (visual polish).

Phase 8 — Migrate call sites incrementally
- [ ] Identify call sites that present editors:
  - `EnhancedEditorView`
  - `EditorWithREPL`
  - `NativeSplitEditor`
  - Other screens that embed/edit notes
- [ ] For each call site:
  - [ ] Replace with an adapter that instantiates `EditorContainer` and forwards relevant props/state.
  - [ ] Run compile and manual smoke tests.
  - [ ] Keep legacy class as `Deprecated*Adapter` for a short period to ease rollback.
- [ ] Migrate screens one at a time; open small PRs per screen to make reviews manageable.

Phase 9 — Cleanup & remove legacy code
- [ ] After all call sites migrated and tested:
  - Remove old duplicate container classes or convert to tiny adapters with forwarding to `EditorContainer`.
  - Remove or mark deprecated public types as `@available(*, deprecated)`.
- [ ] Run `swift build` and all tests; fix leftover compile errors.

Phase 10 — Testing & QA (D)
- [ ] Full build: `swift build`.
- [ ] Run unit and UI/Integration tests.
- [ ] Manual QA checklist:
  - [ ] Open Mufi file — default split mode is active.
  - [ ] Editor typing remains responsive (incremental highlighting unchanged).
  - [ ] Toolbar formatting works in editor-only and via the hidden backing editor target.
  - [ ] Hidden editor correctly routes toolbar commands when the visible editor is not the first responder.
  - [ ] Run Mufi scripts via the Run action; outputs appear in the REPL or output pane.
  - [ ] Line numbers align with wrapped lines.
  - [ ] Fonts identical between editor and renderer where intended.
  - [ ] Split ratio and layout preferences persist across restarts.
- [ ] Performance test: open >200KB document and confirm acceptable typing latency.

Phase 11 — PR workflow & merge
- [ ] Prepare PR template for each migration PR:
  - Summary of change
  - Files changed
  - Manual QA steps
  - Screenshots / short GIFs if UI changes
- [ ] Ensure PR passes CI before requesting review.
- [ ] Collect one approval from a code-owner and merge.

Files likely to be created/edited (non-exhaustive)
- New:
  - `Sources/Ferrufi/Features/Editor/EditorHost.swift`
  - `Sources/Ferrufi/Features/Editor/EditorContainer.swift`
  - `Sources/Ferrufi/Features/Editor/EditorCore.swift`
  - `Sources/Ferrufi/Features/Editor/PreviewHost.swift`
  - `Sources/Ferrufi/Features/Editor/EditorCommands.swift`
- Edited:
  - `Sources/Ferrufi/Features/Editor/UnifiedEditor.swift` (expose internals through EditorCore)
  - `Sources/Ferrufi/UI/Components/NativeSplitEditor.swift` (convert to adapter)
  - `Sources/Ferrufi/Features/Editor/LineNumberRulerView.swift` (ensure compatibility)
  - `Sources/Ferrufi/Sources/Ferrufi/...` - any screen embedding editors (replace with adapter)
  - `Ferrufi/TODOs/IMPLEMENT_EDITOR_AND_CREATE_NOTE_CHANGES.md` (update references)
- Tests:
  - `Ferrufi/Tests/Editor/EditorHostTests.swift`
  - `Ferrufi/Tests/Editor/EditorContainerSmokeTests.swift`

Risk register & mitigations
- Toolbar actions stop working
  - Mitigation: Implement hidden backing editor early; ensure toolbarTarget is stable.
- Visual regressions (wrap, fonts, line numbers)
  - Mitigation: Keep existing rendering/highlighting code untouched; only rewire calls. Add visual regression smoke tests.
- Performance regressions
  - Mitigation: Preserve incremental highlighting and profiling step in Phase 10.
- Large refactor scope
  - Mitigation: Migrate in small PRs; keep adapters; maintain compile state.

Non-goals (this ticket)
- Re-architecting syntax-highlighting internals (unless necessary for API exposure).
- Rewriting any notebook parser/serializer in this migration (those are separate feature tasks).
- Changing execution/persistence semantics for code blocks (aside from toolbar routing and hiding editor).

Decision points to confirm before starting
- Default new-note file type: `.mufi` (recommended). Confirm if you want `.md` instead.
- Code-block font policy: Keep code blocks monospaced (recommended) or make them share editor font?
- Toolbar strategy: Hidden backing editor (B1) will be implemented by default for migration. Confirm if you prefer alternative (B2 or B3).

Immediate next actions (what I will do once work starts)
1. Create the feature branch and add this file (done in branch work).
2. Implement Phase 1 scaffolding (EditorHost, EditorContainer stub).
3. Implement EditorCore adapter (Phase 2).
4. Send a WIP PR with the stub and EditorCore — small, reviewable change.

PR Checklist (for each PR)
- [ ] Title follows: "feat(editor): <short description>" or "refactor(editor): <...>"
- [ ] Links to this plan and the feature branch.
- [ ] CI green (`swift build`).
- [ ] Manual QA steps documented and passing.
- [ ] Reviewers assigned.
- [ ] Migration notes for consumers of editor APIs.

Notes
- Keep the public interface tiny and stable. Internal refactors are fine but avoid API churn.
- Preserve backwards compatibility for any external plugins or extensions that rely on existing editor classes while the migration is ongoing; deprecate gradually.
- When in doubt, prefer adding adapters over removing the old code immediately.

If you want me to start now: confirm the Decision points above (default file type, code-block font policy, toolbar strategy). Once confirmed I will begin implementing Phase 1 and open the first WIP PR (small incremental change).