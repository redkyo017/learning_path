"""
Day 1 code lab — reference solution. Only check this after attempting
starter_code/day01_vector_spaces.py yourself.
"""

import numpy as np


def is_in_span(target, vectors):
    A = np.column_stack(vectors)
    solution, residuals, rank, _ = np.linalg.lstsq(A, target, rcond=None)
    return np.allclose(A @ solution, target)


if __name__ == "__main__":
    v1 = np.array([1.0, 0.0, 1.0])
    v2 = np.array([0.0, 1.0, 1.0])
    b_in = np.array([2.0, 3.0, 5.0])
    b_out = np.array([1.0, 1.0, 1.0])

    assert is_in_span(b_in, [v1, v2]) == True
    assert is_in_span(b_out, [v1, v2]) == False
    print("All checks passed!")
