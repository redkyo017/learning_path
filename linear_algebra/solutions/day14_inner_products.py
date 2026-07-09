"""
Day 14 code lab — reference solution. Only check this after attempting
starter_code/day14_inner_products.py yourself.
"""

import numpy as np


def cauchy_schwarz_holds(u, v):
    lhs = abs(np.dot(u, v))
    rhs = np.linalg.norm(u) * np.linalg.norm(v)
    return lhs <= rhs + 1e-9


def parallelogram_law_holds(u, v):
    lhs = np.linalg.norm(u + v) ** 2 + np.linalg.norm(u - v) ** 2
    rhs = 2 * np.linalg.norm(u) ** 2 + 2 * np.linalg.norm(v) ** 2
    return np.isclose(lhs, rhs)


def angle_between(u, v):
    """Extension: angle between u and v in degrees, robust to floating-point
    drift pushing the cosine a hair outside [-1, 1]."""
    cos_theta = np.dot(u, v) / (np.linalg.norm(u) * np.linalg.norm(v))
    cos_theta = np.clip(cos_theta, -1.0, 1.0)
    return np.degrees(np.arccos(cos_theta))


if __name__ == "__main__":
    rng = np.random.default_rng(0)
    for _ in range(5):
        u = rng.uniform(-5, 5, size=4)
        v = rng.uniform(-5, 5, size=4)
        assert cauchy_schwarz_holds(u, v)
        assert parallelogram_law_holds(u, v)
    print("All checks passed across 5 random trials!")

    # Extension: reproduce Exercises 6 and 7 by hand-computed angle.
    print(angle_between(np.array([1.0, 0.0]), np.array([1.0, 1.0])))  # ~45.0
    print(angle_between(np.array([3.0, 4.0]), np.array([4.0, 3.0])))  # ~16.26
