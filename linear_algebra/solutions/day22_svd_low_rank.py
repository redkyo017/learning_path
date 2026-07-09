import numpy as np
import matplotlib.pyplot as plt
from scipy import datasets

def truncated_svd_approx(U, s, Vt, k):
    """
    Given the full SVD (U, s, Vt) of a matrix (as returned by
    np.linalg.svd(A, full_matrices=False)), return the rank-k
    approximation A_k = U[:, :k] @ diag(s[:k]) @ Vt[:k, :].
    """
    return U[:, :k] @ np.diag(s[:k]) @ Vt[:k, :]


if __name__ == "__main__":
    image = datasets.ascent().astype(float)
    U, s, Vt = np.linalg.svd(image, full_matrices=False)

    errors = []
    ks = [5, 20, 50, 100]
    fig, axes = plt.subplots(1, len(ks) + 1, figsize=(15, 4))
    axes[0].imshow(image, cmap="gray")
    axes[0].set_title("original")

    for ax, k in zip(axes[1:], ks):
        approx = truncated_svd_approx(U, s, Vt, k)
        error = np.linalg.norm(image - approx, ord="fro")
        expected_error = np.sqrt(np.sum(s[k:] ** 2))
        assert np.isclose(error, expected_error), f"k={k}: {error} != {expected_error}"
        errors.append(error)
        ax.imshow(approx, cmap="gray")
        ax.set_title(f"k={k}, err={error:.0f}")

    assert all(errors[i] >= errors[i+1] for i in range(len(errors)-1))
    plt.savefig("solutions/day22_svd_compression.png")
    print("All checks passed! errors:", errors)
