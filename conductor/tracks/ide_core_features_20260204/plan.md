# Implementation Plan: IDE Core: Shortcuts & Basic LSP

## Phase 1: Shortcuts UI & Dynamic Integration

- [x] Task: Create `ShortcutsSettingsView` for displaying and managing actions

- [x] Task: Implement `KeyCaptureView` to record new key combinations

- [x] Task: Integrate `ShortcutsManager` with `FerrufiCommands` for dynamic menu updates

- [x] Task: Conductor - User Manual Verification 'Phase 1: Shortcuts' (Protocol in workflow.md)



## Phase 2: LSP Diagnostics & Error Reporting

- [x] Task: Enhance `MufiBridge` and `MufiLSPService` for detailed diagnostic ranges

- [x] Task: Implement squiggly line rendering in `EditorCore` for diagnostics

- [x] Task: Implement workspace-wide `ProblemsListView`

- [x] Task: Conductor - User Manual Verification 'Phase 2: LSP Diagnostics' (Protocol in workflow.md)



## Phase 3: LSP Navigation & Tooltips

- [x] Task: Implement Hover provider in `MufiLSPService` and UI popover

- [x] Task: Implement 'Go to Definition' logic in `MufiBridge`

- [x] Task: Add context menu and shortcut integration for navigation

- [x] Task: Conductor - User Manual Verification 'Phase 3: LSP Navigation' (Protocol in workflow.md)
