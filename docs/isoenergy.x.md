# `isoenergy.x` — Isoenergy-Averaged Interaction

`isoenergy.x` collapses the state-resolved $W_{\mathbf{k},n,\mathbf{k+q},m}$ from
`mantel.x` onto an energy grid, averaging over all states at energy $\varepsilon$
scattering into all states at energy $\varepsilon'$:

$$
W(\varepsilon,\varepsilon') = \sum_{\mathbf{k},n , \mathbf{k+q},m} W_{\mathbf{k},n , \mathbf{k+q},m} \frac{\delta(\varepsilon - \varepsilon_{\mathbf{k},n})}{N(\varepsilon)} \frac{\delta(\varepsilon' - \varepsilon_{\mathbf{k+q},m})}{N(\varepsilon')}
$$

It is the last step of the pipeline, and `W_ee.dat` is what you pass to IsoME.

---

## Inputs

Configuration comes from `mantel.in` on standard input, plus `mantel.nml` in the
working directory. Every variable is documented in [inputs.md](inputs.md).

| Source | Read | Used for |
|---|---|---|
| `&isoenergy` | `numE`, `minE`, `maxE`, `sigma` | the energy grid and smearing |
| `&mantel` | `in_min`, `in_max` | the band window |
| | `iq_min`, `iq_max` | which q-points to sum (`-1` meaning all) |
| `mantel.nml` `&system` | `scf_fermi` | shifting energies to the Fermi level |

Together with these binaries, described in
[file-formats.md](file-formats.md#the-files-the-pipeline-produces):

| File | Produced by |
|---|---|
| `band_energies.bin`, `q_weights.bin` | `mantel_xml.py` |
| `W_iq<N>.bin`, `ikp_iq<N>.bin` | `mantel.x` |

> **`in_min` and `in_max` must match the values `mantel.x` ran with.** They set the band
> window twice over — once when `mantel.x` sized `W_iq<N>.bin`, and again here — and a
> mismatch stops the run with `mismatch in the dimensions of W_iq and the number of bands`.
> If you rerun with a different window, rerun `mantel.x` too.

`in_max` must also be within the `nbnd` of the QE calculation, since `band_energies.bin`
carries all of them.

---

## Running

```bash
$ isoenergy.x < seed.mantel.in > isoenergy.out
$ isoenergy.x -h
```

Cheap next to `mantel.x` — it reads the `W_iq<N>.bin` files once and does no FFTs.

---

## Outputs

| File | Contents |
|---|---|
| `W_ee.dat` | $W(\varepsilon,\varepsilon')$, normalised — the IsoME hand-off |
| `dos.dat` | the Gaussian-smeared density of states on the same grid |

Both formats are in [file-formats.md](file-formats.md#w_eedat). Energies in both are
relative to the Fermi level.

---

## What it computes

Each Dirac delta becomes a Gaussian of width `sigma`, centred on the band energy measured
from the Fermi level:

$$
g(\varepsilon, \varepsilon_{\mathbf{k},n}) = \frac{1}{\sigma\sqrt{\pi}} \exp\left[-\frac{(\varepsilon - (\varepsilon_{\mathbf{k},n} - E_F))^2}{\sigma^2}\right]
$$

Note the convention: the exponent is $-x^2/\sigma^2$, so `sigma` is $\sqrt{2}$ times the
standard deviation of the equivalent normal distribution. This is chosen to be consistent 
with the convention employed by Quantum ESPRESSO.

The density of states is these Gaussians summed over bands and k-points and divided by
`nks`. The unnormalised interaction is accumulated q-point by q-point,

$$
\tilde{W}(\varepsilon,\varepsilon') = \sum_{\mathbf{q}} w_{\mathbf{q}} \sum_{\mathbf{k}} \sum_{n,m} g(\varepsilon, \varepsilon_{\mathbf{k},n})\, \mathrm{Re}\, W_{nm}(\mathbf{k},\mathbf{q})\, g(\varepsilon', \varepsilon_{\mathbf{k'},m})
$$

with $w_\mathbf{q}$ the q-weight normalised to sum to one, and $\mathbf{k'}$ from
`ikp_iq<N>.bin`. Only the **real part** of $W$ contributes. The two sums over bands are
`dgemm` calls, so the speed of this stage is the speed of your BLAS.

The result is scaled by `Ha_to_eV / nks` and then divided by the density of states:

$$
W(\varepsilon,\varepsilon') = \frac{\tilde{W}(\varepsilon,\varepsilon')}{N(\varepsilon)N(\varepsilon')}
$$

> Where $N(\varepsilon)N(\varepsilon') < 10^{-5}$ the entry is set to **exactly zero**
> instead of divided. This is why `W_ee.dat` is flat zero outside the occupied band range
> rather than noisy — there are no states there to average over.

---

## Threading and memory

`isoenergy.x` has no OpenMP of its own; `OMP_NUM_THREADS` only reaches it through a
threaded BLAS.
