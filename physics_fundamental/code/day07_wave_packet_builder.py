"""
Day 7 wave-packet builder: square-wave partial sums, a Gaussian-weighted
wave packet at two k-bandwidths, and a dispersing packet under omega=alpha*k^2.

TWEAK: change DK_NARROW / DK_WIDE in panel (b) -- the wide-k-band packet
       should come out visibly NARROWER in x, and vice versa (the bandwidth
       theorem: dx*dk stays roughly constant while dx and dk trade off).
TWEAK: set ALPHA=0.0 in panel (c) -- the three snapshots should sit exactly
       on top of each other (no dispersion, no spreading, pure translation).
TWEAK: raise n_terms in N_TERMS_LIST above 33 (e.g. 99) -- the Gibbs
       overshoot near the jump stays about the same height, it just narrows.
TWEAK: set NK=3 -- with only 3 discrete k-samples instead of a fine
       continuum, panels (b)/(c) stop looking like a single localized
       envelope and look more like a coarse multi-wave beat pattern; this
       is the sum-to-integral limit (content/day07.md) running in reverse.
"""
import numpy as np
import matplotlib.pyplot as plt

# ---------------------------------------------------------------- panel (a)
def square_partial(x, n_terms):
    """Sum the first n_terms odd harmonics of the square-wave sine series
    b_n = 4/(n*pi), n odd (derived in content/day07.md)."""
    total = np.zeros_like(x)
    for j in range(n_terms):
        n = 2 * j + 1
        total += (4.0 / (n * np.pi)) * np.sin(n * x)
    return total


N_TERMS_LIST = [1, 3, 9, 33]
xa = np.linspace(-2 * np.pi, 2 * np.pi, 2000)
target = np.sign(np.sin(xa))

# ------------------------------------------------------------ panels (b),(c)
NK = 300  # number of k-samples approximating the continuum integral;
          # try NK=3 (see TWEAK above) to see the sum-to-integral limit fail


def build_packet(x, t, k0, dk, alpha):
    """Real wave packet sum_n A(k_n) cos(k_n x - omega(k_n) t): a pure numpy
    sum over NK k-samples approximating the continuum integral (no FFT,
    no integrator). A(k) is Gaussian with intensity |A(k)|^2 of std dk."""
    k = np.linspace(k0 - 6 * dk, k0 + 6 * dk, NK)
    amp = np.exp(-(k - k0) ** 2 / (4.0 * dk ** 2))
    omega = alpha * k ** 2
    phase = np.outer(x, k) - t * omega[np.newaxis, :]
    return (amp[np.newaxis, :] * np.cos(phase)).sum(axis=1) * (k[1] - k[0])


def width(x, y):
    """Standard deviation of the intensity profile y**2 of the real signal
    y = sum_n A(k_n) cos(...), as an intensity-weighted average over the
    (uniform) x-grid -- the common grid spacing cancels between numerator
    and denominator, so a plain weighted sum is exact here without needing
    a quadrature rule. This real-signal width numerically matches the
    complex-envelope Delta_x derived in content/day07.md's Theory section
    only because k0 >> dk here, so the carrier oscillation averages out of
    the intensity profile cleanly rather than beating against a
    near-degenerate negative-k mirror image."""
    inten = y ** 2
    norm = inten.sum()
    mean = (x * inten).sum() / norm
    var = ((x - mean) ** 2 * inten).sum() / norm
    return np.sqrt(var)


K0 = 10.0
xb = np.linspace(-15.0, 15.0, 3000)
DK_NARROW, DK_WIDE = 0.5, 2.0

ALPHA = 0.05
DK_C = 1.0
VG = 2 * ALPHA * K0  # group velocity at k0 for omega = alpha*k^2 (day07 theory)
TIMES = [0.0, 15.0, 30.0]
xi = np.linspace(-10.0, 10.0, 2000)  # window centered on the packet's own path

fig, axes = plt.subplots(1, 3, figsize=(16, 4.5))

# --- panel (a) ---
for n_terms in N_TERMS_LIST:
    axes[0].plot(xa, square_partial(xa, n_terms), label=f"N={n_terms}")
axes[0].plot(xa, target, "k--", lw=1, label="square wave")
axes[0].set_title("(a) square-wave partial sums")
axes[0].set_xlabel("x")
axes[0].legend(fontsize=7, ncol=2)

# --- panel (b) ---
print("panel (b): bandwidth theorem check (dx = std dev of intensity)")
for dk, tag in [(DK_NARROW, "narrow band"), (DK_WIDE, "wide band")]:
    psi = build_packet(xb, 0.0, K0, dk, alpha=0.0)
    dx = width(xb, psi)
    print(f"  {tag}: dk={dk:.2f}  dx={dx:.3f}  dx*dk={dx * dk:.3f}")
    axes[1].plot(xb, psi, label=f"{tag}: dk={dk:.1f}, dx~{dx:.2f}, dx*dk~{dx * dk:.2f}")
axes[1].set_title("(b) bandwidth theorem: wide k <-> narrow x")
axes[1].set_xlabel("x")
axes[1].legend(fontsize=7)

# --- panel (c) ---
print(f"panel (c): v_g = 2*alpha*k0 = {VG:.3f}")
for t in TIMES:
    x_phys = xi + VG * t
    psi = build_packet(x_phys, t, K0, DK_C, ALPHA)
    axes[2].plot(xi, psi, label=f"t={t:.0f}")
axes[2].set_title("(c) dispersive spreading (window follows v_g)")
axes[2].set_xlabel("x - v_g t")
axes[2].legend(fontsize=7)

fig.tight_layout()
plt.show()
