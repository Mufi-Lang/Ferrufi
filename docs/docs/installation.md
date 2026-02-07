# Installation

Ferrufi is currently available for macOS. Follow the instructions below to get started.

## Automatic Installation

The fastest way to install Ferrufi is using our official installation script. This script will download the latest experimental release, install it to your `/Applications` folder, and handle initial setup.

Run the following command in your terminal:

```bash
curl -sSL https://raw.githubusercontent.com/Mufi-Lang/Ferrufi/main/scripts/install.sh | bash
```

### Script Options

You can pass arguments to the installer by running it via `bash`. For example, to auto-accept prompts:

```bash
curl -sSL https://raw.githubusercontent.com/Mufi-Lang/Ferrufi/main/scripts/install.sh | bash -s -- --yes
```

Common options:
- `--yes`: Auto-accept all prompts.
- `--install-dir <path>`: Install to a custom directory instead of `/Applications`.
- `--no-quarantine`: Skip the `xattr -cr` step (not recommended).
- `--uninstall`: Remove Ferrufi from your system.

## Manual Installation

If you prefer to install manually:

1. Download the latest `.zip` archive from the [GitHub Releases](https://github.com/Mufi-Lang/Ferrufi/releases) page.
2. Extract the archive to find `Ferrufi.app`.
3. Move `Ferrufi.app` to your `/Applications` folder.
4. Open your terminal and remove the quarantine attribute:
   ```bash
   xattr -cr /Applications/Ferrufi.app
   ```
5. (Optional but recommended) Add to Gatekeeper's allowed list:
   ```bash
   sudo spctl --add --label "Ferrufi" /Applications/Ferrufi.app
   ```

## Prerequisites

- **macOS:** version 26.0 or later.
- **Architecture:** Apple Silicon (M-series) only. Intel-based Macs are not supported.
- **Metal Support:** Required for GPU acceleration.
