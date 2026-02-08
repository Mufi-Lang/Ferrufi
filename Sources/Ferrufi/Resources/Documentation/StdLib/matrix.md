# matrix

Create a matrix from data.

## Syntax
`A = matrix(data, rows, cols)`

## Description
`matrix(data, rows, cols)` reshapes the input `data` (a float vector) into a matrix with the specified number of `rows` and `cols`.

## Examples
Create a 2-by-2 matrix:
```mufi
var A = matrix({1, 2, 3, 4}, 2, 2);
print(A);
```
