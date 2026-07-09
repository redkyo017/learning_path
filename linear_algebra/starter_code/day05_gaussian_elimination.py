"""
Day 5 code lab — Gaussian elimination from scratch.

Fill in `row_echelon` below. Do not look at
solutions/day05_gaussian_elimination.py until you've attempted this yourself
(and finished the pencil-and-paper exercises in content/day05.md).
"""

import numpy as np


def row_echelon(A):
    """
    Return the reduced row echelon form of matrix A, computed via
    elementary row operations implemented by hand (no np.linalg.solve or
    any built-in row-reduction routine).

    Algorithm sketch:
    - For each column (left to right), find a row at or below the current
      pivot row with a nonzero entry in that column (partial pivoting:
      picking a nonzero entry is enough for correctness).
    - Swap it into the current pivot row position.
    - Scale the pivot row so the pivot entry becomes 1.
    - Subtract multiples of the pivot row from every other row to zero out
      that column everywhere else.
    - Advance to the next pivot row; stop early if you run out of rows.
    """
    # TODO: implement this
    raise NotImplementedError


if __name__ == "__main__":
    A = np.array([
        [2.0, 1.0, -1.0],
        [-3.0, -1.0, 2.0],
        [-2.0, 1.0, 2.0],
    ])
    rref = row_echelon(A)
    print("my row echelon form:\n", rref)

    my_rank = np.linalg.matrix_rank(rref)
    np_rank = np.linalg.matrix_rank(A)
    assert my_rank == np_rank
    print("rank matches numpy:", my_rank, "==", np_rank)

    # Extension: run row_echelon on 3 more matrices you did by hand in the
    # exercises, including one singular matrix, and confirm ranks match.
