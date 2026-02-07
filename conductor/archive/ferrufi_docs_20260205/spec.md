# Specification: Ferrufi Documentation Website

## Overview
This track involves creating a professional, high-performance documentation website for Ferrufi. The site will highlight core features (Metal acceleration, Mufi IDE experience), provide clear installation instructions, and host technical deep dives. To facilitate this, the existing `docs/` directory will be restructured, with current internal documentation moved to a new `docs/` directory.

## Goals
- **Professional Presence:** Create a central hub for Ferrufi documentation and marketing.
- **Easy Installation:** Make the install command prominent and easy to use.
- **Feature Showcase:** Highlight the unique technical aspects of the IDE (Metal, REPL, LSP).
- **Project Organization:** Restructure the repository to separate public documentation from internal development plans.

## Functional Requirements
- **Static Site Generation:** Build the website using Docusaurus (the selected SSG).
- **Landing Page:** Implement a hero section with the Ferrufi logo, a brief description, and a call-to-action (Install).
- **Installation Page:** A dedicated guide featuring the one-liner installation command.
- **Architecture Section:** Integration of existing technical docs explaining the Metal pipeline, memory safety, etc.
- **Feature Pages:** Dedicated pages for the integrated REPL and LSP features.
- **Restructured Repository:** 
    - Move existing `.md` files from `docs/` to `docs/`.
    - Initialize the SSG source within the `docs/` folder.

## Non-Functional Requirements
- **Visual Aesthetic:** High-performance, technical, and modern (aligned with Product Guidelines).
- **Responsive Design:** Ensures readability on mobile and desktop.
- **Ease of Deployment:** Compatible with GitHub Pages.

## Acceptance Criteria
1. Existing markdown files are successfully moved from `docs/` to `docs/`.
2. A Docusaurus site is initialized and functional within the `docs/` directory.
3. The landing page, installation guide, and architectural docs are accessible.
4. The site accurately reflects Ferrufi's "High-Performance" and "Technical Sophistication" brand.
5. The build and deployment process is documented.

## Out of Scope
- A full-featured blog (initial focus is on documentation).
- Interactive Mufi playground (REPL is showcased via text/images for now).
