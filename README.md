# Ferrufi

Ferrufi is a native macOS editor and lightweight IDE built around the Mufi programming language.  
It combines an integrated REPL and compiler runner with a high-performance, Metal-accelerated UI for smooth text rendering and scrolling.  
The editor focuses on a polished developer experience (theme selector, live preview, and first-class Mufi execution), while exposing a simple CLI for scripting and automation.

## Features
- Metal-accelerated UI (GPU rendering for smooth scrolling and SDF text)
- Theme selector (light/dark and custom theme support)
- REPL mode (inline split or floating sheet)
- Built-in compiler runner (embedded CMufi runtime and optional external runner)
- Project creation, run and quick-run workflows
- Integrated documentation viewer and quick reference search
- CLI launcher (installable via `scripts/install_app.sh`) to expose `ferrufi` on your PATH — once installed you can open Ferrufi from your terminal for any folder:
  - Open a specific directory as the vault: `ferrufi /path/to/folder`
  - Open the current directory as the vault: `ferrufi .`
  You can also use the macOS `open` helper: `open -a Ferrufi --args /path/to/folder`

  Note: when launched with a directory argument, Ferrufi will initialize that directory as the vault root (creating it if necessary) and will skip the one-time onboarding flow.
- Editor features: syntax highlighting (Mufi and Markdown), auto-complete, live preview, and word count

This project is actively developed. Contributions and suggestions are welcome!

## Roadmap / TODOs
- Complete and extend syntax highlighting and language modes
- Built-in documentation authoring and improved in-app docs viewer
- Language Server (LSP) integration for enhanced completion and refactoring
- Code folding, linting, and formatter hooks
- Notarized installer and packaged releases
- Expanded automated tests for editor flows and permission handling

## Quick Start - Building for Distribution

### Build Standalone App (Recommended)

Create a distributable `.app` bundle with optional zip archive:

```bash
# Quick build
./scripts/build_app.sh --zip

# This creates:
# - Ferrufi.app (ready to use)
# - Ferrufi-X.Y.Z-macos.zip (for sharing)
```

### Build DMG (Alternative)

Create a traditional DMG installer:

```bash
./scripts/build_dmg_local.sh
```

**See [DISTRIBUTION_QUICKSTART.md](DISTRIBUTION_QUICKSTART.md) for more options and [docs/DISTRIBUTION.md](docs/DISTRIBUTION.md) for complete guide.**

**Note:** Apps are built with entitlements for file access. See [docs/FILE_ACCESS_FIX.md](docs/FILE_ACCESS_FIX.md) if you experience file editing issues.

## Install (macOS)

We provide a helper installer script that copies `Ferrufi.app` into `/Applications` (or `~/Applications` for a per-user install), installs a CLI launcher at `/usr/local/bin/ferrufi`, and allows you to open Ferrufi directly from the terminal for any folder. For example:

- Open a specific directory as the vault:
  `ferrufi /path/to/folder`

- Open the current working directory as the vault:
  `ferrufi .`

You can also achieve the same with macOS's `open` helper:
`open -a Ferrufi --args /path/to/folder`

- System install (requires sudo):
```bash
sudo ./scripts/install_app.sh /path/to/Ferrufi.app
```

- Per-user install (no sudo):
```bash
./scripts/install_app.sh /path/to/Ferrufi.app --user
```

Manual alternative:
```bash
# Copy the app bundle into /usr/local/bin (preserves metadata)
sudo ditto -v /path/to/Ferrufi.app /usr/local/bin/Ferrufi.app

# Create a /Applications symlink pointing to the installed bundle
sudo ln -sfn /usr/local/bin/Ferrufi.app /Applications/Ferrufi.app

# Create a CLI symlink to the bundled executable
sudo ln -sf /usr/local/bin/Ferrufi.app/Contents/MacOS/Ferrufi /usr/local/bin/ferrufi

# If Gatekeeper blocks the app on first launch, clear quarantine:
sudo xattr -dr com.apple.quarantine /usr/local/bin/Ferrufi.app || true
```

The install script also attempts to remove quarantine and prints handy instructions when elevated privileges are required.

Quick install (curl one-liner — app + CLI)
- Run the release installer (this will download the release, place `Ferrufi.app` into `/usr/local/bin/Ferrufi.app`, create `/Applications/Ferrufi.app -> /usr/local/bin/Ferrufi.app`, and set up the CLI at `/usr/local/bin/ferrufi`):

```bash
curl -fsSL https://raw.githubusercontent.com/Mufi-Lang/Ferrufi/main/scripts/install_release.sh | sh
```

Security note: piping a remote script directly into a shell can be risky. We strongly recommend that you download and inspect the script before running it:

```bash
curl -fsSL -o /tmp/install_release.sh https://raw.githubusercontent.com/Mufi-Lang/Ferrufi/main/scripts/install_release.sh
less /tmp/install_release.sh   # verify contents
sh /tmp/install_release.sh
```

Mufi Integration
- The project now includes native integration with the Mufi runtime via a system library.
  - Place the runtime artifacts into `include/`:
    - `include/mufiz.h` (C header)
    - `include/libmufiz.dylib` (dynamic library)
  - A system library target `CMufi` (under `Sources/CMufi`) exposes the header to Swift via a `module.modulemap`.
  - The Swift wrapper is implemented at `Sources/Ferrufi/Integrations/Mufi/MufiBridge.swift`. It provides an actor-based API to:
    - initialize the runtime (`mufiz_init`),
    - interpret Mufi source strings (`mufiz_interpret`) while capturing stdout/stderr,
    - and deinitialize (`mufiz_deinit`).
- Building and runtime notes
  - Build with `swift build` (or use the provided `build_macos.sh` for an Xcode-based build).
  - **Important:** If you're using a pre-built `libmufiz.dylib`, ensure it has the correct macOS deployment target:
    - Run `./scripts/fix_mufiz_deployment_target.sh` to update the dylib's deployment target to macOS 14.0 (matching the Swift package requirement). This fixes linker warnings about version mismatches.
  - After building, ensure the dynamic library is placed where the runtime loader can find it. A helper script is included for this:
    - `./scripts/copy_mufiz_dylib.sh` — copies `include/libmufiz.dylib` into `.build/*/(debug|release)/` directories so `swift run` or locally-built executables can locate it at runtime. `build_macos.sh` invokes this script automatically.


## Using the Mufi-Lang REPL in the Editor

### Quick Start

The Mufi REPL is integrated directly into the editor toolbar for immediate access:

1. **Open any note** in Ferrufi
2. **Look for the toolbar** at the top of the editor (above the text area)
3. **Click the terminal icon** (🖥️) to toggle the REPL panel
4. **Click the play button** (▶️) to run your Mufi code

### Toolbar Buttons

The editor toolbar includes these Mufi-specific buttons:

- **Play Button (▶️)**: Runs the entire note content as a Mufi script
  - Keyboard shortcut: `⌘R`
  - Shows output in a popup window
  - Initializes the runtime automatically

- **Terminal Icon (🖥️)**: Toggles the inline REPL panel
  - Keyboard shortcut: `⌃⌘R` (Control+Command+R)
  - Shows/hides REPL as a split pane on the right side
  - Allows interactive Mufi code execution

### Three Ways to Use the REPL

#### 1. Inline Split Mode (Recommended)
- Click the **terminal button** in the toolbar
- The REPL appears as a panel on the right side
- Write code in the editor (left), test in REPL (right)
- Perfect for development and testing

#### 2. Run Full Scripts
- Write your Mufi code in the note
- Click the **play button** in the toolbar (or press `⌘R`)
- View results in a popup window
- Great for running complete programs

#### 3. Sheet Mode (Popup Window)
- Use `Tools > Toggle Mufi REPL` from the menu bar
- Opens REPL in a floating window
- Good for quick experiments without changing editor layout

## Mufi-Lang REPL Mode

Ferrufi includes a fully integrated **Mufi-lang REPL** (Read-Eval-Print Loop) that runs directly in the editor using the embedded CMufi runtime.

### Features

- **Interactive Mufi Execution**: Type Mufi code and see results immediately
- **No External Process**: Uses the embedded `libmufiz.dylib` library via CMufi for fast, in-process execution
- **Inline REPL Mode**: Available as a split pane alongside your editor and preview
- **Sheet Mode**: Can also be opened as a floating window
- **Auto-initialization**: Runtime starts automatically when you open the REPL
- **Output Capture**: Captures all `print()` statements and runtime output

### How to Use the REPL

1. **Open the REPL**:
   - **Method 1 (Toolbar)**: Click the terminal icon (🖥️) in the editor toolbar
   - **Method 2 (Keyboard)**: Press `⌃⌘R` (Control+Command+R)
   - **Method 3 (Menu)**: Select `Tools > Toggle Mufi REPL`

2. **Write Mufi Code**:
   ```mufi
   var x = 42
   print("The answer is: " + str(x))
   
   fn greet(name) {
       return "Hello, " + name + "!"
   }
   print(greet("World"))
   ```

3. **Execute Code**:
   - Type your Mufi expression or statement in the input field
   - Press Enter or click "Send" to execute
   - See the output appear in the console above

4. **Send from Editor**:
   - Write Mufi code in your note
   - Click the arrow button in the REPL header to send the entire note's content to the REPL
   - Perfect for testing scripts before saving

5. **Run Full Scripts**:
   - Click the Play button (▶️) in the editor toolbar (or press `⌘R`)
   - The entire note executes as a Mufi script
   - Results appear in a separate output window
   - Status codes and errors are clearly displayed

### Example Mufi-Lang Code

```mufi
// Variables
var name = "Ferrufi"
var version = 1.0

// Functions
fn calculate(a, b) {
    return a + b * 2
}

// Control flow
if calculate(5, 10) > 20 {
    print("Result is greater than 20")
}

// Loops
var i = 0
while i < 3 {
    print("Loop iteration: " + str(i))
    i = i + 1
}

// Arrays
var items = [1, 2, 3, 4, 5]
print("First item: " + str(items[0]))
```

### Keyboard Shortcuts

| Action | Shortcut | Description |
|--------|----------|-------------|
| Run Mufi Script | `⌘R` | Execute entire note as Mufi code |
| Toggle REPL | `⌃⌘R` | Show/hide inline REPL panel |
| New Note | `⌘N` | Create new note |
| Find | `⌘F` | Search in notes |

### Avoiding Segfaults and Crashes

The REPL includes multiple safety measures to prevent crashes:

✅ **Input Validation**
- Empty input is rejected
- Null bytes are blocked (they break C strings)
- Size limit: 10MB max per script
- UTF-8 encoding is verified

✅ **Timeout Protection**
- REPL commands: 30 second timeout
- Full scripts: 60 second timeout
- Prevents infinite loops from hanging the app

✅ **Memory Safety**
- Autoreleasepool for each execution
- Proper C string lifetime management
- File descriptor cleanup
- Actor-based thread safety

✅ **State Protection**
- Runtime initialized once at app startup
- State validation before each call
- Prevents use-after-deinitialization

**If you experience crashes:**
1. Check that `libmufiz.dylib` is up to date
2. Avoid infinite loops in Mufi code
3. Keep input under size limits
4. Report reproducible crashes as bugs

See `MEMORY_SAFETY.md` for detailed information.

### Technical Details

- **Runtime**: Mufi interpreter (`libmufiz.dylib`) compiled from Zig
- **API**: CMufi system library exposes C functions (`mufiz_init`, `mufiz_interpret`, `mufiz_deinit`)
- **Bridge**: `MufiBridge` actor provides Swift-friendly async API
- **Lifecycle**: Runtime is initialized once when the app starts and deinitialized when the app quits
- **Isolation**: REPL runs on background threads with stdout/stderr capture
- **Thread Safety**: Actor-based design ensures safe concurrent access
- **No Manual Init**: You don't need to initialize or deinitialize the runtime - it's automatic
- **UI Integration**: Native SwiftUI components in `NativeSplitEditor`

### Editor Features
  - **Split Editor**: Left pane for editing, optional right pane for Markdown preview
  - **Formatting Toolbar**: Quick access to bold, italic, code, links, headers, and lists
  - **Preview Toggle**: Show/hide Markdown preview with one click
  - **Run Script**: Execute current note as Mufi code with play button
  - **Inline REPL**: Toggle REPL panel for interactive Mufi development
  - **Auto-save**: Changes are automatically saved as you type
  - **Word Count**: Live word count display in the toolbar

- Fallback and distribution notes
  - There is a process-based fallback runner (using an external `mufiz` executable) implemented in `Sources/Ferrufi/Features/Mufi/MufiRunner.swift` if you prefer running the standalone CLI rather than embedding the library.
  - When preparing a distributable app, bundle `libmufiz.dylib` into the application bundle (for example into `Contents/Frameworks`) or arrange an install location so the app’s dyld can find it at runtime.


### Licensing
This project is licensed under the MIT License.
