"""
Day 3 oscillator zoo: undamped energy slosh, three damping regimes, and
driven resonance -- three panels, one script.

TWEAK: halve every entry of BETAS_DRIVEN (panel c) -- the resonance peaks
       should grow visibly taller and narrower.
TWEAK: set one entry of BETAS_DAMPED (panel b) above OMEGA0 -- predict the
       shape of x(t) before running: pure decay, no oscillation at all.
TWEAK: double K_S -- OMEGA0 rises with it, and the resonance peaks in
       panel (c) slide to the right (higher drive frequency), since panel
       (c) is plotted against absolute drive frequency, not omega_d/omega0.
"""
import numpy as np
import matplotlib.pyplot as plt

# ---- shared physical parameters ----
M = 1.0
K_S = 1.0                        # spring constant k_s
OMEGA0 = np.sqrt(K_S / M)        # natural frequency, omega_0 = sqrt(k_s/m)
X0, VEL0 = 1.0, 0.0              # initial conditions for the integrated panels
DT = 0.01
T_MAX = 25.0


def euler_cromer(beta, omega0, x0, v0, dt, t_max):
    """Integrate x'' + 2*beta*x' + omega0^2 x = 0 via Euler-Cromer
    (semi-implicit Euler): update v from the current state, then update
    x from the just-updated v. Stable for oscillatory systems."""
    n = int(t_max / dt)
    t = np.linspace(0.0, n * dt, n + 1)
    x = np.zeros(n + 1)
    v = np.zeros(n + 1)
    x[0], v[0] = x0, v0
    for i in range(n):
        a = -omega0**2 * x[i] - 2.0 * beta * v[i]
        v[i + 1] = v[i] + a * dt
        x[i + 1] = x[i] + v[i + 1] * dt
    return t, x, v


fig, axes = plt.subplots(1, 3, figsize=(15, 4.5))

# --- Panel (a): undamped, K(t) and V(t) sloshing, summing to constant E ---
t, x, v = euler_cromer(0.0, OMEGA0, X0, VEL0, DT, T_MAX)
K = 0.5 * M * v**2
V = 0.5 * K_S * x**2
axes[0].plot(t, x, label="x(t)")
axes[0].plot(t, K, label="K(t)")
axes[0].plot(t, V, label="V(t)")
axes[0].plot(t, K + V, "k--", lw=1, label="E = K+V")
axes[0].set_title("(a) undamped: K <-> V slosh")
axes[0].set_xlabel("t")
axes[0].legend(fontsize=8)

# --- Panel (b): three damping regimes at fixed omega_0 ---
BETAS_DAMPED = [0.2 * OMEGA0, 1.0 * OMEGA0, 2.0 * OMEGA0]
LABELS_DAMPED = ["underdamped (0.2 w0)", "critical (1.0 w0)", "overdamped (2.0 w0)"]
for beta, lab in zip(BETAS_DAMPED, LABELS_DAMPED):
    t, x, v = euler_cromer(beta, OMEGA0, X0, VEL0, DT, T_MAX)
    axes[1].plot(t, x, label=lab)
axes[1].axhline(0, color="gray", lw=0.5)
axes[1].set_title("(b) damping regimes")
axes[1].set_xlabel("t")
axes[1].legend(fontsize=8)

# --- Panel (c): driven steady-state amplitude vs drive frequency ---
# Analytic formula (Day 3 theory) -- no integration needed for this panel.
# BETAS_DRIVEN and the sweep range WD are absolute (rad/s), not scaled by
# OMEGA0, so that changing K_S (and hence OMEGA0) visibly moves the peak
# along a fixed axis instead of always landing back at the same spot.
BETAS_DRIVEN = [0.1, 0.3, 0.6]     # absolute damping coefficients, rad/s
F0_OVER_M = 1.0                    # f0 = F0/m; equals F0 here since M = 1
WD_MAX = 2.5                       # fixed absolute sweep ceiling, rad/s
wd = np.linspace(0.01, WD_MAX, 400)
for beta in BETAS_DRIVEN:
    A = F0_OVER_M / np.sqrt((OMEGA0**2 - wd**2)**2 + 4.0 * beta**2 * wd**2)
    axes[2].plot(wd, A, label=f"beta={beta:.2f} rad/s")
axes[2].axvline(OMEGA0, color="gray", lw=0.5, ls=":", label="omega_0")
axes[2].set_title("(c) resonance: amplitude vs drive freq")
axes[2].set_xlabel("w_d [rad/s]")
axes[2].set_ylabel("steady-state amplitude")
axes[2].legend(fontsize=8)

fig.tight_layout()
plt.show()
