# eye

Create an identity matrix.

## Syntax
`I = eye(n)`
`I = eye(m, n)`

## Description
`eye(n)` returns an `n`-by-`n` identity matrix with ones on the main diagonal and zeros elsewhere.
`eye(m, n)` returns an `m`-by-`n` identity matrix.

## Examples
Create a 3-by-3 identity matrix:
```mufi
var I = eye(3);
print(I);
```