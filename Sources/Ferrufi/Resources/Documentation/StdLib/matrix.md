# Standard Library: Matrix

High-performance matrix operations.

## Creation
- `eye(n)`: Identity matrix.
- `ones(m, n)`, `zeros(m, n)`: Constant matrices.
- `matrix(data, rows, cols)`: Create from vector.

## Operations
- `transpose(A)`: Matrix transpose.
- `det(A)`: Matrix determinant.
- `inv(A)`: Matrix inverse.
- `rref(A)`: Reduced row echelon form.

## Manipulation
- `size(A)`: Dimensions.
- `reshape(A, m, n)`: Change shape.
- `matrix_get(A, row, col)`, `matrix_set(A, row, col, value)`
