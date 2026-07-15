import numpy as np

N = 16          # 4-qubit search space
marked = 3      # the single marked index, 0-indexed

s = np.ones(N, dtype=complex) / np.sqrt(N)

def oracle(state, marked_index):
    out = state.copy()
    out[marked_index] *= -1
    return out

def diffusion(state):
    proj = np.vdot(s, state) * s  # <s|state> * s
    return 2 * proj - state

state = s.copy()
print(f"iteration 0: P(marked) = {abs(state[marked])**2:.4f}")
for k in range(1, 11):
    state = oracle(state, marked)
    state = diffusion(state)
    print(f"iteration {k}: P(marked) = {abs(state[marked])**2:.4f}")
