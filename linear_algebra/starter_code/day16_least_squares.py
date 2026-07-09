"""
Day 16 code lab — orthogonal projections, least squares via the normal
equations.

Fill in `least_squares_normal_equations` below. Do not look at
solutions/day16_least_squares.py until you've attempted this yourself (and
finished the pencil-and-paper exercises in content/day16.md).
"""

import numpy as np
import matplotlib.pyplot as plt


def least_squares_normal_equations(A, y):
    """
    Solve the least-squares problem min ||Ax - y|| via the normal equations
    A^T A x = A^T y. Return x.
    Hint: use np.linalg.inv(A.T @ A) @ A.T @ y, or (better numerically)
    np.linalg.solve(A.T @ A, A.T @ y).
    """
    # TODO: implement this
    raise NotImplementedError


if __name__ == "__main__":
    rng = np.random.default_rng(1)
    x = np.linspace(0, 10, 20)
    y = 2.5 * x + 1.0 + rng.normal(0, 1.5, size=x.shape)

    A = np.column_stack([x, np.ones_like(x)])
    my_solution = least_squares_normal_equations(A, y)
    lstsq_solution, *_ = np.linalg.lstsq(A, y, rcond=None)
    assert np.allclose(my_solution, lstsq_solution)
    print("my normal-equations solution matches np.linalg.lstsq:", my_solution)

    plt.scatter(x, y, label="data")
    plt.plot(x, A @ my_solution, color="red", label="least-squares fit")
    plt.legend()
    plt.savefig("starter_code/day16_least_squares_fit.png")
    print("saved plot")
