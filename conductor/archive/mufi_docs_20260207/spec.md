# Specification: In-App Mufi Documentation Browser

## Overview
This feature introduces a dedicated, local documentation browser for the Mufi programming language within Ferrufi. It provides an instant-search interface for syntax references and standard library functions, rendering documentation from local Markdown files in a side-by-side view, similar to the MATLAB Help browser.

## Functional Requirements
- **Dedicated Documentation Search:**
    - A standalone search interface (accessible via a dedicated shortcut, e.g., `Cmd+Shift+H`).
    - Real-time search/filtering of documentation topics.
- **Content Scope:**
    - **Syntax Reference:** Detailed documentation for keywords, operators, and control flow.
    - **Standard Library:** Function signatures, descriptions, and usage examples for the Mufi standard library.
- **Search UI:**
    - Search results must include category labels (e.g., `[Syntax]`, `[StdLib]`) to distinguish content types.
- **MATLAB-Style Documentation Viewer:**
    - A side-by-side layout: A navigation/search results list on the left and a Markdown preview pane on the right.
    - Support for internal linking between documentation pages.
- **Local-First:**
    - All documentation content must be stored locally within the application bundle or a dedicated local directory to ensure offline availability.

## Non-Functional Requirements
- **Instant Response:** Search and rendering should be near-instantaneous.
- **Visual Consistency:** The documentation viewer should match the Ferrufi theme and use the existing Markdown rendering capabilities.

## Acceptance Criteria
- [ ] User can open the Documentation Browser via a shortcut or menu item.
- [ ] Typing in the search bar filters the list of available documentation topics.
- [ ] Results clearly distinguish between Syntax and Standard Library items.
- [ ] Selecting a result displays the corresponding documentation in a rendered Markdown view on the right.
- [ ] Documentation remains accessible without an internet connection.

## Out of Scope
- Integration with external websites (mufi-lang.org) for live fetching (initial version is local-only).
- User-contributed documentation or editing of documentation within the IDE.
