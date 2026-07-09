"""
Day 2 code lab — reference solution. Only check this after attempting
starter_code/day02_basis_dimension.py yourself.
"""

import numpy as np


def is_independent(vectors):
    A = np.column_stack(vectors)
    return np.linalg.matrix_rank(A) == len(vectors)


if __name__ == "__main__":
    v1 = np.array([1.0, 2.0, 3.0])
    v2 = np.array([0.0, 1.0, 1.0])
    v3 = np.array([1.0, 4.0, 5.0])   # = v1 + 2*v2, dependent

    assert is_independent([v1, v2]) == True
    assert is_independent([v1, v2, v3]) == False
    dim = np.linalg.matrix_rank(np.column_stack([v1, v2, v3]))
    assert dim == 2
    print("All checks passed! dimension of span{v1,v2,v3} =", dim)

    # Extension: construct your own 4-vector set in R^4 with exactly one
    # redundant vector and verify the rank drops by exactly 1.
