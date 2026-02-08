# Mufi Syntax Reference

MufiZ is a high-performance, modern programming language inspired by Swift and Rust, built with Zig.

## Variables and Constants
- **Variables (mutable)**: `var x = 10;`
- **Constants (immutable)**: `const PI = 3.14159;`

## Data Structures
- **Float Vectors**: `var vector = {1, 2, 3, 4, 5};`
- **Hash Tables**: `var dict = #{"key": "value", "name": "John"};`

## Control Flow

### Conditionals
```mufi
if (x > 0) {
    print("Positive");
} else if (x < 0) {
    print("Negative");
} else {
    print("Zero");
}
```

### Switch Statements
```mufi
switch(value) {
    case 1 => { print("One"); },
    case 2 => { print("Two"); },
    _ => { print("Other"); }
}
```

### Loops
- **For Loops**:
```mufi
for (var i = 0; i < 10; i = i + 1) {
    print(i);
}
```
- **Foreach Loops**:
    - Range: `foreach (i in 1..10) { print(i); }`
    - Collection: `foreach (item in list) { print(item); }`
- **While Loops**:
```mufi
var i = 0;
while (i < 10) {
    print(i);
    i = i + 1;
}
```

## Functions
```mufi
fun add(a, b) { return a + b; }
fun greet(name) { return format("Hello, {}!", name); }
```

## String Formatting
- **format**: `var greeting = format("Hello, {}!", name);`
- **F-string style**: `var message = f("The answer is {}", 42);`
