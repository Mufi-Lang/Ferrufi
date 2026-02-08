# linspace

Generate a vector of linearly spaced values.

## Syntax
`v = linspace(start, end, count)`

## Description
`linspace(start, end, count)` creates a float vector containing `count` values starting from `start` and ending at `end`.

## Examples
Create a vector of 5 values between 0 and 1:
```mufi
var v = linspace(0, 1, 5);
print(v);
// Output: {0, 0.25, 0.5, 0.75, 1}
```