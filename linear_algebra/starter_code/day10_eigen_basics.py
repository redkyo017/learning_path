"""
Day 10 code lab — eigenvalues via the characteristic polynomial.

Fill in `eigenvalues_via_characteristic_poly` below. Do not look at
solutions/day10_eigen_basics.py until you've attempted this yourself (and
finished the pencil-and-paper exercises in content/day10.md).
"""

import numpy as np


def eigenvalues_via_characteristic_poly(A):
    """
    Compute the eigenvalues of square matrix A by forming its characteristic
    polynomial and finding its roots.
    Hint: np.poly(A) gives the characteristic polynomial's coefficients
    directly from A; np.roots(coeffs) finds the roots of a polynomial given
    its coefficients.
    """
    # TODO: implement this
    raise NotImplementedError


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
