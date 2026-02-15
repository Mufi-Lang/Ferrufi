# Implementation Plan: Formatting and Package Creator Integration

This plan outlines the steps to integrate Mufi C runtime formatting, project creation, and project-aware execution into Ferrufi.

## Phase 1: Foundation & Swift Bridging
This phase focuses on exposing the new C functions to Swift and creating the service layer for these features.

- [x] Task: Update `CMufi` and Bridge C Functions
    - [x] Ensure `mufiz_format_source`, `mufiz_pm_new`, and `mufiz_pm_run` are accessible in Swift.
    - [x] Create a `MufiRuntimeService` or update `MufiIntegration` to wrap these calls safely.
- [x] Task: Create Toast Notification Service
    - [x] Implement a simple UI-agnostic service to queue and display toast messages.
    - [x] Integrate with the main UI to show overlays.
- [x] Task: Conductor - User Manual Verification 'Foundation & Swift Bridging' (Protocol in workflow.md)

## Phase 2: Code Formatting Integration
Implementing the manual and automatic formatting logic.

- [x] Task: Implement Formatting Logic
    - [x] Write tests for `MufiRuntimeService.format(source: String)`.
    - [x] Implement the Swift wrapper for `mufiz_format_source`.
- [x] Task: Add Formatting UI Commands
    - [x] Add "Format Document" to the Edit menu.
    - [x] Bind Cmd+Shift+F to the formatting action.
- [x] Task: Implement Format on Save
    - [x] Add `formatOnSave` to `SettingsManager`.
    - [x] Update the file saving logic to trigger formatting if the setting is enabled.
- [x] Task: Conductor - User Manual Verification 'Code Formatting Integration' (Protocol in workflow.md)

## Phase 3: Package Creator (New Project Wizard)
Creating the UI and logic for new Mufi projects.

- [x] Task: Create New Project Wizard UI
    - [x] Implement the `NewProjectWizardView` in SwiftUI.
    - [x] Add validation for project name and location.
- [x] Task: Implement Project Creation Logic
    - [x] Write tests for `MufiRuntimeService.createNewProject(name:path:initGit:)`.
    - [x] Implement the wrapper for `mufiz_pm_new` and subsequent `git init` if requested.
- [x] Task: Integrate Wizard with File Menu
    - [x] Add "New Project..." to the File menu.
    - [x] Handle the "Open Project" toggle logic after creation.
- [x] Task: Conductor - User Manual Verification 'Package Creator' (Protocol in workflow.md)

## Phase 4: Project-Aware Execution
Updating the Run button to handle project contexts.

- [x] Task: Implement Project Detection Logic
    - [x] Add logic to detect `mufi.zon` in the current workspace/folder.
    - [x] Update the internal state to track the "active project".
- [x] Task: Update Run Button Behavior
    - [x] Modify the Run action to call `mufiz_pm_run` if a project is active.
    - [x] Ensure output from `mufiz_pm_run` is piped correctly to the IDE's console/REPL.
- [x] Task: Conductor - User Manual Verification 'Project-Aware Execution' (Protocol in workflow.md)

## Phase 5: Final Polishing & Integration
Ensuring everything works together smoothly.

- [x] Task: Comprehensive Integration Testing
    - [x] Verify the end-to-end flow: Create project -> Format code -> Run project.
    - [x] Check performance and responsiveness (async operations).
- [x] Task: Update Documentation
    - [x] Document the new features in the user guide.
- [x] Task: Conductor - User Manual Verification 'Final Polishing & Integration' (Protocol in workflow.md)