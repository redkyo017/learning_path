import numpy as np

def solve_least_squares_via_qr(A, y):
    """
    Solve the least-squares problem min ||Ax - y|| using the QR
    decomposition of A (Q has orthonormal columns, R is upper triangular):
    solve R @ x = Q.T @ y for x (R is triangular, so np.linalg.solve works,
    or you may use back-substitution manually).
    Hint: get Q, R via np.linalg.qr(A), then solve the triangular system.
    """
    Q, R = np.linalg.qr(A)
    return np.linalg.solve(R, Q.T @ y)


if __name__ == "__main__":
    A = np.array([
        [1.0, 1.0, 0.0],
        [1.0, 0.0, 1.0],
        [0.0, 1.0, 1.0],
        [1.0, 1.0, 1.0],
    ])
    Q, R = np.linalg.qr(A)
    assert np.allclose(Q.T @ Q, np.eye(Q.shape[1]))
    assert np.allclose(Q @ R, A)
    print("Q orthogonal and QR == A: checks passed")

    y = np.array([1.0, 2.0, 3.0, 4.0])
    x_qr = solve_least_squares_via_qr(A, y)
    x_normal_eq = np.linalg.solve(A.T @ A, A.T @ y)
    assert np.allclose(x_qr, x_normal_eq)
    print("QR-based least-squares solution matches normal equations:", x_qr)
