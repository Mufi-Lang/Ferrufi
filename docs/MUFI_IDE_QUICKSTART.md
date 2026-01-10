# Mufi IDE Quick Start Guide

Welcome to **Mufi IDE** - your integrated development environment for Mufi programming!

## First Launch

When you first open Mufi IDE, you'll see:

1. **Sidebar (Left)**: File explorer with your scripts
2. **Editor (Center)**: Code editor with the Welcome script
3. **Preview/Terminal (Right)**: Preview pane and terminal output

## Creating Your First Script

### Method 1: Quick Action Button
1. Click the **📄+ New Script** button in the sidebar
2. Enter a name like `hello`
3. Click **Create**

### Method 2: Keyboard Shortcut
1. Press `⌘N`
2. Enter your script name
3. Press Enter

### What You Get
A new script opens with this template:

```mufi
// hello
// Created on [date]

// Variables
var message = "Hello from hello!"
print(message)

// Functions
fn greet(name) {
    return "Hello, " + name + "!"
}

print(greet("Mufi"))

// Example: Simple calculation
fn add(a, b) {
    return a + b
}

var result = add(10, 20)
print("Result: " + str(result))
```

## Running Your Script

### Option 1: Keyboard (Recommended)
Press `⌘R` to run the current script

### Option 2: Toolbar Button
Click the **▶️ Play** button in the toolbar

### What Happens
- Script executes immediately
- Terminal panel slides in below the editor
- Output appears with line numbers
- Execution time is displayed

## Understanding Terminal Output

```
┌─────────────────────────────────────────┐
│ ● Terminal       SUCCESS        0.045s  │
│                         [🗑️] [▼] [✕]    │
├─────────────────────────────────────────┤
│   1 │ Hello from hello!                 │
│   2 │ Hello, Mufi!                      │
│   3 │ Result: 30                        │
└─────────────────────────────────────────┘
```

**Status Indicators:**
- 🟢 **SUCCESS** = Script ran without errors (exit code 0)
- 🔴 **ERROR** = Script encountered an error
- ⏱️ **Time** = How long execution took

**Controls:**
- 🗑️ Clear = Clear the output
- ▼ Collapse = Hide/show output
- ✕ Close = Close terminal panel

## Using the Interactive REPL

### Open REPL
Press `⌃⌘R` (Control-Command-R) or click the **🔧 REPL** button

### What is REPL?
REPL = Read-Eval-Print Loop. Test code interactively:

1. Type a line of Mufi code
2. Press Enter
3. See the result immediately
4. Repeat!

**Example Session:**
```
> var x = 42
> print(x)
42
> fn double(n) { return n * 2 }
> print(double(x))
84
```

## Organizing Scripts

### Create Folders
1. Click **📁+ New Folder** in Quick Actions
2. Name your folder (e.g., "examples", "utils")
3. Drag scripts into folders

### File Explorer
- Click folders to expand/collapse
- Click scripts to open in editor
- Right-click for context menu options

### Working Directory
Set a working directory for quick script creation:
1. Click **📁⚙️ Open Dir** in Quick Actions
2. Select a folder
3. New scripts created here by default

## Essential Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Run script | `⌘R` |
| Open REPL | `⌃⌘R` |
| New script | `⌘N` |
| New folder | `⌘⇧N` |
| Find in scripts | `⌘F` |
| Save (auto) | Automatic after 0.5s |
| Bold | `⌘B` |
| Italic | `⌘I` |

## Mufi Language Basics

### Variables
```mufi
var name = "Alice"
var age = 30
var pi = 3.14
```

### Functions
```mufi
fn greet(name) {
    return "Hello, " + name + "!"
}

var message = greet("World")
print(message)
```

### Control Flow
```mufi
// If statements
if age >= 18 {
    print("Adult")
} else {
    print("Minor")
}

// While loops
var i = 0
while i < 5 {
    print("Count: " + str(i))
    i = i + 1
}
```

### Output
```mufi
print("Hello!")              // Print text
print(42)                    // Print number
print("Value: " + str(42))   // Convert to string
```

## Common Workflows

### 1. Quick Test
```
Write code → Press ⌘R → Check output → Edit → Press ⌘R
```

### 2. Interactive Development
```
Open REPL (⌃⌘R) → Test function → Copy to editor → Run full script (⌘R)
```

### 3. Script Library
```
Create folder → Write reusable scripts → Organize by category → Import/reference
```

## Tips & Tricks

### Auto-Save
- Changes save automatically after 0.5 seconds
- No need to press ⌘S manually
- Focus on coding, not saving!

### Terminal Stays Open
- Terminal persists between runs
- Compare outputs from multiple runs
- Clear when needed with 🗑️ button

### Search Everything
- Press `⌘F` to search across all scripts
- Find code snippets instantly
- Results show in sidebar

### Markdown Support
- Scripts can include markdown documentation
- Use `#` for headers
- Mix documentation with code
- Toggle preview with `⌃⌘P`

### Execution Metrics
- Track script performance
- Optimize slow code
- Compare before/after improvements

## Troubleshooting

### Script Won't Run
✅ Check Mufi syntax is correct  
✅ Look for error in terminal  
✅ Try code in REPL first  

### No Output Showing
✅ Add `print()` statements  
✅ Check terminal is visible  
✅ Press terminal icon to toggle  

### REPL Not Working
✅ Check Mufi runtime initialized (see app logs)  
✅ Try restarting the app  
✅ Run scripts with ⌘R instead  

### Slow Performance
✅ Check execution time in terminal  
✅ Look for infinite loops  
✅ Test in REPL to isolate issue  

## Example Scripts

### Hello World
```mufi
var greeting = "Hello, World!"
print(greeting)
```

### Calculator
```mufi
fn add(a, b) { return a + b }
fn subtract(a, b) { return a - b }
fn multiply(a, b) { return a * b }
fn divide(a, b) { return a / b }

print("10 + 5 = " + str(add(10, 5)))
print("10 - 5 = " + str(subtract(10, 5)))
print("10 * 5 = " + str(multiply(10, 5)))
print("10 / 5 = " + str(divide(10, 5)))
```

### Fibonacci
```mufi
fn fibonacci(n) {
    if n <= 1 {
        return n
    }
    return fibonacci(n - 1) + fibonacci(n - 2)
}

var i = 0
while i < 10 {
    print("fib(" + str(i) + ") = " + str(fibonacci(i)))
    i = i + 1
}
```

## Next Steps

1. ✍️ **Write** your own scripts
2. ▶️ **Run** them with ⌘R
3. 🔧 **Experiment** in the REPL
4. 📁 **Organize** into folders
5. 🚀 **Build** something awesome!

## Getting Help

- Check the terminal output for error messages
- Use REPL to test small code snippets
- Review Mufi language documentation
- Experiment and learn by doing!

---

**Happy Coding with Mufi IDE! 🚀**

*Your scripts are stored in `~/.ferrufi/notes/`*