# Mufi Editor Guide

## Overview

Ferrufi now provides enhanced support for working with Mufi code while maintaining full markdown functionality. The editor intelligently handles both markdown notes and Mufi scripts with integrated execution and terminal output.

## Features

### 1. Dual-Mode Editor

The editor supports two primary content types:

- **Markdown Notes**: Traditional note-taking with preview, wiki-links, and formatting
- **Mufi Code**: Programming scripts with syntax awareness and execution

Both modes are available simultaneously - you can write markdown documentation with embedded Mufi code blocks, or work with pure Mufi scripts.

### 2. Play Button - Script Execution

The **Play Button** (▶️) in the toolbar executes your Mufi code:

- **Keyboard Shortcut**: `⌘R`
- **Location**: Editor toolbar, right side
- **Behavior**: 
  - Executes the entire content as Mufi code
  - Shows terminal output inline below the editor
  - Displays execution time and exit status
  - Handles both success and error cases gracefully

#### Terminal Output Features

When you run a script, a **terminal panel** appears below the editor showing:

```
┌─────────────────────────────────────────┐
│ ● Terminal          SUCCESS    0.045s   │
├─────────────────────────────────────────┤
│   1 │ Hello, World!                     │
│   2 │ 5 + 3 = 8                         │
│   3 │ Count: 0                          │
│   4 │ Count: 1                          │
│   5 │ Count: 2                          │
└─────────────────────────────────────────┘
```

**Terminal Controls**:
- **🗑️ Clear**: Clear the output
- **▼ Collapse/Expand**: Show or hide output
- **✕ Close**: Hide the terminal panel

**Status Indicators**:
- 🟢 **Green dot + SUCCESS**: Script executed successfully (exit code 0)
- 🔴 **Red dot + ERROR**: Script encountered an error (non-zero exit code)

### 3. REPL Integration

The **REPL Button** (terminal icon) opens an interactive Mufi REPL:

- **Keyboard Shortcut**: `⌃⌘R` (Control-Command-R)
- **Mode**: Opens as a separate sheet for interactive coding
- **Use Case**: Test code snippets, experiment with Mufi syntax

### 4. Editor Display Modes

The `EditorWithREPL` view provides multiple display configurations:

- **Editor Only**: Focus on writing code
- **Editor + Preview**: Markdown editing with live preview
- **Editor + REPL**: Code editing with interactive REPL
- **All Panes**: Editor, Preview, and REPL simultaneously

Switch between modes using the segmented control in the toolbar.

## Workflow Examples

### Example 1: Quick Script Execution

1. Write your Mufi code in the editor:
   ```mufi
   var greeting = "Hello, World!"
   print(greeting)
   
   fn add(a, b) {
       return a + b
   }
   
   print("Result: " + str(add(5, 3)))
   ```

2. Press `⌘R` or click the Play button

3. View the output in the terminal panel below:
   ```
   Hello, World!
   Result: 8
   ```

### Example 2: Debugging with REPL

1. Write your function in the editor
2. Press `⌃⌘R` to open the REPL
3. Test individual functions interactively
4. Refine your code in the editor
5. Run the complete script with `⌘R`

### Example 3: Documented Code

You can mix markdown documentation with Mufi code:

```markdown
# My Mufi Script

This script demonstrates basic arithmetic operations.

## Implementation

var x = 10
var y = 20
var sum = x + y
print("Sum: " + str(sum))
```

Press `⌘R` to run the code portions.

## Keyboard Shortcuts

| Action | Shortcut | Description |
|--------|----------|-------------|
| **Run Script** | `⌘R` | Execute current content as Mufi code |
| **Toggle REPL** | `⌃⌘R` | Open/close interactive REPL |
| **Toggle Terminal** | Click terminal icon | Show/hide output panel |
| **Toggle Preview** | `⌃⌘P` | Show/hide markdown preview |
| **Bold** | `⌘B` | Format selection as bold |
| **Italic** | `⌘I` | Format selection as italic |
| **New Note** | `⌘N` | Create new note/script |

## Terminal Output Details

### Execution Metrics

The terminal displays:
- **Exit Status**: Success (0) or Error (non-zero)
- **Execution Time**: Duration in seconds (e.g., "0.045s")
- **Line Numbers**: Each output line is numbered for reference

### Output Formatting

- Standard output (stdout) is displayed verbatim
- Errors show in the same panel with ERROR status
- Empty output shows "[No output]" message
- Long output is scrollable with automatic scroll-to-bottom

### Terminal Panel Behavior

- **Auto-show**: Terminal automatically appears when you run a script
- **Persistent**: Stays open between runs unless manually closed
- **Resizable**: Fixed height of 250px (may be customizable in future)
- **Collapsible**: Click chevron to collapse while keeping it visible

## Error Handling

When your script encounters an error:

1. Terminal shows **ERROR** status with red indicator
2. Error message is displayed in the output area
3. Execution time is still tracked
4. Exit code is non-zero

Example error output:
```
Error: undefined function 'undefined_function'
at line 2, column 8
```

## Best Practices

### 1. Use Preview for Documentation

Combine code with markdown for self-documenting scripts:
- Use headers (`#`, `##`) to organize sections
- Add comments in code blocks
- Include examples and expected outputs

### 2. Iterative Development

- Write small functions
- Test in REPL first
- Run full script to verify integration
- Check terminal output for correctness

### 3. Performance Testing

The execution timer helps you:
- Benchmark script performance
- Identify slow operations
- Compare different implementations

### 4. Output Management

- Clear terminal output between runs for clarity
- Keep terminal open to compare outputs
- Copy output using text selection when needed

## Technical Details

### Execution Flow

1. User clicks Play or presses `⌘R`
2. Editor content is captured
3. `MufiBridge.shared.interpret()` is called
4. Mufi runtime (`libmufiz.dylib`) executes the code
5. stdout/stderr are captured
6. Results are formatted and displayed in terminal
7. Exit status and timing are recorded

### Safety Features

- **Timeout Protection**: Scripts timeout after 30s (single commands) or 60s (full scripts)
- **Memory Safety**: Bridge uses proper C/Swift interop with `withCString` and autorelease pools
- **Error Isolation**: Crashes in Mufi runtime don't crash the editor
- **Actor Serialization**: Only one script runs at a time

### File Types

The editor works with:
- `.md` - Markdown files (can contain Mufi code blocks)
- `.mufi` - Pure Mufi script files
- Any text content treated as potential Mufi code when executed

## Troubleshooting

### Script Won't Run

- Check that Mufi runtime is initialized (see app logs)
- Verify your syntax is valid Mufi code
- Look for error messages in terminal output

### Terminal Not Appearing

- Click the terminal icon to toggle visibility
- Check that script actually executed (look for spinning indicator)
- Verify you're not in preview-only mode

### Slow Execution

- Check for infinite loops (will timeout after 60s)
- Review execution time in terminal
- Use REPL to test isolated pieces

### Output Not Showing

- Check exit status - errors may prevent output
- Verify your code uses `print()` statements
- Clear terminal and run again

## Future Enhancements

Planned improvements:
- Syntax highlighting for Mufi code
- Breakpoint support
- Step-through debugging
- Output filtering and search
- Customizable terminal themes
- Variable inspector panel
- Export output to file

## Related Documentation

- [REPL Guide](MUFI_REPL_GUIDE.md) - Interactive REPL usage
- [Quick Start](QUICK_START_REPL.md) - Getting started with Mufi
- [Troubleshooting](TROUBLESHOOTING_MUFI.md) - Common issues and solutions
- [Memory Safety](MEMORY_SAFETY.md) - Runtime safety features

---

**Note**: This editor maintains full backward compatibility with traditional markdown note-taking while adding powerful code execution capabilities for Mufi development.