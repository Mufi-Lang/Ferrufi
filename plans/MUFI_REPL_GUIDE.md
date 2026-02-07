# Mufi-Lang REPL Guide for Ferrufi

## What is the Mufi REPL?

The **Mufi REPL** (Read-Eval-Print Loop) in Ferrufi is an interactive programming environment for the **Mufi programming language**. It allows you to:

- Write and execute Mufi code line-by-line
- Test Mufi expressions and see results immediately
- Debug Mufi scripts interactively
- Learn Mufi syntax with instant feedback

## What is Mufi-Lang?

Mufi is a programming language with a syntax similar to Swift/Rust. The REPL connects directly to the Mufi runtime (`libmufiz.dylib`) through the CMufi C API bridge, allowing you to run Mufi code without spawning external processes.

## How It Works

```
┌─────────────────┐
│  Your Mufi Code │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   MufiBridge    │ (Swift Actor)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│     CMufi       │ (C API Module)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ libmufiz.dylib  │ (Mufi Runtime - Zig)
└─────────────────┘
```

## Basic Mufi Syntax

### 1. Variables

```mufi
var x = 42
var name = "Alice"
var pi = 3.14159
var isActive = true
```

### 2. Printing Output

```mufi
print("Hello, World!")
print("The value is: " + str(42))
```

### 3. Functions

```mufi
fn add(a, b) {
    return a + b
}

fn greet(name) {
    return "Hello, " + name + "!"
}

print(add(5, 10))        // Output: 15
print(greet("Mufi"))     // Output: Hello, Mufi!
```

### 4. Conditionals

```mufi
var age = 25

if age >= 18 {
    print("Adult")
} else {
    print("Minor")
}
```

### 5. Loops

```mufi
// While loop
var i = 0
while i < 5 {
    print("Count: " + str(i))
    i = i + 1
}

// For-style iteration (if supported)
var j = 0
while j < 3 {
    print("Iteration " + str(j))
    j = j + 1
}
```

### 6. Arrays

```mufi
var numbers = [1, 2, 3, 4, 5]
var fruits = ["apple", "banana", "orange"]

print("First number: " + str(numbers[0]))
print("Second fruit: " + fruits[1])
```

### 7. String Interpolation

```mufi
var name = "Bob"
var age = 30
print("My name is " + name + " and I am " + str(age) + " years old")
```

## Using the REPL in Ferrufi

### Method 1: Sheet Mode (Popup Window)

1. Open any note in Ferrufi
2. Click the **terminal icon** (🖥️) in the toolbar
3. A REPL window will appear
4. Type Mufi code and press Enter

**Example Session:**
```
> var x = 10
> var y = 20
> print(x + y)
30
> fn double(n) { return n * 2 }
> print(double(21))
42
```

### Method 2: Inline Split Mode

1. Click the **display mode picker** in the toolbar
2. Select **"Editor + REPL"** or **"All Panes"**
3. The REPL appears as a side panel
4. Write code in the editor on the left
5. Test snippets in the REPL on the right

### Method 3: Execute Full Scripts

1. Write a complete Mufi script in your note
2. Click the **Play button** (▶️) in the toolbar
3. The entire note executes as a Mufi program
4. Output appears in a results sheet

### Method 4: Send Editor Content to REPL

1. Write Mufi code in your note
2. Open the REPL (any mode)
3. Click the **arrow button** (➡️) in the REPL header
4. Your editor's content is sent to the REPL and executed

## Example Workflows

### Testing a Function

**In Editor:**
```mufi
fn fibonacci(n) {
    if n <= 1 {
        return n
    }
    return fibonacci(n - 1) + fibonacci(n - 2)
}
```

**In REPL:**
```
> fibonacci(5)
5
> fibonacci(10)
55
```

### Building a Calculator

**In Editor:**
```mufi
fn add(a, b) { return a + b }
fn subtract(a, b) { return a - b }
fn multiply(a, b) { return a * b }
fn divide(a, b) { return a / b }
```

**In REPL:**
```
> add(10, 5)
15
> multiply(4, 7)
28
> divide(100, 4)
25
```

### Data Processing

**In Editor:**
```mufi
var scores = [85, 92, 78, 95, 88]

fn average(arr) {
    var sum = 0
    var i = 0
    while i < len(arr) {
        sum = sum + arr[i]
        i = i + 1
    }
    return sum / len(arr)
}
```

**In REPL:**
```
> print("Average score: " + str(average(scores)))
Average score: 87.6
```

## REPL Features

### ✅ Supported

- ✓ Variable declarations
- ✓ Function definitions
- ✓ Print statements
- ✓ Arithmetic operations
- ✓ String concatenation
- ✓ Conditionals (if/else)
- ✓ Loops (while)
- ✓ Arrays
- ✓ Function calls
- ✓ Recursive functions
- ✓ Multi-line expressions

### 🎯 Runtime Options

The REPL initializes with these options (configurable in code):

- `enableLeakDetection`: false (memory leak tracking)
- `enableTracking`: false (execution tracking)
- `enableSafety`: true (runtime safety checks)

### 📊 Status Codes

- `0` = Success
- `Non-zero` = Error or warning

The REPL shows status codes when execution completes:
```
> invalid syntax here
[Status: 1]
```

## Troubleshooting

### REPL Not Starting

**Problem:** "Mufi runtime is not initialized"

**Solution:** 
- Check that `include/libmufiz.dylib` exists
- Run `./scripts/fix_mufiz_deployment_target.sh`
- Ensure the library is copied: `./scripts/copy_mufiz_dylib.sh`

### Linker Warnings

**Problem:** "warning: building for macOS-14.0, but linking with dylib built for newer version"

**Solution:**
```bash
./scripts/fix_mufiz_deployment_target.sh
swift build --clean
swift build
```

### No Output Appearing

**Problem:** Code runs but nothing shows in REPL

**Solution:**
- Use `print()` statements explicitly
- Check for syntax errors (status code will be non-zero)
- The REPL captures stdout/stderr automatically

### Runtime Crashes

**Problem:** REPL crashes or freezes

**Solution:**
- Stop the runtime (stop button in REPL)
- Restart the REPL
- Check for infinite loops or stack overflow
- Review your Mufi code for errors

## Advanced Usage

### Persistent State

The REPL maintains state between commands:

```
> var counter = 0
> counter = counter + 1
> print(counter)
1
> counter = counter + 1
> print(counter)
2
```

### Multi-line Input

For complex code, write in the editor and send to REPL:

**Editor:**
```mufi
fn factorial(n) {
    if n <= 1 {
        return 1
    }
    return n * factorial(n - 1)
}

var result = factorial(5)
print("5! = " + str(result))
```

Click the arrow button → Executes in REPL → Shows output

### Debugging Scripts

1. Write your full script in the editor
2. Use the Play button to run it completely
3. If there's an error, test parts in the REPL
4. Fix issues and iterate

## Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Send input | Enter / Return |
| Clear REPL output | Click trash icon |
| Stop runtime | Click stop icon |
| Focus input | Auto-focus on open |
| Run script | Click play button |
| Toggle REPL | Click terminal icon |

## Performance Tips

1. **Avoid infinite loops** - Use counters or conditions
2. **Close REPL when not in use** - Saves memory
3. **Clear output regularly** - Keeps UI responsive
4. **Test incrementally** - Build complex code step-by-step

## Integration with Ferrufi

### Note-Taking + Code

Write Mufi tutorials with executable examples:

```markdown
# My Mufi Tutorial

## Lesson 1: Variables

In Mufi, you can declare variables like this:

```mufi
var name = "Student"
var age = 20
print(name + " is " + str(age) + " years old")
```

Try this in the REPL!
```

### Code Snippets Library

Create a note with useful Mufi functions:

```mufi
// Math utilities
fn abs(n) { if n < 0 { return -n } else { return n } }
fn max(a, b) { if a > b { return a } else { return b } }
fn min(a, b) { if a < b { return a } else { return b } }

// String utilities
fn repeat(str, n) {
    var result = ""
    var i = 0
    while i < n {
        result = result + str
        i = i + 1
    }
    return result
}
```

Send to REPL and test functions as needed.

## Summary

The Mufi REPL in Ferrufi provides a powerful, integrated environment for:

- 🚀 **Learning** Mufi-lang interactively
- 🔧 **Testing** code snippets before committing
- 🐛 **Debugging** scripts with immediate feedback
- 📝 **Documenting** code with executable examples
- ⚡ **Prototyping** algorithms quickly

All powered by the native CMufi runtime for fast, in-process execution!

---

## Resources

- **Mufi Documentation**: Check the Mufi-lang repository for full language docs
- **C API Reference**: See `include/mufiz.h` for available functions
- **MufiBridge Source**: `Sources/Ferrufi/Integrations/Mufi/MufiBridge.swift`
- **REPL Source**: `Sources/Ferrufi/Integrations/Mufi/EmbeddedMufiREPLView.swift`

Happy coding in Mufi! 🎉