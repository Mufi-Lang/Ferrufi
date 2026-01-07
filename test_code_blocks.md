# Code Block Styling Test

This document tests the improved code block styling in Iron Notes.

## Basic Code Block

Here's a simple code block without language specification:

```
function hello() {
    console.log("Hello, World!");
}
```

## Swift Code Block

Here's a Swift code block with language specification:

```swift
struct ContentView: View {
    @State private var text = ""
    
    var body: some View {
        VStack {
            TextField("Enter text", text: $text)
            Text("You typed: \(text)")
        }
        .padding()
    }
}
```

## Python Code Block

```python
def fibonacci(n):
    if n <= 1:
        return n
    else:
        return fibonacci(n-1) + fibonacci(n-2)

# Generate first 10 fibonacci numbers
for i in range(10):
    print(f"F({i}) = {fibonacci(i)}")
```

## JavaScript Code Block

```javascript
class TaskManager {
    constructor() {
        this.tasks = [];
    }
    
    addTask(title, description = '') {
        const task = {
            id: Date.now(),
            title,
            description,
            completed: false,
            createdAt: new Date()
        };
        this.tasks.push(task);
        return task;
    }
    
    completeTask(id) {
        const task = this.tasks.find(t => t.id === id);
        if (task) {
            task.completed = true;
        }
    }
}
```

## Mixed Content

Here's some text with `inline code` mixed with regular text and then a code block:

```bash
# Install dependencies
npm install

# Run the development server
npm run dev

# Build for production
npm run build
```

And here's more text after the code block with some **bold text** and *italic text*.

## SQL Code Block

```sql
SELECT u.name, u.email, COUNT(o.id) as order_count
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
WHERE u.created_at >= '2024-01-01'
GROUP BY u.id, u.name, u.email
HAVING COUNT(o.id) > 5
ORDER BY order_count DESC;
```

## Inline Code Testing

Here are some examples of `inline code` within regular text. You can use `console.log()` for debugging, or `Array.prototype.map()` for transformations.

The `NotionStyleEditor` should properly hide the backticks and style the code with a monospace font and background color.

## Code Block with Empty Lines

```typescript
interface User {
    id: number;
    name: string;
    email: string;
}

class UserService {
    private users: User[] = [];

    async createUser(userData: Omit<User, 'id'>): Promise<User> {
        const newUser = {
            id: this.generateId(),
            ...userData
        };
        
        this.users.push(newUser);
        
        return newUser;
    }

    private generateId(): number {
        return Math.max(...this.users.map(u => u.id), 0) + 1;
    }
}
```

This should test various aspects of the code block rendering including:
- Syntax hiding for ``` markers
- Background colors and borders
- Proper spacing and padding
- Language detection
- Monospace font rendering
- Mixed content handling