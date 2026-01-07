# Theme-Aware Preview Test

This is a test document to verify the **markdown preview** functionality works correctly with *different themes*.

## Code Examples

Here's some `inline code` and a code block:

```swift
func testThemes() {
    print("Hello, Iron!")
    return true
}
```

## Lists and Links

- Item 1 with **bold text**
- Item 2 with *italic text*
- Item 3 with [external link](https://example.com)
- Item 4 with [[wiki link]]
- Item 5 with #tag

## Blockquotes

> This is a blockquote that should adapt to the current theme colors.
> It should look good in both light and dark themes.

## Other Elements

1. Numbered list item
2. ~~Strikethrough text~~
3. ==Highlighted text==

---

**Test Results:**
- ✅ Headers should use theme foreground color
- ✅ Code blocks should use theme background secondary
- ✅ Links and tags should use theme accent color
- ✅ Borders should use theme border color
- ✅ Text should use theme foreground colors

*Theme switching should update all colors dynamically.*