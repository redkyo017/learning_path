"""
Day 16 code lab — reference solution. Only check this after attempting
starter_code/day16_least_squares.py yourself.
"""

import numpy as np
import matplotlib.pyplot as plt


def least_squares_normal_equations(A, y):
    return np.linalg.solve(A.T @ A, A.T @ y)


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
    plt.savefig("solutions/day16_least_squares_fit.png")
    print("saved plot")

    # Extension: fit a quadratic y = a + bx + cx^2 -- still *linear* in the
    # unknowns (a, b, c), hence still ordinary least squares, even though
    # the model is nonlinear in x.
    y_quad = 0.5 * x**2 - 2.0 * x + 3.0 + rng.normal(0, 2.0, size=x.shape)
    A_quad = np.column_stack([np.ones_like(x), x, x**2])
    my_quad_solution = least_squares_normal_equations(A_quad, y_quad)
    lstsq_quad_solution, *_ = np.linalg.lstsq(A_quad, y_quad, rcond=None)
    assert np.allclose(my_quad_solution, lstsq_quad_solution)
    print(
        "quadratic-fit normal-equations solution matches np.linalg.lstsq:",
        my_quad_solution,
    )
