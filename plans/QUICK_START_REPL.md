# Quick Start: Mufi REPL in Ferrufi

## 🚀 The Fastest Way to Run Mufi Code

Ferrufi has **Mufi-lang** built right into the editor. No external tools needed!

## The Editor Toolbar

When you open any note, look at the toolbar above the editor:

```
┌─────────────────────────────────────────────────────────────┐
│  👁️  |  B  I  <>  🔗  #  •  {}  |  ▶️  🖥️  |  123 words    │
└─────────────────────────────────────────────────────────────┘
```

### Two Important Buttons for Mufi:

1. **▶️ Play Button** - Run your Mufi script
2. **🖥️ Terminal Button** - Open interactive REPL

---

## Method 1: Run a Script (Quick Execution)

**Perfect for:** Running complete Mufi programs

### Steps:
1. Write Mufi code in your note:
   ```mufi
   var name = "Alice"
   var age = 30
   print("Hello, " + name + "!")
   print("Age: " + str(age))
   ```

2. Click the **▶️ Play Button** in the toolbar
   - Or press **⌘R** (Command+R)

3. See the output in a popup window:
   ```
   Hello, Alice!
   Age: 30
   [Script executed successfully]
   Status: 0
   ```

4. Done! 🎉

---

## Method 2: Interactive REPL (Development Mode)

**Perfect for:** Testing code snippets, debugging, learning Mufi

### Steps:
1. Click the **🖥️ Terminal Button** in the toolbar
   - Or press **⌃⌘R** (Control+Command+R)

2. The REPL opens on the right side:
   ```
   ┌─────────────┬─────────────┐
   │   Editor    │  Mufi REPL  │
   │             │             │
   │  Write code │  Test code  │
   │    here     │    here     │
   │             │             │
   └─────────────┴─────────────┘
   ```

3. Type Mufi code in the REPL input field:
   ```
   > var x = 42
   > print("The answer is: " + str(x))
   The answer is: 42
   ```

4. Press **Enter** to execute each line

5. Click the **🖥️ button** again to hide the REPL

---

## Keyboard Shortcuts

| Action | Shortcut | Button |
|--------|----------|--------|
| Run Script | `⌘R` | ▶️ |
| Toggle REPL | `⌃⌘R` | 🖥️ |

---

## Example Workflow: Testing a Function

### Step 1: Write in Editor
```mufi
fn fibonacci(n) {
    if n <= 1 {
        return n
    }
    return fibonacci(n - 1) + fibonacci(n - 2)
}
```

### Step 2: Open REPL (`⌃⌘R`)

### Step 3: Test in REPL
```
> fibonacci(5)
5
> fibonacci(10)
55
> fibonacci(15)
610
```

### Step 4: Perfect! Save your note

---

## Common Mufi Patterns

### Print Output
```mufi
print("Hello, World!")
```

### Variables
```mufi
var name = "Bob"
var age = 25
var active = true
```

### Functions
```mufi
fn add(a, b) {
    return a + b
}
print(add(10, 20))  // Output: 30
```

### Conditionals
```mufi
var x = 10
if x > 5 {
    print("x is greater than 5")
}
```

### Loops
```mufi
var i = 0
while i < 5 {
    print("Count: " + str(i))
    i = i + 1
}
```

### Arrays
```mufi
var numbers = [1, 2, 3, 4, 5]
print(numbers[0])  // Output: 1
```

---

## Troubleshooting

### "Runtime not initialized" Error
**Fix:** The first time you use the REPL, it auto-initializes. Wait a moment and try again.

### Nothing happens when I click Play
**Fix:** Check that your code is valid Mufi syntax. Status codes will show errors.

### REPL button not visible
**Fix:** Make sure you're in the editor view (not the sidebar or settings).

---

## Tips

✅ **DO:**
- Use the REPL to test small snippets
- Run full scripts with the Play button
- Save your work before running large scripts
- Check the word count to track your code size

❌ **DON'T:**
- Don't write infinite loops without a way to stop them
- Don't forget to use `print()` if you want output
- Don't close the REPL window during execution

---

## Menu Bar Access

Can't find the buttons? Use the menu:

- **Tools → Run Mufi Script** (`⌘R`)
- **Tools → Toggle Mufi REPL** (`⌃⌘R`)

---

## What is Mufi-Lang?

Mufi is a programming language with syntax similar to Swift/Rust. The REPL in Ferrufi connects directly to the Mufi runtime (`libmufiz.dylib`) for fast, native execution.

**Learn more:**
- See `MUFI_REPL_GUIDE.md` for complete language reference
- Check `README.md` for technical details
- Visit the Mufi-lang repository for documentation

---

## Summary

1. **Quick Run**: Click ▶️ or press `⌘R` to run your note as a Mufi script
2. **Interactive Mode**: Click 🖥️ or press `⌃⌘R` to open the REPL panel
3. **Both work together**: Write in the editor, test in the REPL, run with Play

**Happy coding with Mufi in Ferrufi!** 🎉