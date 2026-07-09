"""
Day 20 code lab — reference solution. Only check this after attempting
starter_code/day20_quadratic_forms.py yourself.
"""

import numpy as np
import matplotlib.pyplot as plt


def classify(A):
    eigvals = np.linalg.eigvalsh(A)
    if np.all(eigvals > 0):
        return "positive definite"
    if np.all(eigvals < 0):
        return "negative definite"
    if np.all(eigvals >= 0):
        return "positive semidefinite"
    if np.all(eigvals <= 0):
        return "negative semidefinite"
    return "indefinite"


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
    plt.savefig("solutions/day20_quadratic_forms.png")
    print("saved plot")

    # Extension: check every matrix from today's exercises against the
    # by-hand classifications, including the degenerate zero-matrix case.
    exercise_matrices = {
        "Ex1": (np.array([[3.0, 0.0], [0.0, 5.0]]), "positive definite"),
        "Ex2": (np.array([[-2.0, 0.0], [0.0, -7.0]]), "negative definite"),
        "Ex3": (np.array([[1.0, 2.0], [2.0, 1.0]]), "indefinite"),
        "Ex4": (np.array([[4.0, 2.0], [2.0, 1.0]]), "positive semidefinite"),
        "Ex5": (np.array([[0.0, 0.0], [0.0, 0.0]]), "positive semidefinite"),
        "Ex6": (
            np.array([[2.0, 1.0, 0.0], [1.0, 2.0, 0.0], [0.0, 0.0, -3.0]]),
            "indefinite",
        ),
        "Ex8": (np.array([[1.0, 5.0], [5.0, 1.0]]), "indefinite"),
    }
    for name, (A, expected_label) in exercise_matrices.items():
        result = classify(A)
        assert result == expected_label, f"{name}: got {result}, expected {expected_label}"
        print(f"{name}: {result} (eigenvalues {np.linalg.eigvalsh(A)})")
    print("All exercise-matrix classifications match the by-hand answers!")
