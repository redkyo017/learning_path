import numpy as np


def change_of_basis(T_matrix, P):
    """Return P^{-1} @ T_matrix @ P."""
    # TODO: implement this
    raise NotImplementedError


if __name__ == "__main__":
    T_standard = np.array([[0.0, 1.0], [1.0, 0.0]])
    P = np.array([[1.0, 1.0], [1.0, -1.0]])

    T_new = change_of_basis(T_standard, P)
    assert np.allclose(T_new, np.diag([1.0, -1.0]))
    assert np.isclose(np.trace(T_new), np.trace(T_standard))
    assert np.isclose(np.linalg.det(T_new), np.linalg.det(T_standard))
    print("All checks passed! T in new basis:\n", T_new)
