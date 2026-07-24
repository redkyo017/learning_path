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

## Plain-language review

### Notation decoder

| Symbol | Read it as | In today's context |
|--------|------------|--------------------|
| $A = U\Sigma V^T$ | "the singular value decomposition" | orthonormal input frame $V$, scaling $\Sigma$, orthonormal output frame $U$ |
| $\sigma_i$ | "the $i$-th singular value" | how strongly $A$ acts along its $i$-th principal direction |
| $\sigma_i^2$ | "energy (a squared singular value)" | Eckart-Young measures approximation error in these squared units |
| $\sum_{i\le k}\sigma_i^2 / \sum_i \sigma_i^2$ | "fraction of energy kept by the top $k$" | the 95% compression budget |
| $k$ | "the truncation rank" | how many directions you keep in the approximation |

### The big ideas (conclusions)

- Any matrix at all — square or not, invertible or not — factors as an
  SVD: pick the right orthonormal input and output bases and the map
  becomes pure scaling by the singular values.
- Squared singular values are "energy," and keeping the largest few
  captures most of the matrix in a low-rank approximation.
- Real data hugs a low-dimensional subspace, so a handful of singular
  values dominate and a small $k$ already reaches 95% of the energy.
- Truncated SVD is provably the *best* rank-$k$ approximation there is —
  no other rank-$k$ matrix comes closer (Eckart-Young, Day 22).
- The four fundamental subspaces, the spectral theorem, the SVD, and PCA
  are one family: SVD is the spectral theorem applied to $A^TA$, and PCA
  is that same move applied to a covariance matrix.

### If you remember only 3 things

1. SVD = two orthonormal bases in which any linear map is just scaling by
   the singular values.
2. Energy is the squared singular values; the smallest $k$ whose
   cumulative energy reaches 95% is your compression rank.
3. It all connects — SVD is the spectral theorem on $A^TA$, and PCA is
   the spectral theorem on a covariance matrix: one trick, different
   matrices.

## Journal template

```
## Day 29 — Capstone part 2: SVD + mental map
Key theorem in my own words: ...
What confused me: ...
```
