# Glossary — Physics Fundamentals (QM Bridge)

*Lookup for catch-up: scan for the term you forgot — this is not meant to be read in order. Full treatments live in the day file named at the end of each entry, which is where the term is first used in earnest, not merely mentioned.*

→ [Jump index](#jump-index)

## Notation at a glance

The path reuses a small alphabet across eighteen days, so a few symbols carry more than one job. The collisions below are the ones worth memorizing; each day states its own convention on first use.

| Symbol | Read as | Meaning |
|--------|---------|---------|
| $x, v, a$ | "x, v, a" | position, velocity, acceleration — the kinematic trio of Days 1–4 |
| $k_s$ | "k sub s" | spring constant, written with the subscript on any day where a wave number is also in play (Days 3, 5, 16, 17) |
| $k$ | "k" | wave number, $2\pi/\lambda$ — how many radians of phase fit into a metre |
| $k_e$ | "k sub e" | the Coulomb constant $1/(4\pi\epsilon_0)$, subscripted to stay clear of the wave number |
| $\omega$ | "omega" | angular frequency, $2\pi f$ |
| $\omega_0$ | "omega naught" | an oscillator's *natural* angular frequency, $\sqrt{k_s/m}$ or $\sqrt{V''(x_0)/m}$ |
| $V(x)$ | "V of x" | potential energy as a function of position |
| $T$ | "T" | kinetic energy on Days 9–11 (analytical mechanics); elsewhere kinetic energy is $K$ |
| $L$ | "L" | the Lagrangian on Days 9–11; angular momentum elsewhere; a length (box width, string length) on Days 5–6 and 16–17 — every day states which |
| $H$ | "H" | the Hamiltonian — total energy expressed in terms of coordinates and momenta |
| $\{f,g\}$ | "Poisson bracket of f and g" | the classical bracket that becomes the quantum commutator |
| $[\hat f,\hat g]$ | "commutator of f-hat and g-hat" | $\hat f\hat g-\hat g\hat f$, the quantum counterpart of the Poisson bracket |
| $\hbar$ | "h-bar" | Planck's constant divided by $2\pi$ |
| $\psi$ | "psi" | the wavefunction — a complex probability amplitude as a function of position |
| $\phi_n$ | "phi sub n" | the $n$-th energy eigenfunction (stationary state) of a system |
| $\lvert H\rangle,\lvert V\rangle$ | "ket H / ket V" | horizontal and vertical polarization, written as two-component Jones vectors |
| $\kappa$ | "kappa" | the decay constant of a wavefunction inside a classically forbidden region |
| $\Delta x,\Delta p$ | "delta x / delta p" | statistical spreads (standard deviations) of position and momentum across an ensemble |

## Jump index

[A](#a) · [B](#b) · [C](#c) · [D](#d) · [E](#e) · [F](#f) · [G](#g) · [H](#h) · [I](#i) · [J](#j) · [L](#l) · [M](#m) · [N](#n) · [P](#p) · [Q](#q) · [R](#r) · [S](#s) · [T](#t) · [U](#u) · [W](#w) · [Z](#z)

## A

**Action ($S=\int L\,dt$)** — the running total of the Lagrangian along a path through time. Nature picks the path that makes this total stationary, which turns out to be an exact restatement of Newton's laws. (Day 9)

**Amplitude** — the size of an oscillation's swing: how far from equilibrium it gets at its extreme. In wave and quantum contexts the amplitude can be a complex number, in which case its magnitude sets the size and its phase sets the timing. (Day 3)

**Angular momentum ($L=r\times p$)** — the rotational counterpart of ordinary momentum. It is conserved whenever the physics does not care which way the system is turned. (Day 4)

## B

**Bandwidth theorem ($\Delta x\,\Delta k\gtrsim1$)** — a fact about *all* waves, not just quantum ones: a pulse that is short in space or time must be built from a wide spread of wave numbers or frequencies. Multiply it by $p=\hbar k$ and it becomes Heisenberg's uncertainty principle. (Day 7)

**Beam splitter** — a partly reflecting mirror that takes one input beam and produces two outputs. Written as a matrix acting on the two beams' complex amplitudes, it is the same object your quantum computing course calls a Hadamard gate. (Day 6)

**Beats** — the slow throb heard when two waves of nearly equal frequency overlap: the two drift in and out of step, so their sum swells and fades at the difference frequency. The same mathematics makes probability slosh in a quantum superposition. (Day 6)

**Blackbody** — an idealized object that absorbs every wavelength that hits it, and therefore glows with a spectrum set purely by its temperature. Explaining that spectrum required inventing energy quanta, which is where quantum mechanics starts. (Day 13)

**Bohr radius ($a_0\approx0.529$ Å)** — the characteristic size of a hydrogen atom, about half an ångström. It falls out of balancing the electron's confinement energy against its Coulomb attraction. (Day 14)

**Boltzmann factor ($e^{-E/k_BT}$)** — the weight that says how likely a system in contact with a heat bath is to be found in a state of energy $E$. High-energy states are exponentially rare, and that exponential is what freezes out quantum degrees of freedom when the temperature is low. (Day 12)

**Born rule** — the postulate that connects the wave to what you actually see: the probability of an outcome is the squared magnitude of its complex amplitude. Malus's law in optics turns out to have been the Born rule all along. (Day 8)

**Bound motion (bound state)** — motion trapped between two turning points, so the object oscillates back and forth forever rather than escaping to infinity. Quantum bound states are the ones with discrete, quantized energies. (Day 2)

**Boundary condition** — a requirement imposed at the edges of a region, such as "the string cannot move where it is clamped." Boundary conditions are what turn a continuous range of possible waves into a discrete list of allowed ones. (Day 5)

## C

**Canonical quantization** — the recipe for building a quantum theory from a classical one: keep the same variables, and replace every Poisson bracket with a commutator divided by $i\hbar$. It is a well-motivated guess, not a derivation. (Day 11)

**Commutator ($[\hat f,\hat g]=\hat f\hat g-\hat g\hat f$)** — the amount by which two operations fail to give the same result when applied in the opposite order. When it is nonzero, the two quantities cannot both have sharp values at once. (Day 11)

**Conservative force** — a force that can be written as the downhill slope of a potential energy, $F=-dV/dx$. For such forces the total energy stays constant, which is what makes energy diagrams a complete description of the motion. (Day 2)

## D

**Damped oscillator** — an oscillator losing energy to friction or drag, so its swings shrink over time. How fast they shrink separates gentle ringing from a sluggish return with no oscillation at all. (Day 3)

**de Broglie wavelength ($\lambda=h/p$)** — the wavelength any particle has by virtue of its momentum. It is tiny for everyday objects and comparable to atomic spacings for electrons, which is why electrons diffract and baseballs do not. (Day 15)

**Degrees of freedom** — the independent ways a system can store energy: each direction it can move, rotate, or vibrate. Counting them correctly is what classical statistical mechanics gets right about gases and wrong about their heat capacities. (Day 12)

**Dispersion relation ($\omega(k)$)** — the rule linking a wave's frequency to its wave number, set by the medium. If it is not a straight line, different wavelengths travel at different speeds and a pulse spreads out as it goes. (Day 5)

## E

**Ehrenfest's theorem** — the statement that quantum *average* positions and momenta obey Newton-like equations. It is why a thrown ball follows a classical trajectory even though its wave packet is technically spreading the entire flight. (Day 17)

**Eigenstate** — a state that an operator leaves pointing in the same direction, changing only its scale. Energy eigenstates are the states with one definite energy, and every other state is a superposition of them. (Day 16)

**Equipartition** — the classical rule that every quadratic way of storing energy gets an average $\tfrac12k_BT$. Its failure at low temperatures is one of the clearest experimental fingerprints of quantized energy levels. (Day 12)

**Escape velocity** — the launch speed at which an object's kinetic energy exactly matches the depth of the gravitational well, so it just barely never falls back. A pure energy-conservation result, with no orbital mechanics required. (Day 2)

**Euler–Lagrange equation** — the differential equation that picks out the path making the action stationary. Feeding it a Lagrangian is a mechanical procedure that reproduces $F=ma$ without ever drawing a force. (Day 9)

**Evanescent wave** — a wave that decays exponentially instead of propagating, as light does just past a totally internally reflecting surface. It obeys the same equation as a wavefunction inside a barrier, which is why tunneling and frustrated total internal reflection are one phenomenon in two costumes. (Day 17)

## F

**Fourier series** — the decomposition of any repeating shape into a sum of pure sines and cosines. It is how a plucked string's arbitrary initial shape becomes a list of amplitudes in the normal-mode basis — the same move as expanding a quantum state in energy eigenstates. (Day 7)

## G

**Generalized coordinate** — any convenient variable that pins down a system's configuration: an angle, an arc length, a separation. The Lagrangian machinery works in whatever coordinate is natural, which is its main practical advantage over forces. (Day 9)

**Group velocity ($v_g=d\omega/dk$)** — the speed at which a wave packet's envelope — and therefore its energy and information — actually travels. It can differ sharply from the speed of the individual crests inside it. (Day 7)

## H

**Hamiltonian ($H$)** — the system's total energy written as a function of positions and momenta. It generates the system's evolution in time, both classically and, as the operator $\hat H$, quantum mechanically. (Day 10)

**Harmonic oscillator** — a mass pulled back by a force proportional to its displacement. It matters far beyond springs because *every* smooth potential looks like one near a minimum. (Day 3)

**Hermitian operator** — an operator equal to its own conjugate transpose. Such operators have real eigenvalues and orthogonal eigenstates, which is exactly what is needed to represent something measurable. (Day 16)

## I

**Interference** — the addition of wave amplitudes before they are squared, so two contributions can cancel where either alone would give something. This is the one classical wave behavior that survives intact into quantum mechanics. (Day 6)

## J

**Jones vector** — a two-component complex column vector describing a light beam's polarization. It is a qubit in every mathematical respect, written down in optics decades before anyone used the word. (Day 8)

## L

**Lagrangian ($L=T-V$)** — kinetic energy minus potential energy, the single function from which the entire motion follows via the Euler–Lagrange equation. (Day 9)

**Legendre transform** — the algebraic move that trades a dependence on velocity for a dependence on momentum, carrying you from the Lagrangian to the Hamiltonian. (Day 9)

**Level repulsion** — the generic effect of coupling two energy levels: the upper one moves up and the lower one moves down, so they never cross. It is what a $2\times2$ diagonalization produces every time. (Day 18)

## M

**Mach–Zehnder interferometer** — a device splitting a beam into two arms and recombining it, so a phase difference between the arms shows up as a swing in output brightness. Read as a circuit, it is a Hadamard, a phase gate, and a Hadamard. (Day 6)

**Malus's law ($I=I_0\cos^2\theta$)** — the intensity transmitted by a polarizer at angle $\theta$ to the incoming polarization. It is a projection followed by a squared magnitude, which is to say it is the Born rule. (Day 8)

**Matter wave** — the wave associated with a particle, whose wavelength is set by de Broglie's $\lambda=h/p$. Treating electrons as waves is what makes atomic energy levels a standing-wave counting problem. (Day 15)

**Michelson interferometer** — an interferometer splitting light down two perpendicular arms and recombining it, so moving one mirror sweeps the output through bright and dark fringes. Its sensitivity to sub-wavelength path changes made it the tool that failed to find the ether and now detects gravitational waves. (Day 6)

**Mode** — one specific standing-wave pattern a bounded system is allowed to hold, each with its own frequency. "Which mode, and how much of it" is a complete description of any state of the system. (Day 6)

## N

**Node** — a point of a standing wave that never moves, because the contributions arriving there always cancel. Counting nodes identifies which mode you are looking at, in quantum mechanics as well as on a string. (Day 6)

**Noether's theorem** — the result that every continuous symmetry of a system implies a conserved quantity: time-shift symmetry gives energy, space-shift gives momentum, rotation gives angular momentum. (Day 4)

**Normal mode** — a pattern of motion in which every part of a coupled system oscillates at one common frequency. Any motion at all is a superposition of normal modes, which reduces coupled oscillators to a list of independent simple ones. (Day 5)

**Normalization** — the requirement that total probability comes to exactly $1$: $\int|\psi|^2dx=1$. It fixes the otherwise arbitrary overall scale of a wavefunction. (Day 16)

## P

**Partition function ($Z=\sum e^{-E_i/k_BT}$)** — the sum of Boltzmann factors over every state of a system. Nearly every thermal average can be extracted from it by differentiation, which is why it is the central object of statistical mechanics. (Day 12)

**Phase space** — the space whose axes are position and momentum, in which a system's entire history is a single curve. Its geometry makes conserved quantities and qualitatively different motions visible at a glance. (Day 10)

**Phase velocity ($v_{ph}=\omega/k$)** — the speed of an individual wave crest, as opposed to the speed of the packet as a whole. (Day 5)

**Photoelectric effect** — the ejection of electrons from a metal by light, where the electrons' energy depends on the light's *frequency* and not its brightness. Waves alone cannot explain this; particles of energy $hf$ can. (Day 13)

**Photon** — one quantum of a light mode, carrying energy $hf$. Once a field mode is understood as a harmonic oscillator, "$n$ photons" means precisely "the mode is on rung $n$ of its energy ladder." (Day 13)

**Planck's constant ($h$, and $\hbar=h/2\pi$)** — the constant of proportionality between a quantum's energy and its frequency, and the scale at which quantum effects become unavoidable. (Day 13)

**Poisson bracket ($\{f,g\}$)** — a classical operation on two quantities that says how one changes as the other generates motion. Conserved quantities are exactly those whose bracket with $H$ vanishes — the classical shadow of "commutes with the Hamiltonian." (Day 11)

**Polarization** — the direction in which a light wave's electric field oscillates. Because there are two independent choices, polarization is a genuine physical two-state system. (Day 8)

**Population inversion** — the unnatural situation where more atoms sit in an excited level than in a lower one. It cannot happen in thermal equilibrium, and creating it is what makes a laser possible. (Day 14)

**Potential well** — a dip in the potential-energy landscape that can trap a particle. Reading the shape of $V(x)$ tells you where motion is allowed, where it is forbidden, and where it oscillates. (Day 2)

## Q

**Quantum harmonic oscillator** — the harmonic oscillator solved quantum mechanically, whose energies form an evenly spaced ladder $E_n=\hbar\omega_0(n+\tfrac12)$ starting above zero. The even spacing is what makes energy come in identical countable lumps. (Day 17)

**Quarter-wave plate** — a crystal that delays one polarization component by a quarter cycle relative to the other, converting linear polarization into circular. As a matrix it is a phase gate. (Day 8)

**Qubit** — any quantum system you have agreed to keep only two levels of. Not a special kind of particle: a truncated box, an atom's two lowest levels, a photon's polarization, and a photon's which-path state are all the same $2\times2$ mathematics. (Day 18)

## R

**Resonance** — the large response an oscillator gives when driven near its own natural frequency. It is how systems select frequencies, and why a small periodic push can build a big amplitude. (Day 3)

**Rydberg constant ($R\approx1.097\times10^7\,\text{m}^{-1}$)** — the constant in Balmer's empirical formula for hydrogen's spectral-line wavelengths. Balmer fitted it to data thirty years before anyone could say why; Bohr's model then derived it, which is what turned numerology into physics. (Day 14)

## S

**Separatrix** — the curve in phase space dividing qualitatively different motions, such as a pendulum swinging back and forth from one whirling all the way around. Exactly on it, the motion takes infinite time to arrive. (Day 10)

**Standing wave** — a wave pattern that oscillates in place instead of travelling, formed when waves reflect and interfere with themselves. Boundary conditions permit only a discrete set of them, which is the origin of every quantization result on this path. (Day 6)

**Stationary state** — a state whose probability distribution does not change in time, because its only time dependence is an overall phase $e^{-iEt/\hbar}$. Nothing about the particle is frozen — only the distribution. (Day 16; Bohr's earlier sense of the term appears on Day 14)

**Stimulated emission** — an excited atom being triggered by a passing photon into emitting a second photon identical to it. The copy is what makes light amplification, and therefore lasers, possible. (Day 14)

**Superposition** — adding two valid states to get another valid state, a consequence of the governing equation being linear. Interference is what superposition looks like after you square. (Day 6)

## T

**Terminal velocity** — the speed at which drag exactly cancels gravity, so acceleration stops and the fall becomes steady. The first real payoff of reading $F=ma$ as a differential equation. (Day 1)

**Time-dependent Schrödinger equation (TDSE)** — the equation governing how a wavefunction evolves, $i\hbar\,\partial_t\psi=\hat H\psi$. It is first order in time, so the present state fixes the entire future. (Day 16)

**Time-independent Schrödinger equation (TISE)** — the eigenvalue equation $\hat H\phi=E\phi$ left after separating out the time dependence. Solving it is what produces a system's allowed energies. (Day 16)

**Tunneling** — the leaking of a wavefunction into and through a region a classical particle could never enter, with transmission falling off as $e^{-2\kappa d}$. Energy is conserved throughout; nothing is borrowed. (Day 17)

**Turning point** — a position where a particle's kinetic energy reaches zero, so it stops and reverses. Reading turning points off an energy diagram tells you the range of the motion without solving anything. (Day 2)

**Two-level system** — a quantum system restricted to two relevant states, either genuinely or by truncation. It is the smallest nontrivial quantum system and the template for the qubit. (Day 11)

## U

**Ultraviolet catastrophe** — the classical prediction that a hot cavity radiates infinite power, because there are infinitely many high-frequency modes and equipartition gives each the same energy. Its failure forced the quantum hypothesis. (Day 13)

**Uncertainty principle ($\Delta x\,\Delta p\ge\hbar/2$)** — the limit on how sharply position and momentum can be simultaneously defined. It is a property of the state's own wave structure, not of clumsy measurement, and it follows from Fourier analysis plus $p=\hbar k$. (Day 17)

**Unitary** — a transformation that preserves total probability (or, classically, total energy), so nothing is lost or created. Every quantum evolution and every quantum gate is unitary. (Day 6)

## W

**Wave number ($k=2\pi/\lambda$)** — how much wave phase fits into a unit of distance, the spatial counterpart of angular frequency. (Day 5)

**Wave packet** — a localized bundle of waves, built by adding many wave numbers so they reinforce in one region and cancel elsewhere. It is the closest a wave gets to being a particle, and its spreading is unavoidable in a dispersive medium. (Day 7)

**Wavefunction ($\psi$)** — the complex function whose squared magnitude gives the probability of finding a particle at each position. It is a probability amplitude, not a physical ripple in any medium. (Day 15)

**Work function** — the minimum energy needed to knock an electron out of a particular metal. Subtracting it from the photon energy gives the fastest photoelectron's kinetic energy. (Day 13)

## Z

**Zero-point energy** — the irreducible energy a confined quantum system retains even at absolute zero, $\tfrac12\hbar\omega_0$ for an oscillator. It is a consequence of confinement and uncertainty, not of leftover heat, and it does not go away when you cool the system. (Day 17; first met as the box's $n=1$ floor on Day 16)
