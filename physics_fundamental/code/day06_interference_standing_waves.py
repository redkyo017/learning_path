"""
Day 6: two-source interference, beats, Mach-Zehnder complementarity, and
standing-wave mode shapes -- four analytic panels, no integration anywhere.

TWEAK: halve D (panel a source separation) -- fringe spacing (lambda*L/D)
       should visibly double (wider fringes, still several visible across
       the +-40 mm window).
TWEAK: set F2 much closer to F1 (panel b) -- the beat envelope should
       oscillate much more slowly (fewer beats over the same time window).
TWEAK: add a constant offset to PHI (panel c), e.g. PHI + 0.3 -- I1 and I2
       both shift left/right but I1+I2 stays exactly flat at I0.
TWEAK: add more entries to T_SNAPSHOTS (panel d) -- expect the same fixed
       node positions for each n, just a finer time sampling between them.
"""
import numpy as np
import matplotlib.pyplot as plt

# ---- panel (a): two-source interference on a screen ----
LAMBDA = 633e-9   # m, He-Ne red laser
D = 1.0e-4        # m, source separation (TWEAK)
L_SCREEN = 2.0    # m, source-to-screen distance
I0_A = 1.0

y = np.linspace(-0.04, 0.04, 800)          # screen position, m (+-40 mm)
phase_a = 2.0 * np.pi * D * y / (LAMBDA * L_SCREEN)   # delta = k*D*y/L_screen
I_screen = I0_A * np.cos(phase_a / 2.0) ** 2
fringe_spacing = LAMBDA * L_SCREEN / D

# ---- panel (b): beats ----
F1 = 5.0   # Hz
F2 = 5.6   # Hz (TWEAK, together with F1)
W1, W2 = 2.0 * np.pi * F1, 2.0 * np.pi * F2

t = np.linspace(0.0, 4.0, 2000)
y_beats = np.cos(W1 * t) + np.cos(W2 * t)
envelope = 2.0 * np.cos((W1 - W2) / 2.0 * t)

# ---- panel (c): Mach-Zehnder complementarity ----
I0_MZ = 1.0
PHI = np.linspace(0.0, 4.0 * np.pi, 400)
I1 = I0_MZ * np.cos(PHI / 2.0) ** 2
I2 = I0_MZ * np.sin(PHI / 2.0) ** 2
I_sum = I1 + I2

# ---- panel (d): standing-wave modes n=1,2,3 at a few time snapshots ----
L_STRING = 1.0
X_STR = np.linspace(0.0, L_STRING, 400)
OMEGA1 = 2.0 * np.pi                       # base angular frequency, n=1
T1 = 2.0 * np.pi / OMEGA1                  # n=1 period
T_SNAPSHOTS = [0.0, T1 / 8, T1 / 4, 3 * T1 / 8]
MODE_COLORS = ["C0", "C1", "C2"]

fig, axes = plt.subplots(2, 2, figsize=(11, 9))

axes[0, 0].plot(y * 1e3, I_screen)
axes[0, 0].set_title(f"(a) two-source interference\nfringe spacing = {fringe_spacing*1e3:.2f} mm")
axes[0, 0].set_xlabel("screen position y (mm)")
axes[0, 0].set_ylabel("I(y) / I_max")

axes[0, 1].plot(t, y_beats, label="y(t) = cos(w1 t) + cos(w2 t)")
axes[0, 1].plot(t, envelope, "k--", lw=1, label="+/- envelope")
axes[0, 1].plot(t, -envelope, "k--", lw=1)
axes[0, 1].set_title(f"(b) beats: f_beat = |f1-f2| = {abs(F1-F2):.2f} Hz")
axes[0, 1].set_xlabel("t (s)")
axes[0, 1].set_ylabel("y(t)")
axes[0, 1].legend(fontsize=8)

axes[1, 0].plot(PHI, I1, label="I1 = I0 cos^2(phi/2)  [bright port at phi=0]")
axes[1, 0].plot(PHI, I2, label="I2 = I0 sin^2(phi/2)  [dark port at phi=0]")
axes[1, 0].plot(PHI, I_sum, "k--", lw=1, label="I1 + I2 = I0")
axes[1, 0].set_title("(c) Mach-Zehnder complementarity")
axes[1, 0].set_xlabel("phi (rad)")
axes[1, 0].set_ylabel("intensity / I0")
axes[1, 0].legend(fontsize=7)

for n, color in zip([1, 2, 3], MODE_COLORS):
    for j, t_snap in enumerate(T_SNAPSHOTS):
        alpha = 0.3 + 0.7 * j / (len(T_SNAPSHOTS) - 1)
        y_mode = 2.0 * np.sin(n * np.pi * X_STR / L_STRING) * np.cos(n * OMEGA1 * t_snap)
        label = f"n={n}" if j == 0 else None
        axes[1, 1].plot(X_STR, y_mode, color=color, alpha=alpha, label=label)
axes[1, 1].axhline(0, color="gray", lw=0.5)
axes[1, 1].set_title("(d) standing-wave modes n=1,2,3\n(several t snapshots each -- nodes fixed in place)")
axes[1, 1].set_xlabel("x / L")
axes[1, 1].set_ylabel("y(x,t)")
axes[1, 1].legend(fontsize=8)

fig.tight_layout()
plt.show()
