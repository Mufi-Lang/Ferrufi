# transpose

Transpose a matrix.

## Syntax
`At = transpose(A)`

## Description
`transpose(A)` returns the non-conjugate transpose of matrix `A`.

## Examples
Transpose a 2-by-2 matrix:
```mufi
var A = [[1, 2], [3, 4]];
var At = transpose(A);
print(At);
// Output: [[1, 3], [2, 4]]
```