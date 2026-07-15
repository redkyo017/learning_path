import numpy as np

N = 15
a = 7

# Work register: represent |y> for y in 0..N-1 as a length-N basis vector
# (this sidesteps needing ceil(log2(N)) qubits explicitly, since we only
# need the *permutation matrix* U_a|y> = |a*y mod N>, restricted to y
# coprime to N in practice, but defined on all of 0..N-1 here for simplicity).
def mod_mult_unitary(a, N):
    U = np.zeros((N, N))
    for y in range(N):
        U[(a * y) % N, y] = 1
    return U

U = mod_mult_unitary(a, N)

# Find the order r of a mod N classically, to build controlled-U^(2^j) exactly
# and to check the QPE output against (Day 13 Step 3.3's brute-force result).
r = 1
val = a % N
while val != 1:
    val = (val * a) % N
    r += 1
print(f"order of {a} mod {N}: r = {r}")

t = 6  # phase register precision (bits)
phase_dim = 2 ** t

# Build the full QPE state exactly: start in |1> on the work register
# (an eigenvector-supporting state; U_a's eigenvectors are combinations of
# {a^k mod N}, and starting from |1> after the full circuit yields a
# uniform mixture over k = 0..r-1's eigenphases, which is what a real
# circuit produces too when no single eigenvector is prepared).
work_dim = N
state = np.zeros(phase_dim * work_dim, dtype=complex)
work_start = 1  # |1> on the work register
for x in range(phase_dim):
    state[x * work_dim + work_start] = 1.0
state /= np.sqrt(phase_dim)

# Apply controlled-U^(2^j): for phase-register basis state |x>, apply U^x
# to the work register (this is exactly controlled-U^(2^j) for all j at once,
# since x's binary expansion picks out exactly which powers of 2 apply).
U_powers = {}
def U_power(k):
    if k not in U_powers:
        U_powers[k] = np.linalg.matrix_power(U, k)
    return U_powers[k]

new_state = np.zeros_like(state)
for x in range(phase_dim):
    Ux = U_power(x)
    block = state[x * work_dim:(x + 1) * work_dim]
    new_state[x * work_dim:(x + 1) * work_dim] = Ux @ block
state = new_state

# Inverse QFT on the phase register (work register is a spectator here).
def inverse_qft_matrix(dim):
    omega = np.exp(-2j * np.pi / dim)
    return np.array([[omega ** (x * y) for y in range(dim)] for x in range(dim)]) / np.sqrt(dim)

IQFT = inverse_qft_matrix(phase_dim)
state_reshaped = state.reshape(phase_dim, work_dim)
state_reshaped = IQFT @ state_reshaped
state = state_reshaped.reshape(-1)

# Measure the phase register: sum probability over the work register.
probs = np.sum(np.abs(state.reshape(phase_dim, work_dim)) ** 2, axis=1)
print("Top phase-register outcomes (x, probability, x/2^t):")
top = np.argsort(probs)[::-1][:8]
for x in sorted(top):
    print(f"  x={x:3d}  P={probs[x]:.4f}  x/2^t={x/phase_dim:.4f}  (expect near k/{r} for integer k)")
