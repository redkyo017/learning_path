"""
Day 11 code lab — reference solution. Only check this after attempting
starter_code/day11_diagonalization.py yourself.
"""

import numpy as np


def diagonalize_and_reconstruct(A):
    n = A.shape[0]
    eigvals, eigvecs = np.linalg.eig(A)
    is_diagonalizable = np.linalg.matrix_rank(eigvecs) == n
    if is_diagonalizable:
        D = np.diag(eigvals)
        P = eigvecs
        reconstructed = P @ D @ np.linalg.inv(P)
    else:
        reconstructed = None
    return is_diagonalizable, reconstructed


if __name__ == "__main__":
    A_not_diagonalizable = np.array([
        [2.0, 1.0, 0.0],
        [0.0, 2.0, 1.0],
        [0.0, 0.0, 3.0],
    ])
    is_diag, _ = diagonalize_and_reconstruct(A_not_diagonalizable)
    assert is_diag == False
    print("correctly identified non-diagonalizable matrix")

    A_diagonalizable = np.array([
        [4.0, 1.0],
        [2.0, 3.0],
    ])
    is_diag, reconstructed = diagonalize_and_reconstruct(A_diagonalizable)
    assert is_diag == True
    assert np.allclose(reconstructed.real, A_diagonalizable)
    print("correctly diagonalized and reconstructed A")

    # Extension: confirm the Jordan block from Exercise 5 is also correctly
    # flagged as non-diagonalizable.
    jordan_block = np.array([
        [4.0, 1.0, 0.0],
        [0.0, 4.0, 1.0],
        [0.0, 0.0, 4.0],
    ])
    is_diag, _ = diagonalize_and_reconstruct(jordan_block)
    assert is_diag == False
    print("correctly identified the Exercise 5 Jordan block as non-diagonalizable")
