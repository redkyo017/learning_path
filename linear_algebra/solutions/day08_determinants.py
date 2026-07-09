import numpy as np


def cofactor_det(A):
    """
    Compute the determinant of square matrix A via recursive cofactor
    expansion along the first row. A is a 2D numpy array.
    Base cases: 1x1 -> the single entry; 2x2 -> ad - bc.
    Recursive case: sum over columns of (-1)^col * A[0,col] * det(minor),
    where minor is A with row 0 and that column removed.
    """
    A = np.array(A, dtype=float)
    n = A.shape[0]
    if n == 1:
        return A[0, 0]
    if n == 2:
        return A[0, 0] * A[1, 1] - A[0, 1] * A[1, 0]
    total = 0.0
    for col in range(n):
        minor = np.delete(np.delete(A, 0, axis=0), col, axis=1)
        sign = (-1) ** col
        total += sign * A[0, col] * cofactor_det(minor)
    return total


if __name__ == "__main__":
    A = np.array([
        [2.0, 0.0, 1.0],
        [1.0, 3.0, -1.0],
        [0.0, 4.0, 2.0],
    ])
    my_det = cofactor_det(A)
    np_det = np.linalg.det(A)
    assert np.isclose(my_det, np_det), f"{my_det} != {np_det}"
    print("my cofactor det matches numpy:", my_det)

    # Extension: test on a 4x4 matrix of your choice, and verify
    # det(A @ A.T) == det(A) * det(A.T) numerically.
    B = np.array([
        [2.0, 1.0, 0.0, 3.0],
        [0.0, 4.0, 0.0, 1.0],
        [1.0, 2.0, 5.0, 0.0],
        [3.0, 0.0, 0.0, 2.0],
    ])
    my_det_B = cofactor_det(B)
    np_det_B = np.linalg.det(B)
    assert np.isclose(my_det_B, np_det_B), f"{my_det_B} != {np_det_B}"
    print("my cofactor det matches numpy on 4x4:", my_det_B)

    lhs = cofactor_det(B @ B.T)
    rhs = cofactor_det(B) * cofactor_det(B.T)
    assert np.isclose(lhs, rhs), f"{lhs} != {rhs}"
    print("det(B @ B.T) == det(B) * det(B.T):", lhs, "==", rhs)
