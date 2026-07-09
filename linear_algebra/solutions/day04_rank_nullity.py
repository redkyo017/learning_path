"""
Day 4 code lab — reference solution. Only check this after attempting
starter_code/day04_rank_nullity.py yourself.
"""

import numpy as np
from scipy.linalg import null_space


def rank_nullity_holds(A):
    rank = np.linalg.matrix_rank(A)
    nullity = null_space(A).shape[1]
    return rank + nullity == A.shape[1]


if __name__ == "__main__":
    A = np.array([
        [1.0, 2.0, 3.0],
        [2.0, 4.0, 6.0],
        [1.0, 0.0, 1.0],
    ])
    assert rank_nullity_holds(A) == True
    print("All checks passed!")

    # Extension: generate 3 random 4x6 matrices with np.random.default_rng()
    # and verify rank_nullity_holds returns True for all of them.
    rng = np.random.default_rng()
    for _ in range(3):
        M = rng.standard_normal((4, 6))
        assert rank_nullity_holds(M) == True
    print("Extension checks passed!")
