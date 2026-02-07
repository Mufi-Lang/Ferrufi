# Ferrufi

Ferrufi is a native macOS editor and lightweight IDE built around the Mufi programming language.  
It focuses on a smooth, native experience with fast text rendering, an integrated REPL, and a compact toolchain for authoring and running Mufi code.

---

## Features
- Native macOS UI with Metal-accelerated rendering
- Theme support (light / dark + custom themes)
- Integrated Mufi REPL and embedded runtime (`libmufiz.dylib`)
- Built-in compile/run workflows and quick-run
- Project/workspace support and CLI launcher (`ferrufi`)
- Syntax highlighting (Mufi), auto-complete
- Lightweight distribution scripts for building and installing releases

---

## Quick Install (macOS)

Ferrufi can be built from source and installed to your Applications folder with a single command:

```bash
curl -fsSL https://raw.githubusercontent.com/Mufi-Lang/Ferrufi/main/scripts/installer.sh | bash
```

This script will:
1. Clone the repository into a temporary folder.
2. Build the application and its dependencies (requires Xcode Command Line Tools).
3. Install `Ferrufi.app` to `/Applications`.
4. Create a CLI launcher at `/usr/local/bin/ferrufi`.
5. Clean up the temporary build files.

---

Usage:
- Open a folder as workspace from terminal:
```bash
ferrufi /path/to/folder
```
or
```bash
open -a Ferrufi --args /path/to/folder
```

---

## Roadmap (high level)

Planned/ongoing improvements:
- Language Server Protocol (LSP) integration
- Code folding, linting, and formatter hooks
- Notarized installers and official packaged releases
- Expanded automated tests (editor flows, permissions, runtimes)
- Enhanced in-app documentation and authoring tooling

---

## Contributing
We welcome contributions — issues, PRs, and feedback.

- Please open issues for bugs and feature requests at:
  `https://github.com/Mufi-Lang/Ferrufi/issues`
- For code contributions:
  - Fork the repo, make small focused changes, add tests where applicable, and open a PR.
  - Run the local build (`./scripts/build_app.sh --zip`) and any relevant checks before submitting.

See project docs in `plans/` for additional developer notes (e.g., linking tests and binary layout).

---

## Documentation
Helpful docs:
- `DISTRIBUTION_QUICKSTART.md` — packaging and distribution notes
- `plans/DISTRIBUTION.md` — full distribution guide
- `plans/FILE_ACCESS_FIX.md` — file permission / entitlement guidance
- `MEMORY_SAFETY.md` — runtime safety and crash-avoidance notes

---

## Settings Implementation Status

Ferrufi features a unified global settings system. Below is the current status of various preferences:

| Category | Feature | Status |
| :--- | :--- | :--- |
| **General** | Launch at Login, Confirm Before Quit, Auto-updates | ✅ Fully Functional |
| | Startup Behavior (Restore / Welcome / Specific Note) | ✅ Fully Functional |
| **Workspace** | Workspace Location Management (Security-scoped) | ✅ Fully Functional |
| | Auto-save Interval, External File Watching | ✅ Fully Functional |
| **Editor** | Font Family & Size, Line Height | ✅ Fully Functional |
| | Word Wrap, Line Numbers | ✅ Fully Functional |
| | Syntax Highlighting (Mufi) | ✅ Fully Functional |
| | Auto-complete, Spell Check | 🚧 In Progress |
| **Search** | Global Indexing, Fuzzy Threshold | ✅ Fully Functional |
| | Search Scope (Content vs Titles), Case Sensitivity | ✅ Fully Functional |
| **UI** | Professional Themes (16+ variants), System Theme sync | ✅ Fully Functional |
| | Metal Acceleration, Animation Control | ✅ Fully Functional |
| **Shortcuts** | Custom Key Bindings | 🚧 UI Ready / Logic In Progress |

---

## License
This project is licensed under the MIT License — see `LICENSE` for details.

---

Thanks for checking out Ferrufi! If you have questions or need help getting set up, open an issue or drop a short note in a PR.