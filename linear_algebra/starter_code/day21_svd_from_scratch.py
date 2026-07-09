import numpy as np
import matplotlib.pyplot as plt

def svd_from_scratch(A):
    """
    Compute the SVD of matrix A (assume A is square and invertible, for
    simplicity) by eigendecomposing A^T A, returning (U, singular_values, V)
    such that A ≈ U @ diag(singular_values) @ V.T.
    Steps:
    1. eigvals, V = np.linalg.eigh(A.T @ A)   (ascending order)
    2. sort eigvals descending (and reorder V's columns to match)
    3. singular_values = sqrt(clipped eigvals, floor at 0)
    4. U = (A @ V) / singular_values   (column-wise division)
    """
    # TODO: implement this
    raise NotImplementedError


if __name__ == "__main__":
    A = np.array([[3.0, 0.0], [4.0, 5.0]])
    U, s, V = svd_from_scratch(A)

    U_np, s_np, Vt_np = np.linalg.svd(A)
    assert np.allclose(np.sort(s)[::-1], np.sort(s_np)[::-1])
    print("my singular values match numpy:", s)

    reconstructed = U @ np.diag(s) @ V.T
    assert np.allclose(reconstructed, A)
    print("U @ diag(s) @ V.T == A: check passed")

    theta = np.linspace(0, 2 * np.pi, 200)
    circle = np.column_stack([np.cos(theta), np.sin(theta)])
    ellipse = circle @ A.T
    fig, ax = plt.subplots()
    ax.plot(circle[:, 0], circle[:, 1], label="unit circle")
    ax.plot(ellipse[:, 0], ellipse[:, 1], label="A * unit circle")
    ax.legend()
    ax.set_aspect("equal")
    plt.savefig("starter_code/day21_svd_circle_to_ellipse.png")
    print("saved plot")
