import numpy as np
from scipy.linalg import cholesky


def trace_det_match_eigenvalues(A):
    """Return True if trace(A) == sum(eigenvalues) and det(A) == prod(eigenvalues)."""
    # TODO: implement this
    raise NotImplementedError


if __name__ == "__main__":
    rng = np.random.default_rng(3)
    M = rng.uniform(-2, 2, size=(4, 4))
    A = M @ M.T + 4 * np.eye(4)  # symmetric positive definite by construction

    assert trace_det_match_eigenvalues(A)
    print("trace/det match eigenvalues: check passed")

    L = cholesky(A, lower=True)
    assert np.allclose(L @ L.T, A)
    print("L @ L.T == A: check passed")
