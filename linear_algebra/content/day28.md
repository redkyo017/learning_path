# Day 28 — Capstone, Part 1: PCA on a Real Dataset

## Goal

Apply Day 23's PCA derivation end to end on a real dataset, with every line
of code traceable to a specific theorem from this plan.

## Instructions

1. **Re-derive from memory, closed-book (30 min).** Before touching code,
   write out Day 23's full derivation again from scratch: how
   $\operatorname{Var}(Xw) = w^TCw$, why $C$ is symmetric PSD, and why the
   top eigenvector of $C$ maximizes that variance. Compare against your Day
   23 journal entry afterward and note any gaps.
2. **Build the capstone (90 min).** The code is deliberately short — it's
   the *exact* `pca_from_scratch` function from Day 23, applied to a new
   dataset (Wine instead of Iris) so you're exercising the same theorem on
   different data rather than writing new machinery. Run
   `solutions/day28_pca_capstone.py`. Read it side by side with
   `solutions/day23_pca_from_scratch.py` and confirm you understand why the
   same six lines work unchanged on a 13-feature dataset instead of a
   4-feature one.
3. **Annotate (30 min).** In your own copy, add a one-line comment above
   each step naming the Day 19–23 theorem that justifies it (e.g. "# Day 19
   spectral theorem: cov is symmetric ⟹ eigh gives real eigenvalues +
   orthogonal eigenvectors").
4. **Journal entry (15 min).**

## Code

`solutions/day28_pca_capstone.py`:

```python
import numpy as np
from sklearn.datasets import load_wine
from sklearn.decomposition import PCA

def pca_from_scratch(X, n_components):
    X_centered = X - X.mean(axis=0)
    cov = (X_centered.T @ X_centered) / (X_centered.shape[0] - 1)   # Day 23: sample covariance
    eigvals, eigvecs = np.linalg.eigh(cov)                          # Day 19: symmetric -> real, orthogonal eigh
    order = np.argsort(eigvals)[::-1]
    eigvals, eigvecs = eigvals[order], eigvecs[:, order]
    components = eigvecs[:, :n_components]                          # Day 23: top eigenvectors maximize variance
    projected = X_centered @ components
    explained_variance_ratio = eigvals[:n_components] / eigvals.sum()
    return projected, components, explained_variance_ratio


if __name__ == "__main__":
    X, y = load_wine(return_X_y=True)
    projected, components, ratio = pca_from_scratch(X, n_components=2)

    sk_pca = PCA(n_components=2)
    sk_projected = sk_pca.fit_transform(X)

    assert np.allclose(ratio, sk_pca.explained_variance_ratio_)
    print("explained variance ratio:", ratio)
    print("matches sklearn:", True)
```

No separate starter/skeleton today — Day 23 already built and verified this
function from a blank TODO; today is about re-applying and annotating it,
not re-deriving the code.

## Plain-language review

### Notation decoder

| Symbol | Read it as | In today's context |
|--------|------------|--------------------|
| $C = \frac{1}{n-1}X^TX$ | "the sample covariance matrix" | built from the centered data; symmetric and PSD |
| $w^T C w$ | "the variance of the data projected onto direction $w$" | the quantity PCA maximizes |
| $w$ | "a unit direction to project onto" | a candidate principal component |
| top eigenvector | "the eigenvector of the largest eigenvalue" | the first principal component |
| $\lambda_i / \sum_j \lambda_j$ | "explained-variance ratio" | fraction of total variance captured by component $i$ |
| symmetric PSD | "$C = C^T$ and $w^T C w \ge 0$" | what guarantees real eigenvalues and orthogonal components |

### The big ideas (conclusions)

- PCA is nothing more than the spectral theorem applied to the covariance
  matrix: diagonalize $C$ and read the principal directions straight off
  its eigenvectors.
- The variance captured by a unit direction $w$ is $w^T C w$; maximizing
  it over all unit vectors lands exactly on the top eigenvector of $C$.
- Because $C$ is symmetric, its eigenvectors are automatically
  orthogonal, so the principal components form an orthonormal frame with
  no extra work.
- The eigenvalues *are* the variances along each component; dividing each
  by their total gives the explained-variance ratios.
- The same six-line routine runs unchanged on 4-feature Iris or
  13-feature Wine — the theorem does not care about the dimension.

### If you remember only 3 things

1. PCA = the spectral theorem on the covariance matrix; everything else
   is bookkeeping.
2. Maximizing $w^T C w$ over unit vectors is an eigenvalue problem, and
   the answer is the top eigenvector of $C$.
3. Symmetry of $C$ is what makes it all work — real eigenvalues,
   orthogonal components — which is why you call `eigh`, not `eig`.

## Journal template

```
## Day 28 — Capstone part 1: PCA
Key theorem in my own words: ...
What confused me: ...
```
