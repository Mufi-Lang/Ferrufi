# Plan: Initial Linux Support (Full IDE Port)

## Phase 1: Foundation & Abstraction
- [x] Task: Abstract Platform-Specific Core Logic a221e98
    - [x] Identify AppKit/Foundation-specific dependencies in `Sources/Ferrufi/Core`.
    - [x] Introduce conditional compilation blocks (`#if os(macOS)` / `#if os(Linux)`).
    - [x] Create protocols for platform-specific services (File Storage, Notifications).
- [x] Task: Linux Build System Setup b69bada
    - [x] Create a `docker-compose.yml` for Linux build environment (Swift + Zig + GTK dependencies).
    - [x] Update `Package.swift` to handle Linux targets and dependencies.
- [ ] Task: Conductor - User Manual Verification 'Phase 1: Foundation & Abstraction' (Protocol in workflow.md)

## Phase 2: Mufi Runtime & Rendering
- [ ] Task: Recompile Mufi Runtime for Linux
    - [ ] Port Zig build logic to produce `libmufiz.so`.
    - [ ] Update `CMufi` module map and linker settings for Linux.
- [ ] Task: Vulkan Rendering Backend (Foundation)
    - [ ] Implement basic Vulkan initialization logic.
    - [ ] Create a shared `Renderer` protocol to abstract Metal vs. Vulkan.
- [ ] Task: Conductor - User Manual Verification 'Phase 2: Mufi Runtime & Rendering' (Protocol in workflow.md)

## Phase 3: UI Porting (Initial)
- [ ] Task: Setup Linux UI Framework
    - [ ] Integrate Adwaita-Swift or GTK-Swift into the project.
    - [ ] Implement a basic "Hello Linux" window.
- [ ] Task: Port Core Views
    - [ ] Implement basic Editor and Sidebar views using the Linux UI framework.
    - [ ] Integrate Vulkan text rendering into the Linux UI.
- [ ] Task: Conductor - User Manual Verification 'Phase 3: UI Porting (Initial)' (Protocol in workflow.md)
