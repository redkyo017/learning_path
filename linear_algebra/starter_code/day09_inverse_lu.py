import numpy as np
from scipy.linalg import lu


def gauss_jordan_inverse(A):
    """
    Compute the inverse of square matrix A via Gauss-Jordan elimination on
    the augmented matrix [A | I] (no np.linalg.inv calls inside this
    function -- only used afterward to check).
    Hint: build the augmented n x 2n matrix, then for each column, find a
    pivot (partial pivoting via argmax of abs value is fine), swap it into
    position, scale that row so the pivot is 1, then eliminate that column
    in every OTHER row (not just below). The right half of the final
    augmented matrix is A^{-1}.
    """
    # TODO: implement this
    raise NotImplementedError


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
