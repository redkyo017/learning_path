"""
Day 4 code lab — rank-nullity theorem.

Fill in `rank_nullity_holds` below. Do not look at
solutions/day04_rank_nullity.py until you've attempted this yourself (and
finished the pencil-and-paper exercises in content/day04.md).
"""

import numpy as np
from scipy.linalg import null_space


def rank_nullity_holds(A):
    """
    Return True if rank(A) + nullity(A) == number of columns of A
    (the rank-nullity theorem, verified numerically).
    Hint: use np.linalg.matrix_rank(A) for rank, and
    scipy.linalg.null_space(A).shape[1] for nullity.
    """
    # TODO: implement this
    raise NotImplementedError


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
