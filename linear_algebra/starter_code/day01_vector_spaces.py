"""
Day 1 code lab — span membership.

Fill in `is_in_span` below. Do not look at solutions/day01_vector_spaces.py
until you've attempted this yourself (and finished the pencil-and-paper
exercises in content/day01.md).
"""

import numpy as np


def is_in_span(target, vectors):
    """
    Return True if `target` can be written as a linear combination of
    `vectors`, False otherwise.

    target: 1D numpy array, shape (n,)
    vectors: list of 1D numpy arrays, each shape (n,)

    Hint: stack `vectors` as columns of a matrix A (np.column_stack), solve
    A @ x = target with np.linalg.lstsq, then check whether the residual
    A @ x - target is (numerically) zero via np.allclose.
    """
    # TODO: implement this
    raise NotImplementedError


if __name__ == "__main__":
    v1 = np.array([1.0, 0.0, 1.0])
    v2 = np.array([0.0, 1.0, 1.0])
    b_in = np.array([2.0, 3.0, 5.0])       # = 2*v1 + 3*v2 -> should be True
    b_out = np.array([1.0, 1.0, 1.0])      # not in span{v1, v2} -> should be False

    assert is_in_span(b_in, [v1, v2]) == True, "b_in should be in the span"
    assert is_in_span(b_out, [v1, v2]) == False, "b_out should NOT be in the span"
    print("All checks passed!")

    # Extension (do this after the checks above pass):
    # Pick your own two vectors in R^4 and a third vector you proved by hand
    # (Exercise 7 technique) is outside their span. Confirm your code agrees.
