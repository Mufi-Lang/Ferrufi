# TODO: Unify editor fonts and add file-type chooser for creating notes

Goal
- Ensure the editor uses a consistent monospaced font for Mufi editing.
- Use `.mufi` as the exclusive file type for notes; remove Markdown support and any preview-related UI options.
- Propagate file type selection through the app's create-note APIs where applicable.

Priority: High — affects user workflow, file type consistency, and UI clarity.

Overview of changes
1. API: add an explicit `fileExtension` (or small enum) parameter to note creation APIs.
   - `FolderManager.createNote(name:content:folder:fileExtension:)`
   - `FerrufiApp.createNote(title:content:in:fileExtension:)`
   - Update pass-throughs in `NoteManager`, `NavigationModel`, and UI callers.

2. UI: ensure the Create Note UI reflects the single supported file type (Mufi).
  - Expose option: `Mufi (.mufi)` only.
  - Use the selected value when calling `FerrufiApp.createNote(...)` where applicable.

3. Editor font: ensure `UnifiedTextView` uses the same monospaced font for `.mufi` mode.
  - Update `setupForMode(_:)` in `UnifiedEditor.swift` to set the same NSFont for the editor.
  - Ensure previews and other renderers show code/script content in a monospaced font so visual parity is maintained.

4. Normalize defaults:
  - Decide on the app default extension for the "Create Note" button (use `.mufi` by default).
  - Update `FileStorage.createNote` and other helpers to accept/forward `fileExtension` where appropriate, or ensure higher-level APIs always set it.

Files to modify (locations & suggested edits)

- `FolderManager.createNote(...)` (current: forces `.mufi`)
  - Path: `Ferrufi/Sources/Ferrufi/Core/Models/Folder.swift`
  - Change signature to accept `fileExtension: String = ".md"` and use it to compose the filename.

  Suggested change (conceptual):
  - Before:
    - Forces `.mufi`:
      - `let fileName = name.hasSuffix(".mufi") ? name : "\(name).mufi"`
  - After:
    - Use provided extension:
      - `let fileName = name.hasSuffix(fileExtension) ? name : "\(name)\(fileExtension)"`

- `FerrufiApp.createNote(...)`
  - Path: `Ferrufi/Sources/Ferrufi/Ferrufi.swift`
  - Add parameter `fileExtension: String = ".md"` and pass it to `folderManager.createNote(...)`.

- `NoteManager.createNote(...)` and other API wrappers
  - Update these helpers to accept/forward `fileExtension` if they call `FerrufiApp.createNote`, or call the updated `FerrufiApp.createNote(..., fileExtension:)` with a default.

- `NoteCreationSheet` UI
  - Path: `Ferrufi/Sources/Ferrufi/UI/Views/NoteCreationView.swift`
  - Add state for file type selection:
    - `@State private var selectedFileType: String = ".mufi"`
  - Add a segmented control or Picker near the name input:
    - Example UI (segmented): `Picker("File Type", selection: $selectedFileType) { Text("Mufi").tag(".mufi") }.pickerStyle(.segmented)`
  - Use `selectedFileType` when calling `ferrufiApp.createNote(...)`:
    - `let newNote = try await ferrufiApp.createNote(title: noteTitle, content: scriptContent, in: targetFolder, fileExtension: selectedFileType)`

- Editor font unification
  - Renderer styling
    - Path: `Ferrufi/Sources/Ferrufi/Features/Editor/UnifiedEditor.swift`
    - Ensure `UnifiedTextView.setupForMode(_:)` sets the monospaced NSFont consistently for the editor (prefer `.mufi` settings), e.g.:
      - `self.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)`
    - Consider centralizing the font in a single constant or a `ThemeManager` accessor (e.g., `themeManager.editorFont`) to keep sizes and styles consistent across components.

- Preview styling
  - Path: `Ferrufi/Sources/Ferrufi/UI/Components/PreviewHost.swift` (or where preview is implemented)
  - If the preview is SwiftUI views, apply `.font(.system(size: 14, design: .monospaced))` where appropriate for code blocks or for whole preview if desired.
  - If preview generates HTML/CSS, ensure the CSS for `pre`, `code`, and main text uses the same monospaced family to match editor.

- FileStorage.createNote and other helpers
  - Path: `Ferrufi/Sources/Ferrufi/Core/Storage/FileStorage.swift`
  - Either update to accept `fileExtension` or document and ensure it is only used where `.md` is appropriate (e.g., `FileStorage.createNote` can default to `.md` but higher-level `FolderManager` will be used for flexible creation).

Implementation details / code snippets (conceptual)

- FolderManager change (conceptual)
  ```
  // Folder.swift
  public func createNote(
      name: String,
      content: String,
      folder: Folder?,
      fileExtension: String = ".mufi"
  ) async throws -> Note {
      let targetFolder = folder ?? rootFolder
      let fileName = name.hasSuffix(fileExtension) ? name : "\(name)\(fileExtension)"
      let fileURL = targetFolder.url.appendingPathComponent(fileName)
      let filePath = fileURL.path
      // write via FileService...
  }
  ```

- FerrufiApp change (conceptual)
  ```
  // Ferrufi.swift
  public func createNote(
      title: String,
      content: String = "",
      in folder: Folder? = nil,
      fileExtension: String = ".mufi"
  ) async throws -> Note {
      let contentToUse = content.isEmpty ? "// \(title)\n// Created on \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short))\n\n" : content
      let note = try await folderManager.createNote(
          name: title, content: contentToUse, folder: folder, fileExtension: fileExtension)
      // index, append to notes, return
  }
  ```

- NoteCreationSheet change (conceptual)
  ```
  // NoteCreationView.swift
  @State private var selectedFileType: String = ".mufi"

  // Inside the UI near inputs:
  Picker("File Type", selection: $selectedFileType) {
      Text("Mufi").tag(".mufi")
  }
  .pickerStyle(.segmented)

  // When creating:
  let newNote = try await ferrufiApp.createNote(
      title: noteTitle,
      content: scriptContent,
      in: targetFolder,
      fileExtension: selectedFileType
  )
  ```

Testing & verification steps

1. Build
   - Run `swift build` and fix compile errors from changed signatures.

2. Manual UI tests
   - Open the Create Note sheet and verify the file-type control appears and defaults to `.mufi`.
   - Create a `.mufi` note; check the selected folder — only one `.mufi` file should be created.
   - Create from other flows (duplicate, templates) and verify they follow the `.mufi` defaults where applicable.

3. Editor font verification
   - Open both a `.md` and a `.mufi` note in the editor (UnifiedEditor). Ensure the editor uses the same monospaced font and size for both.
   - Open preview and ensure code blocks or overall preview use the matching monospaced font where appropriate.

4. Regression checks
   - Verify other creation flows (welcome note, duplication, import) still work and produce consistent extensions. Update call sites to pass `fileExtension` if needed.
   - Run any unit tests and do a smoke test for creating/opening/saving notes.

Optional improvements / follow-ups
- Replace `String` fileExtension with a typed enum:
  ```
  public enum NoteFileType: String, Sendable {
      case mufi = ".mufi"
  }
  ```
  This offers stronger typing and easier future extension (e.g., `.rich`).

- Add an app preference for the default new-note type (Defaults stored in `ConfigurationManager`).

- Expose editor font/size via `ThemeManager` so the user can change font size globally and have it apply everywhere.

Estimated effort
- API + call-site changes: ~30–60 minutes (depends on number of call sites).
- UI change (Picker) + wiring: ~20–40 minutes.
- Editor font/preview tweaks: ~15–30 minutes.
- Testing & polish: ~30–60 minutes.

If you want, I can implement the minimal, pragmatic approach now:
- Add `fileExtension: String` parameter to `FerrufiApp.createNote` and `FolderManager.createNote`.
- Add `selectedFileType` Picker to `NoteCreationSheet` and wire creation to pass it.
- Ensure `UnifiedTextView` sets identical monospaced font for `.markdown` and `.mufi`.

Tell me to proceed and which default file type you prefer (`.md` or `.mufi`). I'll then:
1. Implement the API changes and update call sites.
2. Add the UI picker and wire the value.
3. Unify the editor font and adjust preview styling.
4. Run the build and report back with any required follow-ups or fixes.

---
Note: Notebook-style execution formats and text-first workflows have been deprecated and are no longer part of the implementation plan for this TODO. This document now focuses on unifying the editor font and using `.mufi` as the primary note file type. If you'd like to revisit notebook-style features later, please open an issue to discuss scope and requirements.