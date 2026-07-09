"""
Day 15 code lab — reference solution. Only check this after attempting
starter_code/day15_gram_schmidt.py yourself.
"""

import numpy as np


def gram_schmidt(vectors):
    basis = []
    for v in vectors:
        w = v.astype(float).copy()
        for b in basis:
            w -= (np.dot(v, b) / np.dot(b, b)) * b
        basis.append(w)
    return np.column_stack([b / np.linalg.norm(b) for b in basis])


if __name__ == "__main__":
    vectors = [np.array([1.0, 1.0, 0.0]), np.array([1.0, 0.0, 1.0]), np.array([0.0, 1.0, 1.0])]
    Q = gram_schmidt(vectors)
    assert np.allclose(Q.T @ Q, np.eye(3), atol=1e-8)
    print("Q^T Q == I (orthonormal): check passed")

    Q_np, _ = np.linalg.qr(np.column_stack(vectors))
    assert np.allclose(np.abs(Q), np.abs(Q_np))
    print("matches numpy QR's Q up to column sign: check passed")
