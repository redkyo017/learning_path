"""
Day 5 code lab — reference solution. Only check this after attempting
starter_code/day05_gaussian_elimination.py yourself.
"""

import numpy as np


def row_echelon(A):
    A = A.astype(float).copy()
    rows, cols = A.shape
    pivot_row = 0
    for col in range(cols):
        pivot = None
        for r in range(pivot_row, rows):
            if not np.isclose(A[r, col], 0):
                pivot = r
                break
        if pivot is None:
            continue
        A[[pivot_row, pivot]] = A[[pivot, pivot_row]]
        A[pivot_row] = A[pivot_row] / A[pivot_row, col]
        for r in range(rows):
            if r != pivot_row:
                A[r] -= A[r, col] * A[pivot_row]
        pivot_row += 1
        if pivot_row == rows:
            break
    return A


if __name__ == "__main__":
    A = np.array([
        [2.0, 1.0, -1.0],
        [-3.0, -1.0, 2.0],
        [-2.0, 1.0, 2.0],
    ])
    rref = row_echelon(A)
    print("my row echelon form:\n", rref)

    my_rank = np.linalg.matrix_rank(rref)
    np_rank = np.linalg.matrix_rank(A)
    assert my_rank == np_rank
    print("rank matches numpy:", my_rank, "==", np_rank)

    # Extension: run row_echelon on 3 more matrices from the exercises,
    # including one singular matrix, and confirm ranks match.
    B = np.array([
        [2.0, 4.0, -2.0],
        [4.0, 9.0, -3.0],
        [-2.0, -3.0, 7.0],
    ])
    C = np.array([
        [1.0, 2.0, 1.0],
        [2.0, 4.0, 3.0],
        [3.0, 6.0, 4.0],
    ])
    D = np.array([
        [1.0, 2.0, 0.0, 1.0],
        [2.0, 4.0, 1.0, 3.0],
        [1.0, 2.0, 1.0, 2.0],
    ])

    for name, M in [("B", B), ("C", C), ("D", D)]:
        R = row_echelon(M)
        my_r = np.linalg.matrix_rank(R)
        np_r = np.linalg.matrix_rank(M)
        assert my_r == np_r
        print(f"{name} row echelon form:\n{R}\nrank {my_r} == {np_r}\n")
