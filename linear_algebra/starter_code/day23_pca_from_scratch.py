import numpy as np
from sklearn.datasets import load_iris
from sklearn.decomposition import PCA

def pca_from_scratch(X, n_components):
    """
    Perform PCA on data matrix X (n_samples x n_features) from scratch.
    Return (projected, components, explained_variance_ratio):
      - projected: X_centered @ components, shape (n_samples, n_components)
      - components: top n_components eigenvectors of the covariance matrix
        as columns, shape (n_features, n_components)
      - explained_variance_ratio: fraction of total variance captured by
        each of the n_components, as a 1D array of length n_components
    Steps: center X, compute covariance matrix (X_centered.T @ X_centered)
    / (n-1), eigendecompose with np.linalg.eigh, sort descending, take top
    n_components, project.
    """
    # TODO: implement this
    raise NotImplementedError


if __name__ == "__main__":
    X = load_iris().data
    projected, components, ratio = pca_from_scratch(X, n_components=2)

    sk_pca = PCA(n_components=2)
    sk_projected = sk_pca.fit_transform(X)

    assert np.allclose(ratio, sk_pca.explained_variance_ratio_)
    assert np.allclose(np.abs(projected), np.abs(sk_projected), atol=1e-6)
    print("explained variance ratio matches sklearn:", ratio)
    print("projections match sklearn up to sign:", True)
