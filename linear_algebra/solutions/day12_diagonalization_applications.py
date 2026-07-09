"""
Day 12 code lab — reference solution. Only check this after attempting
starter_code/day12_diagonalization_applications.py yourself.
"""

import numpy as np
import matplotlib.pyplot as plt


def fib_via_diagonalization(n, A, eigvals, eigvecs):
    D_n = np.diag(eigvals ** n)
    A_n = eigvecs @ D_n @ np.linalg.inv(eigvecs)
    return (A_n @ np.array([1.0, 0.0]))[1].real


def fib_via_matrix_power(n, A):
    return (np.linalg.matrix_power(A, n) @ np.array([1.0, 0.0]))[1]


if __name__ == "__main__":
    A = np.array([[1.0, 1.0], [1.0, 0.0]])
    eigvals, eigvecs = np.linalg.eig(A)

    for n in [10, 20, 30]:
        via_diag = fib_via_diagonalization(n, A, eigvals, eigvecs)
        via_power = fib_via_matrix_power(n, A)
        assert np.isclose(via_diag, via_power), f"mismatch at n={n}: {via_diag} vs {via_power}"
        print(f"n={n}: diagonalization={via_diag:.1f}, matrix_power={via_power:.1f}")

    fig, ax = plt.subplots()
    for v in eigvecs.T.real:
        ax.plot([0, v[0]], [0, v[1]], marker="o")
    ax.set_title("Eigenvector directions of the Fibonacci matrix")
    ax.set_aspect("equal")
    plt.savefig("solutions/day12_eigenvector_directions.png")
    print("saved plot")

    # Extension: verify Exercise 5's recurrence a_{n+1} = 3a_n - 2a_{n-1},
    # a_0=1, a_1=2, has closed form a_n = 2^n.
    A_rec = np.array([[3.0, -2.0], [1.0, 0.0]])
    x0 = np.array([2.0, 1.0])  # (a_1, a_0)
    for n in range(6):
        a_n = (np.linalg.matrix_power(A_rec, n) @ x0)[1]
        assert np.isclose(a_n, 2.0 ** n), f"mismatch at n={n}: {a_n} vs {2.0**n}"
        print(f"n={n}: a_n={a_n:.1f}, 2^n={2.0**n:.1f}")
    print("Exercise 5 closed form a_n = 2^n confirmed")
