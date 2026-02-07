# Implementation Plan: Ferrufi Documentation Website

This plan covers the restructuring of project documentation and the creation of a high-performance documentation website using Docusaurus.

## Phase 1: Repository Restructuring [checkpoint: ba5be61]
- [x] Task: Relocate Internal Documentation
    - [x] Create the top-level `plans/` directory.
    - [x] Move all existing `.md` files from `docs/` to `plans/`.
    - [x] Perform a global search and replace to update internal links within these files if necessary.
- [x] Task: Conductor - User Manual Verification 'Phase 1: Repository Restructuring' (Protocol in workflow.md)

## Phase 2: Website Scaffolding (Docusaurus) [checkpoint: a38feff]
- [x] Task: Initialize SSG Project
    - [x] Initialize a new Docusaurus site within the (now empty) `docs/` directory.
    - [x] Configure `docusaurus.config.js` with Ferrufi's name, tagline, and GitHub repository links.
- [x] Task: Configure Theme and Branding
    - [x] Apply Ferrufi branding (logo, accent colors) to the Docusaurus theme.
    - [x] Set up the primary navigation structure (Home, Installation, Features, Architecture).
- [x] Task: Conductor - User Manual Verification 'Phase 2: Website Scaffolding' (Protocol in workflow.md)

## Phase 3: Content Creation and Integration [checkpoint: 525bea1]
- [x] Task: Implement Landing Page
    - [x] Design and implement the Hero section with a clear call-to-action for installation.
    - [x] Add high-level feature highlights (Metal acceleration, Mufi support).
- [x] Task: Create Installation and Feature Pages
    - [x] Create a dedicated `Installation` guide with the one-liner command.
    - [x] Create `Features` pages for the REPL, LSP, and high-performance editor.
- [x] Task: Migrate Technical Architecture Docs
    - [x] Integrate the moved technical docs (from Phase 1) into the site's `Architecture` section.
    - [x] Polish formatting and ensure images/assets are correctly referenced.
- [x] Task: Conductor - User Manual Verification 'Phase 3: Content Creation and Integration' (Protocol in workflow.md)

## Phase 4: Finalization and Quality Gate
- [x] Task: Final Polish and Link Verification
    - [x] Run a link checker to ensure no broken internal or external links.
    - [x] Verify responsive design on mobile and desktop viewports.
- [x] Task: Deployment Documentation
    - [x] Add a `DEPLOYMENT.md` (or similar) explaining how to build and host the site on GitHub Pages.
- [x] Task: Conductor - User Manual Verification 'Phase 4: Finalization and Quality Gate' (Protocol in workflow.md)