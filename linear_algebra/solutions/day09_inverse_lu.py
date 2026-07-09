"""
Day 9 code lab — reference solution. Only check this after attempting
starter_code/day09_inverse_lu.py yourself.
"""

import numpy as np
from scipy.linalg import lu


def gauss_jordan_inverse(A):
    A = A.astype(float)
    n = A.shape[0]
    aug = np.hstack([A, np.eye(n)])
    for col in range(n):
        pivot = np.argmax(np.abs(aug[col:, col])) + col
        aug[[col, pivot]] = aug[[pivot, col]]
        aug[col] = aug[col] / aug[col, col]
        for r in range(n):
            if r != col:
                aug[r] -= aug[r, col] * aug[col]
    return aug[:, n:]


if __name__ == "__main__":
    A = np.array([
        [4.0, 3.0],
        [6.0, 3.0],
    ])
    my_inv = gauss_jordan_inverse(A)
    assert np.allclose(my_inv, np.linalg.inv(A))
    print("my inverse matches numpy:\n", my_inv)

    A3 = np.array([[2.0, 1.0, 1.0], [4.0, 3.0, 3.0], [8.0, 7.0, 9.0]])
    P, L, U = lu(A3)
    # scipy.linalg.lu returns P, L, U with A3 == P @ L @ U (P permutes rows
    # of L @ U back into A3's order), equivalently P.T @ A3 == L @ U since
    # a permutation matrix is orthogonal (P.T == P^-1).
    assert np.allclose(A3, P @ L @ U)
    assert np.allclose(P.T @ A3, L @ U)
    print("A3 == P @ L @ U check passed")

    # Extension: cross-check against Exercises 3 and 4's hand computations.
    C = np.array([
        [1.0, 2.0, 3.0],
        [0.0, 1.0, 4.0],
        [5.0, 6.0, 0.0],
    ])
    C_inv = gauss_jordan_inverse(C)
    assert np.allclose(C_inv, np.linalg.inv(C))
    expected_C_inv = np.array([
        [-24.0, 18.0, 5.0],
        [20.0, -15.0, -4.0],
        [-5.0, 4.0, 1.0],
    ])
    assert np.allclose(C_inv, expected_C_inv)
    print("C^-1 matches hand computation:\n", C_inv)

    D = np.array([
        [1.0, 2.0, 2.0],
        [1.0, 3.0, 3.0],
        [2.0, 4.0, 5.0],
    ])
    D_inv = gauss_jordan_inverse(D)
    assert np.allclose(D_inv, np.linalg.inv(D))
    expected_D_inv = np.array([
        [3.0, -2.0, 0.0],
        [1.0, 1.0, -1.0],
        [-2.0, 0.0, 1.0],
    ])
    assert np.allclose(D_inv, expected_D_inv)
    print("D^-1 matches hand computation:\n", D_inv)

    # Singular matrix: partial pivoting still picks the largest-magnitude
    # entry, but that entry is 0 -- the division below produces inf/nan
    # rather than a valid inverse. This is exactly the failure Exercise 9
    # predicts by hand: no legitimate pivot exists in column 2.
    M = np.array([
        [1.0, 2.0],
        [2.0, 4.0],
    ])
    with np.errstate(divide="ignore", invalid="ignore"):
        M_inv = gauss_jordan_inverse(M)
    assert not np.all(np.isfinite(M_inv))
    print("singular matrix M correctly fails to produce a finite inverse:\n", M_inv)
