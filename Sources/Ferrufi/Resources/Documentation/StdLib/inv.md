# inv

Matrix inverse.

## Syntax
`Ai = inv(A)`

## Description
`inv(A)` returns the inverse of the square matrix `A`.

## Examples
Invert a 2-by-2 identity matrix:
```mufi
var A = eye(2);
var Ai = inv(A);
print(Ai);
```