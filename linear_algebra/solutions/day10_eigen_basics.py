"""
Day 10 code lab — reference solution. Only check this after attempting
starter_code/day10_eigen_basics.py yourself.
"""

import numpy as np


def eigenvalues_via_characteristic_poly(A):
    coeffs = np.poly(A)
    return np.roots(coeffs)


if __name__ == "__main__":
    A = np.array([
        [4.0, 1.0],
        [2.0, 3.0],
    ])
    my_eigs = np.sort(eigenvalues_via_characteristic_poly(A).real)
    np_eigs = np.sort(np.linalg.eigvals(A).real)
    assert np.allclose(my_eigs, np_eigs)
    print("my eigenvalues match numpy:", my_eigs)

    # Extension: verify against the 2 more 3x3 matrices you compute by hand
    # in the exercises.
