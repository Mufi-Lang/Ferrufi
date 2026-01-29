# Build Fixed

The `swift build` command now completes successfully.

## Fixes Applied

1.  **`Sources/Ferrufi/Core/Storage/FileService.swift`**
    -   Ambiguity between `Files` package `Folder` and `Ferrufi` module `Folder` was resolved.
    -   Updated all references to use `Files.Folder` and `Files.File` explicitly when interacting with the `Files` package.

2.  **`Sources/Ferrufi/UI/Views/ScriptCreationView.swift`**
    -   Fixed `property must be declared private` errors.
    -   Changed `availableFolders` and `suggestedFolder` to `private var` to match the access level of the private type alias `FerrufiFolder`.

## Current Status
-   `swift build` passes.
-   Linker warning about `libmufiz.dylib` version (26.2 vs 26.0) is present but non-blocking.
