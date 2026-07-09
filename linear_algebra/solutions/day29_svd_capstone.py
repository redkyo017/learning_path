import numpy as np

rng = np.random.default_rng(4)

true_directions = rng.normal(size=(50, 3))
weights = rng.normal(size=(3, 30))
A = true_directions @ weights + 0.05 * rng.normal(size=(50, 30))

_, s, _ = np.linalg.svd(A, full_matrices=False)
energy = np.cumsum(s**2) / np.sum(s**2)
k_95 = int(np.searchsorted(energy, 0.95) + 1)

print(f"singular values (first 6): {np.round(s[:6], 3)}")
print(f"smallest k capturing 95% of energy: {k_95} out of {len(s)}")
