"""
Day 3 code lab — reference solution. Only check this after attempting
starter_code/day03_linear_transformations.py yourself.
"""

import numpy as np


def matches_composition(S, T, v):
    via_matrix = (S @ T) @ v
    via_composition = S @ (T @ v)
    return np.allclose(via_matrix, via_composition)


if __name__ == "__main__":
    T = np.array([[0.0, -1.0], [1.0, 0.0]])   # rotate 90 degrees
    S = np.array([[2.0, 0.0], [0.0, 1.0]])    # scale x by 2
    v = np.array([3.0, -1.0])

    assert matches_composition(S, T, v) == True
    print("All checks passed!")

    # Extension: define a third transformation R of your own and verify
    # associativity of composition numerically: (R@S)@T == R@(S@T) as matrices.
