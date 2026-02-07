# Ferrufi Mufi Editor - Quick Reference

## 🎯 Quick Actions

| Action | Shortcut | Button |
|--------|----------|--------|
| Run script | `⌘R` | ▶️ Play |
| Toggle terminal | Click icon | 🖥️ Terminal |
| Toggle REPL | `⌃⌘R` | 🔧 REPL |
| Toggle preview | `⌃⌘P` | 👁️ Preview |
| Clear output | - | 🗑️ Clear |

## 📝 Editor Modes

### Markdown Mode
- Full markdown support with preview
- Wiki-style links `[[Note Name]]`
- Hashtags for organization `#tag`
- Live preview rendering

### Mufi Code Mode
- Write and execute Mufi scripts
- Inline terminal output
- Execution timing
- Error reporting

### Hybrid Mode
- Markdown documentation + Mufi code
- Best of both worlds
- Run code, preview docs

## 🖥️ Terminal Output

```
┌─────────────────────────────────────┐
│ ● Terminal    SUCCESS    0.045s     │
├─────────────────────────────────────┤
│   1 │ Hello, World!                 │
│   2 │ Result: 42                    │
└─────────────────────────────────────┘
```

### Status Indicators
- 🟢 **SUCCESS** - Script executed (exit code 0)
- 🔴 **ERROR** - Script failed (non-zero exit)
- ⏱️ **Time** - Execution duration

### Terminal Controls
- **▼/▶** - Collapse/expand output
- **🗑️** - Clear output buffer
- **✕** - Close terminal panel

## 🔧 REPL (Interactive Mode)

Press `⌃⌘R` to open interactive REPL:
- Test code snippets
- Experiment with syntax
- Immediate feedback
- Separate from main script

## ✏️ Formatting Shortcuts

| Format | Shortcut | Syntax |
|--------|----------|--------|
| Bold | `⌘B` | `**text**` |
| Italic | `⌘I` | `*text*` |
| Code | - | `` `code` `` |
| Header | - | `# Header` |
| List | - | `- Item` |
| Link | `⌘K` | `[[Note]]` |

## 📊 Display Layouts

**EditorWithREPL** provides 4 modes:
1. **Editor Only** - Focus on code
2. **Editor + Preview** - Markdown editing
3. **Editor + REPL** - Interactive coding
4. **All Panes** - Full workspace

Switch via toolbar segmented control.

## 🚀 Common Workflows

### Quick Script Test
1. Write code
2. Press `⌘R`
3. Check terminal output

### Interactive Development
1. Press `⌃⌘R` for REPL
2. Test functions
3. Copy working code to editor
4. Run full script with `⌘R`

### Documented Code
1. Write markdown docs
2. Add Mufi code sections
3. Toggle preview to see formatting
4. Run code with `⌘R`
5. Terminal shows output, preview shows docs

## ⚡ Pro Tips

- **Auto-save**: Changes save automatically after 0.5s
- **Line numbers**: Terminal output includes line numbers
- **Text selection**: Copy output directly from terminal
- **Multi-run**: Terminal stays open for comparison
- **Error messages**: Include line/column info
- **Execution timer**: Benchmark your scripts

## 🐛 Debugging

### Script Won't Run
- ✅ Check Mufi syntax
- ✅ Look for error in terminal
- ✅ Try in REPL first

### No Output
- ✅ Add `print()` statements
- ✅ Check exit status
- ✅ Clear and retry

### Slow Performance
- ✅ Check execution time
- ✅ Look for infinite loops
- ✅ Simplify complex logic

## 📚 Mufi Syntax Reminder

```mufi
// Variables
var x = 42
var name = "Mufi"

// Functions
fun add(a, b) {
    return a + b
}

// Control flow
if x > 10 {
    print("Large")
}

// Loops
while i < 5 {
    print(i)
    i = i + 1
}

// Output
print("Hello, World!")
```

## 🔒 Safety Features

- ⏱️ **Timeouts**: 30s/60s limits
- 🛡️ **Memory safe**: Proper C/Swift bridge
- 🔄 **Serialized**: One script at a time
- 💾 **Auto-save**: No lost changes

## 🎨 UI Elements

```
┌─────────────────────────────────────────────────┐
│ [●] Editing  [Fmt Buttons]  ▶️ 🖥️ 🔧  123 words │ ← Toolbar
├─────────────────────────────────────────────────┤
│ Editor               │ Preview/REPL             │ ← Main Area
│ (Write code/docs)    │ (See results)            │
├─────────────────────────────────────────────────┤
│ ● Terminal       SUCCESS       0.045s  🗑️ ▼ ✕  │ ← Terminal
│   1 │ Output line 1                             │
│   2 │ Output line 2                             │
└─────────────────────────────────────────────────┘
```

## 📖 Full Documentation

For detailed information:
- [Mufi Editor Guide](MUFI_EDITOR_GUIDE.md)
- [REPL Guide](MUFI_REPL_GUIDE.md)
- [Troubleshooting](TROUBLESHOOTING_MUFI.md)

---

**Happy Coding! 🚀**