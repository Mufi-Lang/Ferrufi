# Iron Simplified Storage System

## Overview

Iron now uses a simple, centralized storage system at `~/.iron` for all your notes. There are no "vaults" to manage - just one location for all your knowledge.

## What Changed

### Before (Vault System)
- Users had to create and manage multiple vaults
- Vault picker interface for selection
- Complex directory structures with vault metadata
- Confusing TextField editing issues in vault creation

### After (Simplified System)
- Single storage location at `~/.iron/notes/`
- No vault management or selection needed
- Direct startup into the main application
- Clean, simple directory structure

## Directory Structure

```
~/.iron/
├── config.json              # Iron configuration
└── notes/                    # All your markdown files
    ├── Welcome.md
    └── [your notes].md
```

## Benefits

1. **Zero Configuration**: No setup or vault creation needed
2. **Instant Start**: App launches directly into note-taking
3. **Simple Backup**: Just backup `~/.iron` directory
4. **Familiar Structure**: Similar to other simple note apps
5. **No Confusion**: No vault concepts to understand

## How It Works

### First Launch
1. Iron automatically creates `~/.iron/notes/`
2. Creates a welcome note to get you started
3. Launches directly into the main interface
4. You can immediately start creating and editing notes

### Daily Usage
- All notes are stored in `~/.iron/notes/`
- Use folders within notes/ to organize content
- Search works across all your notes
- No vault switching or management needed

## File Structure

### Configuration (`~/.iron/config.json`)
```json
{
  "vault": {
    "defaultVaultPath": "~/.iron/notes",
    "autoSaveInterval": 30.0,
    "fileWatchingEnabled": true,
    "backupEnabled": true
  },
  "editor": {
    "fontSize": 14.0,
    "fontFamily": "SF Mono",
    "syntaxHighlighting": true,
    "livePreview": true
  }
}
```

### Welcome Note (`~/.iron/notes/Welcome.md`)
```markdown
# Welcome to Iron!

This is your Iron knowledge management system. Your notes are stored in `~/.iron/notes/`.

## Getting Started
- Create and organize your notes
- Use markdown formatting for rich text
- Link between notes using [[Note Name]] syntax
- Search across all your content

## Features
- **Markdown Editor**: Full markdown support with live preview
- **Note Linking**: Create connections between your ideas
- **Search**: Find anything across your notes
- **File Organization**: Organize notes in folders

Happy note-taking! 📝
```

## Technical Implementation

### Automatic Setup
The app automatically:
1. Creates `~/.iron` directory on first run
2. Creates `notes` subdirectory for your files
3. Generates a welcome note if none exists
4. Initializes configuration with sensible defaults

### Code Changes
- Removed `VaultManager` and vault picker UI
- Updated `ContentView` to skip vault selection
- Changed default storage path to `~/.iron/notes`
- Simplified configuration to use `~/.iron/config.json`

### Key Benefits Over Vault System
- **No TextField Issues**: Eliminated the problematic vault name editing
- **Faster Startup**: Direct launch without vault selection
- **Less Complexity**: No vault management code or UI
- **Better UX**: Familiar single-folder approach

## Migration from Vault System

If you previously had vaults created:
1. Copy your markdown files from old vault locations
2. Place them in `~/.iron/notes/`
3. Organize in subfolders as needed
4. Delete old vault directories when ready

## Usage Examples

### Organizing Notes
```
~/.iron/notes/
├── Projects/
│   ├── Iron Development.md
│   └── Website Redesign.md
├── Learning/
│   ├── Swift Concurrency.md
│   └── SwiftUI Tips.md
├── Personal/
│   └── Daily Journal.md
└── Welcome.md
```

### Linking Notes
Use `[[Note Name]]` syntax to link between notes:
```markdown
See my notes on [[Swift Concurrency]] for more details.
Check out the [[Iron Development]] project status.
```

## Troubleshooting

### Common Issues

**App won't start**
- Check if `~/.iron` directory is writable
- Verify sufficient disk space
- Look for permission errors in console

**Notes not appearing**
- Ensure files are in `~/.iron/notes/` directory
- Check file extensions are `.md` or `.markdown`
- Verify files are valid UTF-8 text

**Configuration issues**
- Delete `~/.iron/config.json` to reset to defaults
- Check JSON syntax if manually edited
- Restart Iron after configuration changes

### Debug Information

Iron logs helpful information:
- `Iron directory structure created at: ~/.iron`
- `Created welcome note at: ~/.iron/notes/Welcome.md`
- `Initialized with notes directory: ~/.iron/notes`

## Future Enhancements

Planned simplifications:
- **Cloud Sync**: Optional syncing to iCloud or other services
- **Import/Export**: Bulk operations for note management
- **Themes**: Simple appearance customization
- **Extensions**: Plugin system for additional functionality

## Developer Notes

### Architecture Benefits
- **Reduced Complexity**: Eliminated entire vault management system
- **Better Performance**: No vault switching overhead
- **Simpler Code**: Less UI state management needed
- **Fewer Bugs**: Removed problematic vault picker code

### Implementation Details
- All file operations target `~/.iron/notes/`
- Configuration stored in `~/.iron/config.json`
- Automatic directory creation on first run
- Welcome note generated if no notes exist

## Conclusion

The simplified system eliminates the vault concept entirely, providing:

- **Immediate Usability**: No setup required, just start taking notes
- **Familiar Experience**: Works like other simple note-taking apps  
- **Zero Confusion**: No vault management or selection needed
- **Clean Architecture**: Simpler codebase without vault complexity

This approach completely avoids the original TextField editing issue by removing the vault creation UI entirely. Iron now focuses purely on what matters: taking and organizing notes.