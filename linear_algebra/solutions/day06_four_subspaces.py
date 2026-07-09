"""
Day 6 code lab — reference solution. Only check this after attempting
starter_code/day06_four_subspaces.py yourself.
"""

import numpy as np
from scipy.linalg import null_space, orth


def fundamental_subspaces(A):
    return {
        "column": orth(A),
        "row": orth(A.T),
        "null": null_space(A),
        "left_null": null_space(A.T),
    }


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
    rng = np.random.default_rng(0)
    tall = rng.standard_normal((4, 3))
    wide = rng.standard_normal((3, 4))
    for name, M in [("random 4x3", tall), ("random 3x4", wide)]:
        sub = fundamental_subspaces(M)
        rr = np.linalg.matrix_rank(M)
        mm, nn = M.shape
        assert sub["column"].shape[1] == rr
        assert sub["row"].shape[1] == rr
        assert sub["null"].shape[1] == nn - rr
        assert sub["left_null"].shape[1] == mm - rr
        print(f"{name}: rank={rr}, dims OK "
              f"(null dim={sub['null'].shape[1]}, "
              f"left_null dim={sub['left_null'].shape[1]})")
