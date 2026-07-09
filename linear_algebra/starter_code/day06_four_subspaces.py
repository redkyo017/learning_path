"""
Day 6 code lab — the four fundamental subspaces.

Fill in `fundamental_subspaces` below. Do not look at
solutions/day06_four_subspaces.py until you've attempted this yourself (and
finished the pencil-and-paper exercises in content/day06.md).
"""

import numpy as np
from scipy.linalg import null_space, orth


def fundamental_subspaces(A):
    """
    Return a dict with keys 'column', 'row', 'null', 'left_null', each
    mapping to a numpy array whose columns form a basis for that subspace
    of the given matrix A.
    Hint: use scipy.linalg.orth(A) for column space, scipy.linalg.orth(A.T)
    for row space, scipy.linalg.null_space(A) for null space, and
    scipy.linalg.null_space(A.T) for left null space.
    """
    # TODO: implement this
    raise NotImplementedError


if __name__ == "__main__":
    A = np.array([
        [1.0, 2.0, 1.0],
        [2.0, 4.0, 3.0],
        [3.0, 6.0, 5.0],
    ])
    subspaces = fundamental_subspaces(A)
    r = np.linalg.matrix_rank(A)
    m, n = A.shape

    assert subspaces["column"].shape[1] == r
    assert subspaces["row"].shape[1] == r
    assert subspaces["null"].shape[1] == n - r
    assert subspaces["left_null"].shape[1] == m - r
    print("All dimension checks passed! rank =", r)

    if subspaces["null"].shape[1] > 0:
        orthogonality = np.allclose(subspaces["row"].T @ subspaces["null"], 0)
        print("row space is orthogonal to null space:", orthogonality)

    # Extension: try this on a random 4x3 matrix and a random 3x4 matrix
    # and confirm the dimension counts still satisfy the Fundamental Theorem.
