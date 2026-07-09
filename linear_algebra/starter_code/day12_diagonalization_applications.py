"""
Day 12 code lab — diagonalization applications: matrix powers via A = PDP^-1.

Fill in `fib_via_diagonalization` below. Do not look at
solutions/day12_diagonalization_applications.py until you've attempted this
yourself (and finished the pencil-and-paper exercises in content/day12.md).
"""

import numpy as np
import matplotlib.pyplot as plt


def fib_via_diagonalization(n, A, eigvals, eigvecs):
    """
    Compute the n-th term of the sequence (F_{n+1}, F_n) using
    A^n = P @ diag(eigvals**n) @ P_inv, where eigvecs are the columns of P.
    Return just F_n (the second component), as a float.
    Hint: build D_n = np.diag(eigvals ** n), compute
    A_n = eigvecs @ D_n @ np.linalg.inv(eigvecs), then apply A_n to the
    starting vector [1.0, 0.0] (representing (F_1, F_0)) and take index 1.
    """
    # TODO: implement this
    raise NotImplementedError


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
    plt.savefig("starter_code/day12_eigenvector_directions.png")
    print("saved plot")
