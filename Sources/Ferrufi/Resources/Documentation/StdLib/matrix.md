# matrix

Create a matrix from data.

## Syntax
`A = matrix(data, rows, cols)`

## Description
`matrix(data, rows, cols)` creates a matrix with the specified number of `rows` and `cols` using the elements from the list `data`.

## Examples
Create a 2-by-2 matrix from a list:
```mufi
var A = matrix([1, 2, 3, 4], 2, 2);
print(A);
```

You can also create a matrix using nested list literals:
```mufi
var B = [[1, 2], [3, 4]];
print(B);
```