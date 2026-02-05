# Implementation Plan: IDE Core: Shortcuts & Basic LSP

## Phase 1: Shortcuts UI & Dynamic Integration
- [ ] Task: Create `ShortcutsSettingsView` for displaying and managing actions
- [ ] Task: Implement `KeyCaptureView` to record new key combinations
- [ ] Task: Integrate `ShortcutsManager` with `FerrufiCommands` for dynamic menu updates
- [ ] Task: Conductor - User Manual Verification 'Phase 1: Shortcuts' (Protocol in workflow.md)

## Phase 2: LSP Diagnostics & Error Reporting
- [ ] Task: Enhance `MufiBridge` and `MufiLSPService` for detailed diagnostic ranges
- [ ] Task: Implement squiggly line rendering in `EditorCore` for diagnostics
- [ ] Task: Implement workspace-wide `ProblemsListView`
- [ ] Task: Conductor - User Manual Verification 'Phase 2: LSP Diagnostics' (Protocol in workflow.md)

## Phase 3: LSP Navigation & Tooltips
- [ ] Task: Implement Hover provider in `MufiLSPService` and UI popover
- [ ] Task: Implement 'Go to Definition' logic in `MufiBridge`
- [ ] Task: Add context menu and shortcut integration for navigation
- [ ] Task: Conductor - User Manual Verification 'Phase 3: LSP Navigation' (Protocol in workflow.md)