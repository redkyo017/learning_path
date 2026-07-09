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
