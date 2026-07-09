"""
Day 15 code lab — the Gram-Schmidt process.

Fill in `gram_schmidt` below. Do not look at
solutions/day15_gram_schmidt.py until you've attempted this yourself (and
finished the pencil-and-paper exercises in content/day15.md).
"""

import numpy as np


def gram_schmidt(vectors):
    """
    Given a list of linearly independent 1D numpy arrays `vectors`, return
    a 2D numpy array Q whose columns are an orthonormal basis for their
    span, computed via the Gram-Schmidt process (no np.linalg.qr calls
    inside this function -- only used afterward to check).
    Hint: build up a list `basis` of orthogonal (not yet normalized)
    vectors one at a time: for each new vector v, subtract its projection
    onto every vector already in `basis`, then append the result. At the
    end, normalize each vector in `basis` and stack as columns.
    """
    # TODO: implement this
    raise NotImplementedError


if __name__ == "__main__":
    vectors = [np.array([1.0, 1.0, 0.0]), np.array([1.0, 0.0, 1.0]), np.array([0.0, 1.0, 1.0])]
    Q = gram_schmidt(vectors)
    assert np.allclose(Q.T @ Q, np.eye(3), atol=1e-8)
    print("Q^T Q == I (orthonormal): check passed")

    Q_np, _ = np.linalg.qr(np.column_stack(vectors))
    assert np.allclose(np.abs(Q), np.abs(Q_np))
    print("matches numpy QR's Q up to column sign: check passed")
