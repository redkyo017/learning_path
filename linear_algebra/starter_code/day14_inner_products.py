"""
Day 14 code lab — Cauchy-Schwarz and the parallelogram law.

Fill in `cauchy_schwarz_holds` and `parallelogram_law_holds` below. Do not
look at solutions/day14_inner_products.py until you've attempted this
yourself (and finished the pencil-and-paper exercises in content/day14.md).
"""

import numpy as np


def cauchy_schwarz_holds(u, v):
    """Return True if |<u,v>| <= ||u|| * ||v|| (Cauchy-Schwarz), within
    floating-point tolerance."""
    # TODO: implement this
    raise NotImplementedError


def parallelogram_law_holds(u, v):
    """Return True if ||u+v||^2 + ||u-v||^2 == 2||u||^2 + 2||v||^2, within
    floating-point tolerance."""
    # TODO: implement this
    raise NotImplementedError


if __name__ == "__main__":
    rng = np.random.default_rng(0)
    for _ in range(5):
        u = rng.uniform(-5, 5, size=4)
        v = rng.uniform(-5, 5, size=4)
        assert cauchy_schwarz_holds(u, v)
        assert parallelogram_law_holds(u, v)
    print("All checks passed across 5 random trials!")

    # Extension (do this after the checks above pass):
    # Write angle_between(u, v) = degrees(arccos(clip(<u,v>/(||u||*||v||), -1, 1)))
    # and confirm it reproduces your hand-computed angles from Exercises 6 and 7.
