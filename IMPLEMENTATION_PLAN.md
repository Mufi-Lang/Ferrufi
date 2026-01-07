# Iron Implementation Plan

## Project Overview

Iron is a note-taking and knowledge management tool similar to Obsidian and Logseq, but with Metal graphics acceleration for enhanced performance and smooth user experience.

**Current State**: Early-stage Swift project with basic package scaffolding.

**Target Platform**: macOS (with potential iOS expansion later)

**Key Technologies**: SwiftUI, Metal, Core Data/SQLite, Combine

---

## Phase 1: Foundation & Architecture (Weeks 1-2)

### 1.1 Core Data Models ✅ COMPLETE
- [x] Define note data structures (content, metadata, relationships)
- [x] Implement file-based storage system
- [x] Create note indexing and search foundation
- [x] Set up configuration management
- [x] Create basic error handling system
- [x] Fix Swift concurrency and Sendable conformance
- [x] Ensure successful compilation with Swift 6.2

### 1.2 Basic App Structure ✅ COMPLETE
- [x] Set up SwiftUI app structure (targeting macOS)
- [x] Implement basic window management
- [x] Create navigation framework
- [x] Set up Metal rendering pipeline foundation
- [x] Establish project structure and organization
- [x] Create main ContentView with navigation split view
- [x] Build comprehensive SidebarView with folder navigation
- [x] Implement NoteListView with list/grid modes and search
- [x] Create DetailView for note editing and preview
- [x] Add SettingsView with full configuration options
- [x] Set up VaultPickerView for vault selection/creation
- [x] Create Metal rendering foundation classes
- [x] Add menu bar commands and keyboard shortcuts
- [x] Fix all build errors and ensure compilation

---

## Phase 2: Core Editing Experience (Weeks 3-4)

### 2.1 Text Editor ✅ COMPLETE
- [x] Implement markdown-aware text editor (NSTextView-based)
- [x] Add syntax highlighting for markdown
- [x] Create real-time preview system (WebKit-based)
- [x] Implement basic text editing operations
- [x] Add undo/redo functionality (NSTextView provides this)
- [x] Fix concurrency issues with MainActor isolation

### 2.2 Note Management ✅ COMPLETE
- [x] File creation, deletion, renaming
- [x] Folder organization system
- [x] Note templates functionality
- [x] Auto-save implementation
- [x] File watcher for external changes
- [x] Fix compilation errors in FileOperations
- [x] Complete integration with UI components

---

## Phase 3: Knowledge Graph & Linking (Weeks 5-6)

### 3.1 Note Linking System
- [ ] Implement wiki-style linking (`[[Note Title]]`)
- [ ] Backlink detection and management
- [ ] Tag system implementation (#tags)
- [ ] Reference counting and validation
- [ ] Broken link detection

### 3.2 Metal-Accelerated Graph View
- [ ] Design graph layout algorithms
- [ ] Implement Metal shaders for node/edge rendering
- [ ] Add interactive graph navigation
- [ ] Optimize for smooth 60fps performance
- [ ] Add graph filtering and search

---

## Phase 4: Advanced Features (Weeks 7-8)

### 4.1 Enhanced UI with Metal
- [ ] Smooth scrolling and zooming
- [ ] Animated transitions between views
- [ ] High-performance text rendering with Metal
- [ ] Custom Metal-based UI components
- [ ] Performance profiling and optimization

### 4.2 Search & Discovery
- [ ] Full-text search implementation
- [ ] Fuzzy matching for note discovery
- [ ] Search result highlighting
- [ ] Recently accessed notes tracking
- [ ] Advanced search filters and operators

---

## Phase 5: Polish & Extensions (Weeks 9-10)

### 5.1 User Experience
- [ ] Themes and customization system
- [ ] Comprehensive keyboard shortcuts
- [ ] Export functionality (PDF, HTML, etc.)
- [ ] Import functionality (Markdown, Obsidian, etc.)
- [ ] Performance optimization and profiling

### 5.2 Advanced Knowledge Management
- [ ] Block-based editing (Logseq-style)
- [ ] Daily notes functionality
- [ ] Query system for notes
- [ ] Plugin architecture foundation
- [ ] Collaborative features planning

---

## Technical Architecture

### Project Structure
```
Iron/
├── Sources/Iron/
│   ├── Core/
│   │   ├── Models/          # Data models and entities
│   │   ├── Storage/         # File system and persistence
│   │   └── Search/          # Search and indexing
│   ├── UI/
│   │   ├── Views/           # SwiftUI views
│   │   ├── Components/      # Reusable UI components
│   │   └── Metal/           # Metal rendering code
│   ├── Features/
│   │   ├── Editor/          # Text editing functionality
│   │   ├── Graph/           # Graph visualization
│   │   └── Navigation/      # App navigation
│   └── App/                 # App entry point and configuration
```

### Metal Integration Points
- [ ] Custom Metal view for graph visualization
- [ ] Metal Performance Shaders for text layout optimization
- [ ] Metal-backed Core Animation for smooth transitions
- [ ] Compute shaders for search indexing acceleration

---

## Development Milestones

### Milestone 1: Basic Functionality (End of Phase 2)
- [ ] Can create and edit markdown notes
- [ ] Basic file management works
- [ ] Simple navigation between notes

### Milestone 2: Knowledge Graph (End of Phase 3)
- [ ] Note linking system functional
- [ ] Interactive graph view with Metal acceleration
- [ ] Backlinks and tags working

### Milestone 3: Enhanced Experience (End of Phase 4)
- [ ] Metal-accelerated UI components
- [ ] Comprehensive search functionality
- [ ] Performance optimizations complete

### Milestone 4: Production Ready (End of Phase 5)
- [ ] All core features implemented
- [ ] Export/import functionality
- [ ] Plugin architecture ready
- [ ] Performance benchmarks met

---

## Success Metrics

- [ ] **Performance**: 60fps in graph view with 1000+ notes
- [ ] **Responsiveness**: Sub-100ms search results
- [ ] **Memory**: Efficient handling of large note collections
- [ ] **User Experience**: Smooth animations and transitions
- [ ] **Functionality**: Feature parity with core Obsidian/Logseq features

---

## Risk Mitigation

### Technical Risks
- [ ] Metal learning curve - allocate extra time for R&D
- [ ] Performance bottlenecks - implement early profiling
- [ ] Cross-platform considerations - start macOS-only

### Scope Risks  
- [ ] Feature creep - stick to core functionality first
- [ ] Over-engineering - build incrementally
- [ ] Timeline pressure - prioritize MVP features

---

## Phase 2 Implementation Summary ✅ COMPLETE

### Successfully Implemented Components:
- **MarkdownEditor**: NSTextView-based editor with syntax highlighting and smart formatting
- **MarkdownSyntaxHighlighter**: Real-time syntax highlighting with color schemes and regex patterns
- **MarkdownPreview**: WebKit-based live preview with HTML rendering and link handling
- **EnhancedEditorView**: Split-pane editor with toolbar, formatting buttons, and auto-save
- **NoteManager**: Advanced note operations including templates, auto-save, and file watching
- **FileOperations**: Import/export utilities for Markdown, HTML, and plain text formats

### Technical Achievements:
- **Swift 6.2 Concurrency**: All @MainActor isolation issues resolved
- **NSTextView Integration**: Proper actor isolation for text view operations
- **File Operations**: Synchronous file enumeration with proper error handling
- **Build Status**: Clean build with zero warnings or errors

### Key Features Delivered:
- Real-time markdown syntax highlighting with comprehensive pattern matching
- Live HTML preview with CSS styling for light/dark themes
- Split-pane editing interface with configurable layout
- Auto-save functionality with configurable intervals and debouncing
- Note templates system with built-in templates (Meeting, Daily, Project, Basic)
- File watching for external changes with proper Sendable compliance
- Import/export capabilities for multiple formats
- Batch file operations (rename, tag addition, move operations)

---

## Notes

- This plan is iterative - each phase should result in a functional improvement
- Metal integration should be incremental, not blocking basic functionality
- User testing should begin after Milestone 1
- Performance benchmarking should start in Phase 4
- Swift 6.2 strict concurrency mode requires careful actor isolation