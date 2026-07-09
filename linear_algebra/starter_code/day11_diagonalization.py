"""
Day 11 code lab — diagonalization.

Fill in `diagonalize_and_reconstruct` below. Do not look at
solutions/day11_diagonalization.py until you've attempted this yourself (and
finished the pencil-and-paper exercises in content/day11.md).
"""

import numpy as np


def diagonalize_and_reconstruct(A):
    """
    Attempt to diagonalize square matrix A. Return a tuple
    (is_diagonalizable, reconstructed) where is_diagonalizable is True iff A
    has n linearly independent eigenvectors, and reconstructed is P @ D @
    inv(P) (should equal A when is_diagonalizable is True; may be garbage
    otherwise -- that's fine, the caller checks is_diagonalizable first).
    Hint: use np.linalg.eig to get eigenvalues/eigenvectors, then check
    np.linalg.matrix_rank(eigenvectors) == A.shape[0].
    """
    # TODO: implement this
    raise NotImplementedError


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
