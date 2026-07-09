import numpy as np


def spectral_decompose_and_check(A):
    """
    Given a real symmetric matrix A, return (Q, eigvals, reconstructed)
    where Q is orthogonal, eigvals is the 1D array of eigenvalues, and
    reconstructed = Q @ diag(eigvals) @ Q.T (should equal A).
    Hint: use np.linalg.eigh (NOT np.linalg.eig) -- eigh is specifically
    for symmetric/Hermitian matrices and guarantees a real, orthogonal Q.
    """
    eigvals, Q = np.linalg.eigh(A)
    reconstructed = Q @ np.diag(eigvals) @ Q.T
    return Q, eigvals, reconstructed


if __name__ == "__main__":
    rng = np.random.default_rng(2)
    M = rng.uniform(-3, 3, size=(4, 4))
    A = M + M.T  # symmetric by construction

    Q, eigvals, reconstructed = spectral_decompose_and_check(A)
    assert np.allclose(Q.T @ Q, np.eye(4))
    assert np.allclose(reconstructed, A)
    assert np.all(np.isreal(eigvals))
    print("All checks passed! Q is orthogonal, Q@diag(eigvals)@Q.T == A, eigenvalues are real.")
