# Specification: Formatting and Package Creator Integration

## Overview
This track integrates new Mufi C runtime capabilities into the Ferrufi IDE: source code formatting, a package management wizard for creating new projects, and project-aware execution. These features leverage the `mufiz_format_source`, `mufiz_pm_new`, and `mufiz_pm_run` functions from `libmufiz.dylib`.

## Functional Requirements

### 1. Code Formatting
- **Manual Trigger:** Users can format the current Mufi file via `Edit > Format Document` or a keyboard shortcut (Cmd+Shift+F).
- **Format on Save:** A new setting in Preferences to enable automatic formatting whenever a `.mufi` file is saved.
- **Integration:** Use `mufiz_format_source` for unsaved buffers.
- **Feedback:** Success/failure feedback provided via toast notifications.

### 2. Package Creator (New Project Wizard)
- **Wizard UI:** A modal dialog triggered by `File > New Project...`.
- **Inputs:**
    - **Project Name:** Required string for the project identity.
    - **Location:** Filesystem path selection.
    - **Git Initialization:** Toggle to initialize a git repository in the new project folder.
    - **Open Project:** Toggle to automatically switch the IDE context to the new project.
- **Integration:** Use `mufiz_pm_new` to create the project structure (mufi.zon, src/main.mufi).
- **Feedback:** Toast notifications for creation status.

### 3. Project-Aware Execution
- **Run Button Logic:** When the IDE is open to a Mufi project (detected by the presence of `mufi.zon`), the "Run" button should execute the project's entry point using `mufiz_pm_run` rather than just the current file.
- **Integration:** Bridge `mufiz_pm_run` to the UI's run action.

## Non-Functional Requirements
- **Responsiveness:** Formatting, project creation, and project execution should happen asynchronously to avoid blocking the main UI thread.
- **Error Handling:** Robust handling of C runtime return codes, displaying user-friendly messages via toasts.

## Acceptance Criteria
- [ ] Formatting a messy `.mufi` file results in clean code according to Mufi standards.
- [ ] "Format on Save" works reliably when enabled.
- [ ] The New Project Wizard creates a valid directory structure with all required files.
- [ ] The "Run" button correctly executes `mufiz_pm_run` when within a project context.
- [ ] Errors (e.g., invalid project name) are clearly communicated to the user.
- [ ] Toast notifications appear correctly for all operations.

## Out of Scope
- Adding/Removing dependencies via the UI (to be handled in a future track).
- Complex project templates beyond the default `mufiz_pm_new` output.
