import numpy as np

def cofactor_det(A):
    """
    Compute the determinant of square matrix A via recursive cofactor
    expansion along the first row. A is a 2D numpy array.
    Base cases: 1x1 -> the single entry; 2x2 -> ad - bc.
    Recursive case: sum over columns of (-1)^col * A[0,col] * det(minor),
    where minor is A with row 0 and that column removed.
    """
    # TODO: implement this
    raise NotImplementedError


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
