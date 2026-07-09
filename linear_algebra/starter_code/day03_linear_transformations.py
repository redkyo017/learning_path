"""
Day 3 code lab — linear transformations, matrix representation.

Fill in `matches_composition` below. Do not look at
solutions/day03_linear_transformations.py until you've attempted this
yourself (and finished the pencil-and-paper exercises in content/day03.md).
"""

import numpy as np


def matches_composition(S, T, v):
    """
    Return True if applying T then S to vector v gives the same result as
    applying the single matrix product (S @ T) to v.
    S, T: 2D numpy arrays (matrices). v: 1D numpy array.
    Hint: compute S @ (T @ v) and (S @ T) @ v and compare with np.allclose.
    """
    # TODO: implement this
    raise NotImplementedError


if __name__ == "__main__":
    T = np.array([[0.0, -1.0], [1.0, 0.0]])   # rotate 90 degrees
    S = np.array([[2.0, 0.0], [0.0, 1.0]])    # scale x by 2
    v = np.array([3.0, -1.0])

    assert matches_composition(S, T, v) == True
    print("All checks passed!")

    # Extension: define a third transformation R of your own and verify
    # associativity of composition numerically: (R@S)@T == R@(S@T) as matrices.
