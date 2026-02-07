# Implementation Plan: Ferrufi Documentation Website

This plan covers the restructuring of project documentation and the creation of a high-performance documentation website using Docusaurus.

## Phase 1: Repository Restructuring
- [x] Task: Relocate Internal Documentation
    - [ ] Create the top-level `docs/` directory.
    - [ ] Move all existing `.md` files from `docs/` to `docs/`.
    - [ ] Perform a global search and replace to update internal links within these files if necessary.
- [ ] Task: Conductor - User Manual Verification 'Phase 1: Repository Restructuring' (Protocol in workflow.md)

## Phase 2: Website Scaffolding (Docusaurus)
- [ ] Task: Initialize SSG Project
    - [ ] Initialize a new Docusaurus site within the (now empty) `docs/` directory.
    - [ ] Configure `docusaurus.config.js` with Ferrufi's name, tagline, and GitHub repository links.
- [ ] Task: Configure Theme and Branding
    - [ ] Apply Ferrufi branding (logo, accent colors) to the Docusaurus theme.
    - [ ] Set up the primary navigation structure (Home, Installation, Features, Architecture).
- [ ] Task: Conductor - User Manual Verification 'Phase 2: Website Scaffolding' (Protocol in workflow.md)

## Phase 3: Content Creation and Integration
- [ ] Task: Implement Landing Page
    - [ ] Design and implement the Hero section with a clear call-to-action for installation.
    - [ ] Add high-level feature highlights (Metal acceleration, Mufi support).
- [ ] Task: Create Installation and Feature Pages
    - [ ] Create a dedicated `Installation` guide with the one-liner command.
    - [ ] Create `Features` pages for the REPL, LSP, and high-performance editor.
- [ ] Task: Migrate Technical Architecture Docs
    - [ ] Integrate the moved technical docs (from Phase 1) into the site's `Architecture` section.
    - [ ] Polish formatting and ensure images/assets are correctly referenced.
- [ ] Task: Conductor - User Manual Verification 'Phase 3: Content Creation and Integration' (Protocol in workflow.md)

## Phase 4: Finalization and Quality Gate
- [ ] Task: Final Polish and Link Verification
    - [ ] Run a link checker to ensure no broken internal or external links.
    - [ ] Verify responsive design on mobile and desktop viewports.
- [ ] Task: Deployment Documentation
    - [ ] Add a `DEPLOYMENT.md` (or similar) explaining how to build and host the site on GitHub Pages.
- [ ] Task: Conductor - User Manual Verification 'Phase 4: Finalization and Quality Gate' (Protocol in workflow.md)
