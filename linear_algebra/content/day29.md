# Day 29 — Capstone, Part 2: SVD Energy Capture + Mental Map

## Goal

A second, small SVD application, plus a one-page synthesis of the whole
30 days.

## Instructions

1. **SVD energy capture (60 min).** Run `solutions/day29_svd_capstone.py`
   — it builds a random low-rank-ish $50\times30$ matrix, computes its SVD,
   and finds the smallest $k$ that captures 95% of the total "energy"
   $\sum_{i\le k}\sigma_i^2 / \sum_i\sigma_i^2$ (Day 22's Eckart-Young
   framing, applied as a data-compression budget question rather than an
   image). Confirm the printed $k$ makes sense given how the matrix was
   constructed (it's built mostly from a handful of dominant directions, so
   $k$ should be small relative to 30).
2. **Write the mental map (90 min), closed-book.** In `mental_map.md`
   (create it in the project root), write a one-page synthesis connecting
   the major ideas from all 30 days. At minimum, answer: how do the four
   fundamental subspaces (Day 6), the spectral theorem (Day 19), and the
   SVD (Days 21–22) relate to each other? Where does PCA (Day 23) sit in
   that picture? Write this from memory first; check your journal only to
   fill genuine gaps afterward.
3. **Review (30 min).** Reread your mental map and underline any sentence
   you're not fully confident you could defend under questioning — these
   feed Day 30's gap analysis.
4. **Journal entry.**

## Code

`solutions/day29_svd_capstone.py`:

```python
import numpy as np

rng = np.random.default_rng(4)

# Build a matrix that's "secretly" close to rank 3, plus small noise --
# a stand-in for real data where a few directions dominate.
true_directions = rng.normal(size=(50, 3))
weights = rng.normal(size=(3, 30))
A = true_directions @ weights + 0.05 * rng.normal(size=(50, 30))

_, s, _ = np.linalg.svd(A, full_matrices=False)
energy = np.cumsum(s**2) / np.sum(s**2)
k_95 = int(np.searchsorted(energy, 0.95) + 1)

print(f"singular values (first 6): {np.round(s[:6], 3)}")
print(f"smallest k capturing 95% of energy: {k_95} out of {len(s)}")
```

## Journal template

```
## Day 29 — Capstone part 2: SVD + mental map
Key theorem in my own words: ...
What confused me: ...
```
