# `mu.x` — Coulomb Pseudopotential

`mu.x` evaluates the Fermi-surface average of the screened Coulomb interaction and
multiplies it by the density of states there:

$$
\mu = N_F \left\langle\left\langle W \right\rangle\right\rangle_{FS}
$$

It reads the same `W_iq<N>.bin` files as `isoenergy.x`, but evaluates everything **at the
Fermi level only**. Like `ph.x` in Quantum ESPRESSO, it sweeps through different 
smearing widths $\sigma$ (though note `ph.x` expresses smearings in Ry), as poorly converged runs often vary strongly with $\sigma$.

---

## Inputs

Configuration comes from `mantel.in` on standard input, plus `mantel.nml` in the working
directory. Every variable is documented in [inputs.md](inputs.md).

| Source | Read | Used for |
|---|---|---|
| `&mu` | `min_sigma`, `max_sigma`, `num_sigma` | the smearing sweep |
| | `nef` | optional external $N_F$ (see below) |
| `&mantel` | `in_min`, `in_max` | the band window |
| | `iq_min`, `iq_max` | which q-points to sum (`-1` meaning all) |
| `mantel.nml` `&system` | `scf_fermi` | locating the Fermi level |

Together with these binaries, described in
[file-formats.md](file-formats.md#the-files-the-pipeline-produces):

| File | Produced by |
|---|---|
| `band_energies.bin`, `q_weights.bin` | `mantel_xml.py` |
| `W_iq<N>.bin`, `ikp_iq<N>.bin` | `mantel.x` |

> **`in_min` and `in_max` must match the values `mantel.x` ran with**, exactly as for
> `isoenergy.x` — a mismatch stops the run with `mismatch in the dimensions of W_iq and
> the number of bands`.

---

## Running

`mu.x` is the final step of `mantel_run.sh`. Standalone:

```bash
$ mu.x < seed.mantel.in > mu.out
$ mu.x -h
```

The table is written to `mu.dat` and printed to stdout, so `mu.out` holds a copy.

---

## Outputs

`mu.dat` — one row per smearing width, six columns, with a header recording the band and
q ranges the run used. The full column layout is in
[file-formats.md](file-formats.md#mudat).

---

## What it computes

Each state contributes a Gaussian evaluated **at** the Fermi level rather than across a
grid — the energy argument is zero, leaving only the band energy's distance from $E_F$:

$$
g_\sigma(\mathbf{k},n) = \frac{1}{\sigma\sqrt{\pi}} \exp\left[-\frac{(\varepsilon_{\mathbf{k},n} - E_F)^2}{\sigma^2}\right]
$$

Summing these over bands and k-points and dividing by `nks` gives $N_F(\sigma)$ — column 2,
and column 3 is the same in states/Ry/spin for comparison against QE's `lambda.x`.

The interaction is accumulated over q-points exactly as in `isoenergy.x` — same q-weights,
same `ikp_iq<N>.bin` mapping, same use of only the **real part** of $W$ — giving a
numerator carrying two factors of the density of states. Dividing them back out:

| | |
|---|---|
| $\langle\langle W\rangle\rangle_{FS} = \tilde{\mu}/N_F^2$ | column 4, in eV |
| $\mu = \tilde{\mu}/N_F$ | column 5, dimensionless |

Where $N_F(\sigma) < 10^{-5}$ both are set to zero, so the two can never disagree about
which smearings are trustworthy.

---

## Rescaling with an external $N_F$

Gaussian smearing often gets $N_F$ wrong, and just like the electron-phonon coupling strength $\lambda$, the Coulomb potential $\mu$ is linearly dependent on $N_F$. If you have a better
number (e.g. from a tetrahedron DOS), put it in `nef` and `mu.x` fills column 6 with

$$
\mu_\mathrm{rescaled} = \left\langle\left\langle W \right\rangle\right\rangle_{FS} \times N_F^\mathrm{ext}
$$

keeping the interaction from this calculation and taking only the density of states from
outside. Left at `-1.0`, column 6 is `-1` throughout.

> `nef` is **states/eV/spin**. A QE `.dos.dat` is usually states/eV, so halve it first.

The header line `# Ratio to Gaussian N_F at smallest sigma` tells you how far off the
Gaussian was: near 1 means columns 5 and 6 agree and the sweep converged; far from 1 means
read column 6.

---

## Threading and memory

Like `isoenergy.x`, `mu.x` has no OpenMP of its own — `OMP_NUM_THREADS` reaches it only
through a threaded BLAS. 
