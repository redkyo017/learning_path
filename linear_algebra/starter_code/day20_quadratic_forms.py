"""
Day 20 code lab — classifying symmetric matrices by definiteness.

Fill in `classify` below. Do not look at
solutions/day20_quadratic_forms.py until you've attempted this yourself (and
finished the pencil-and-paper exercises in content/day20.md).
"""

import numpy as np
import matplotlib.pyplot as plt


def classify(A):
    """
    Classify symmetric matrix A as one of:
    "positive definite", "negative definite", "positive semidefinite",
    "negative semidefinite", or "indefinite", based on the signs of its
    eigenvalues.
    Hint: use np.linalg.eigvalsh(A) (for symmetric matrices) and check the
    signs of the resulting eigenvalues.
    """
    # TODO: implement this
    raise NotImplementedError


if __name__ == "__main__":
    matrices = {
        "pos_def": np.array([[2.0, 0.0], [0.0, 3.0]]),
        "neg_def": np.array([[-1.0, 0.0], [0.0, -4.0]]),
        "indefinite": np.array([[1.0, 0.0], [0.0, -1.0]]),
    }
    expected = {"pos_def": "positive definite", "neg_def": "negative definite", "indefinite": "indefinite"}
    for name, A in matrices.items():
        result = classify(A)
        assert result == expected[name], f"{name}: got {result}, expected {expected[name]}"
    print("All classification checks passed!")

    x = np.linspace(-2, 2, 100)
    y = np.linspace(-2, 2, 100)
    X, Y = np.meshgrid(x, y)
    fig, axes = plt.subplots(1, 3, figsize=(12, 4))
    for ax, (name, A) in zip(axes, matrices.items()):
        Z = A[0, 0] * X**2 + (A[0, 1] + A[1, 0]) * X * Y + A[1, 1] * Y**2
        ax.contour(X, Y, Z, levels=12)
        ax.set_title(f"{name}: {classify(A)}")
    plt.savefig("starter_code/day20_quadratic_forms.png")
    print("saved plot")
