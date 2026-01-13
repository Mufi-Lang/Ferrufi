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
- Syntax highlighting (Mufi, Markdown), auto-complete, Markdown preview
- Lightweight distribution scripts for building and installing releases

---

## Quick Install (macOS)

Recommended: inspect before running any remote script.

- One-liner (downloads the latest release; falls back to `experimental` prerelease if no official `latest` exists):
```bash
curl -fsSL https://raw.githubusercontent.com/Mufi-Lang/Ferrufi/main/scripts/install_release.sh | sh
```

- Safer: download first, inspect, then run:
```bash
curl -fsSL -o /tmp/install_release.sh https://raw.githubusercontent.com/Mufi-Lang/Ferrufi/main/scripts/install_release.sh
less /tmp/install_release.sh
sh /tmp/install_release.sh
```

- Install from a locally-built `.app`:
  - System (requires `sudo`):
    ```bash
    sudo ./scripts/install_app.sh /path/to/Ferrufi.app
    ```
  - Per-user (no `sudo`):
    ```bash
    ./scripts/install_app.sh /path/to/Ferrufi.app --user
    ```

- Manual alternative:
```bash
sudo ditto -v /path/to/Ferrufi.app /usr/local/bin/Ferrufi.app
sudo ln -sfn /usr/local/bin/Ferrufi.app /Applications/Ferrufi.app
sudo ln -sf /usr/local/bin/Ferrufi.app/Contents/MacOS/Ferrufi /usr/local/bin/ferrufi
sudo xattr -dr com.apple.quarantine /usr/local/bin/Ferrufi.app || true
```

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

## Build (for distribution)

- Quick build and zip (recommended for producing distributable `.app` + `.zip`):
```bash
./scripts/build_app.sh --zip
```

- Create a DMG:
```bash
./scripts/build_dmg_local.sh
```

See `DISTRIBUTION_QUICKSTART.md` and `docs/DISTRIBUTION.md` for more details and packaging guidance.

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

See project docs in `docs/` for additional developer notes (e.g., linking tests and binary layout).

---

## Documentation
Helpful docs:
- `DISTRIBUTION_QUICKSTART.md` — packaging and distribution notes
- `docs/DISTRIBUTION.md` — full distribution guide
- `docs/FILE_ACCESS_FIX.md` — file permission / entitlement guidance
- `MEMORY_SAFETY.md` — runtime safety and crash-avoidance notes

---

## License
This project is licensed under the MIT License — see `LICENSE` for details.

---

Thanks for checking out Ferrufi! If you have questions or need help getting set up, open an issue or drop a short note in a PR.