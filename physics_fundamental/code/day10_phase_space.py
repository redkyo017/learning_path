"""
Day 10 phase-space portraits: (a) oscillator phase-plane flow field with
nested constant-energy ellipses; (b) pendulum phase-plane contours showing
libration, rotation, and the separatrix between them.

TWEAK: multiply K_S by 4 in panel (a) -- the ellipses get narrower at the
       same height (the p semi-axis sqrt(2*m*E) doesn't depend on k_s at
       all; only the q semi-axis sqrt(2*E/k_s) shrinks); the fixed point
       at the origin and the clockwise sense of the flow stay unchanged.
TWEAK: double L_PEND -- E_SEP = 2*M_PEND*G*L_PEND doubles, so the red
       separatrix moves outward in p_theta, but it still passes through
       theta = +-pi exactly, since that's a geometric fact about the
       unstable equilibrium, not an energy fact.
TWEAK: add a value equal to E_SEP into LIBRATION_ENERGIES -- that contour
       degenerates onto the red separatrix itself; this is exactly why
       E_SEP is called the marginal (infinite-period) energy.
"""
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D

# ---- oscillator parameters ----
M = 1.0
K_S = 4.0  # != M, so sqrt(2E/k_s) (q semi-axis) and sqrt(2mE) (p semi-axis)
           # visibly differ at default energies -- the ellipses look elliptical

# ---- pendulum parameters ----
M_PEND = 1.0
G = 9.8
L_PEND = 1.0
E_SEP = 2.0 * M_PEND * G * L_PEND  # separatrix energy, through theta=+-pi

fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(13, 5.5))

# ---- Panel (a): oscillator phase portrait ----
QMAX, PMAX = 2.5, 2.5
q = np.linspace(-QMAX, QMAX, 30)
p = np.linspace(-PMAX, PMAX, 30)
Q, P = np.meshgrid(q, p)
Qdot = P / M            # qdot = dH/dp
Pdot = -K_S * Q         # pdot = -dH/dq

ax1.streamplot(Q, P, Qdot, Pdot, color="lightsteelblue", density=1.1, linewidth=0.8)

ENERGIES = [0.3, 0.9, 1.8, 3.0]
t = np.linspace(0, 2 * np.pi, 200)
for E in ENERGIES:
    q_e = np.sqrt(2 * E / K_S) * np.cos(t)
    p_e = np.sqrt(2 * M * E) * np.sin(t)
    ax1.plot(q_e, p_e, color="darkblue", lw=1.5)
ax1.plot(0, 0, "ko", ms=5)
ax1.set_xlim(-QMAX, QMAX)
ax1.set_ylim(-PMAX, PMAX)
ax1.set_xlabel("q")
ax1.set_ylabel("p")
ax1.set_title("(a) oscillator: flow field + 4 constant-energy ellipses")

# ---- Panel (b): pendulum phase portrait ----
# Levels and the p_theta range are expressed as multiples of E_SEP (not
# hardcoded absolutes) so that changing L_PEND (which rescales E_SEP)
# rescales everything together -- the labels stay truthful and no contour
# gets clipped by a now-too-small p_theta window.
THETA_MAX = 2 * np.pi
PMAX_PEND = 1.5 * np.sqrt(2 * M_PEND * L_PEND**2 * E_SEP)
theta = np.linspace(-THETA_MAX, THETA_MAX, 500)
ptheta = np.linspace(-PMAX_PEND, PMAX_PEND, 500)
TH, PT = np.meshgrid(theta, ptheta)
H = PT**2 / (2 * M_PEND * L_PEND**2) + M_PEND * G * L_PEND * (1 - np.cos(TH))

LIBRATION_ENERGIES = [0.2 * E_SEP, 0.5 * E_SEP, 0.8 * E_SEP]
ROTATION_ENERGIES = [1.2 * E_SEP, 1.6 * E_SEP, 2.0 * E_SEP]

ax2.contour(TH, PT, H, levels=LIBRATION_ENERGIES, colors="seagreen", linewidths=1.2)
ax2.contour(TH, PT, H, levels=ROTATION_ENERGIES, colors="darkorange", linewidths=1.2)
ax2.contour(TH, PT, H, levels=[E_SEP], colors="red", linewidths=2.8)

for eq_theta in (-2 * np.pi, 0.0, 2 * np.pi):
    ax2.plot(eq_theta, 0, "ko", ms=5)   # stable centers
for eq_theta in (-np.pi, np.pi):
    ax2.plot(eq_theta, 0, "k^", ms=7)   # unstable saddles

legend_handles = [
    Line2D([0], [0], color="seagreen", lw=1.5, label="libration (E < E_sep)"),
    Line2D([0], [0], color="red", lw=2.8, label=f"separatrix, E_sep={E_SEP:.1f}"),
    Line2D([0], [0], color="darkorange", lw=1.5, label="rotation (E > E_sep)"),
]
ax2.legend(handles=legend_handles, loc="upper center", fontsize=8)
ax2.set_xlabel("theta")
ax2.set_ylabel("p_theta")
ax2.set_title("(b) pendulum: libration / separatrix / rotation")

fig.tight_layout()
plt.show()
