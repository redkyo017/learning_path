import numpy as np

def bloch_coords(psi):
    """psi: length-2 complex numpy array, normalized. Returns (x, y, z)."""
    a, b = psi
    x = 2 * np.real(np.conj(a) * b)
    y = 2 * np.imag(np.conj(a) * b)
    z = np.abs(a) ** 2 - np.abs(b) ** 2
    return (x, y, z)

X = np.array([[0, 1], [1, 0]], dtype=complex)
H = (1 / np.sqrt(2)) * np.array([[1, 1], [1, -1]], dtype=complex)

zero = np.array([1, 0], dtype=complex)
one = np.array([0, 1], dtype=complex)
plus = H @ zero

print("|0>:", bloch_coords(zero))
print("|1>:", bloch_coords(one))
print("H|0> (|+>):", bloch_coords(plus))

psi = np.array([0.6, 0.8j], dtype=complex)  # already normalized: 0.6^2+0.8^2=1
print("psi:", bloch_coords(psi))
print("X|psi>:", bloch_coords(X @ psi))
