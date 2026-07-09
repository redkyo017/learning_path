"""
Day 2 code lab — linear independence via rank.

Fill in `is_independent` below. Do not look at
solutions/day02_basis_dimension.py until you've attempted this yourself (and
finished the pencil-and-paper exercises in content/day02.md).
"""

import numpy as np


def is_independent(vectors):
    """
    Return True if the given list of 1D numpy arrays is linearly independent.
    Hint: stack them as columns of a matrix and compare
    np.linalg.matrix_rank(...) to the number of vectors.
    """
    # TODO: implement this
    raise NotImplementedError


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
