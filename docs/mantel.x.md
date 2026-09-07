# `mantel.x` — Screened Coulomb Calculator

`mantel.x` computes the screened Coulomb interaction matrix elements $W_{\mathbf{k},n , \mathbf{k+q},m}$ in the Bloch basis:

$$
\begin{aligned}
W_{\mathbf{k},n,\mathbf{k+q},m} &= \sum_{\mathbf{G},\mathbf{G'}} \bigg( \frac{1}{V}\frac{4\pi}{\lvert\mathbf{q+G}\rvert \lvert\mathbf{q+G'}\rvert} \epsilon^{-1}_{\mathbf{G},\mathbf{G'}}(\mathbf{q}, 0)\\
&\quad \times 
\rho_{\mathbf{k},n,\mathbf{k+q},m}(\mathbf{G}) \rho^*_{\mathbf{k},n,\mathbf{k+q},m}(\mathbf{G'}) \bigg)
\end{aligned}
$$

For each $\mathbf{q}$-point it pads the Yambo dielectric matrix onto the full G-grid, builds
$V_c(\mathbf{G},\mathbf{G'}) = \frac{4\pi}{\lvert\mathbf{q+G}\rvert\lvert\mathbf{q+G'}\rvert}\epsilon^{-1}_{\mathbf{G},\mathbf{G'}}$,
and contracts it with density products $\rho(\mathbf{G})$ formed by FFT — one $W$ matrix
per q-point, over every k-point and band pair.

---

## Inputs

`mantel.x` reads two configuration files. The run settings you write arrive on **standard
input**; the facts from the DFT run are read from `mantel.nml` in the working directory.
Nothing appears in both.

| File | Blocks read | Source |
|---|---|---|
| `<seed>.mantel.in` | `&qe`, `&mantel` | you, via `mantel_gen.py` |
| `mantel.nml` | `&structure` (lattice vectors), `&system` (`nelec`) | `mantel_xml.py` |

Every variable is documented in [inputs.md](inputs.md). The ones that change what
`mantel.x` does are `in_min`/`in_max` (the band window), `iq_min`/`iq_max` (the q-range,
`-1` meaning all), and `qtf_method`/`qtf_fit_nq` (see below).

> **`&qe` must set `nbnd` and `scf_in` even though `mantel.x` uses neither.** They are
> validated when the block is read, so a `mantel.in` missing them stops the run. Only
> `wfc_dir` is actually used here.

It also needs these binary files in the working directory, all described in
[file-formats.md](file-formats.md#the-files-the-pipeline-produces):

| File | Produced by |
|---|---|
| `G_vectors.bin`, `cartesian_k.bin`, `<wfc_dir>/ik-*.bin` | `wfc2bin.x` |
| `yambo_qs.bin`, `yambo_Gs.bin`, `epsm1_unpadded.bin` | `prepare_yambo.py` |

---

## Running

```bash
$ mantel.x < seed.mantel.in > seed.mantel.out 2>&1
$ OMP_NUM_THREADS=8 mantel.x < seed.mantel.in    # control thread count
$ mantel.x -h                                    # help
```

---

## Outputs

| File | Contents | Written |
|---|---|---|
| `W_iq<N>.bin` | $W$ for q-point `N`, shape (`numBands`, `numBands`, `nks`) | one per q-point, as each finishes |
| `ikp_iq<N>.bin` | the k′ = k+q index map for q-point `N` | one per q-point, as each finishes |
| `ik.bin` | the k-point index list | once, at the end |

`numBands` is `in_max - in_min + 1`, so the band window sets the file size.

Because `W_iq<N>.bin` and `ikp_iq<N>.bin` are written as each q-point completes, an
interrupted run leaves valid files for the q-points it finished. Restart from where it
stopped by setting `iq_min`.

---

## The $\mathbf{q} \to 0$ divergence

At $\mathbf{q}=0$ the $\mathbf{G}=0$ term of $4\pi/\lvert\mathbf{q+G}\rvert^2$ diverges.
`mantel.x` handles this by treating that one element separately: at the $\mathbf{q}=0$
point it sets the **wings** (the $\mathbf{G}=0$ row and column) to zero and replaces the
**head** with the Thomas-Fermi result

$$
V_c(0,0) = \frac{4\pi}{q_{TF}^2}
$$

`qtf_method` selects how $q_{TF}$ is obtained:

| Method | How |
|---|---|
| `"fit"` (default) | A Gauss-Newton least-squares fit of the computed $\epsilon^{-1}_{0,0}(\mathbf{q})$ to the Thomas-Fermi form $q^2/(q^2 + q_{TF}^2)$, over the `qtf_fit_nq` smallest non-zero $\lvert\mathbf{q}\rvert$ |
| `"electrons"` | From the electron density alone: $k_F = (3\pi^2 n)^{1/3}$ and $q_{TF} = \sqrt{4k_F/\pi}$, using `nelec` and the cell volume |

The fit uses your own dielectric matrix rather than a free-electron estimate, which is why
it is the default. `qtf_fit_nq` must be at most `nqs - 1` — the fit skips the
$\mathbf{q}=0$ point itself.

If the fit converges to a non-positive $q_{TF}^2$ it warns and returns zero, and the run
then stops with `Thomas-Fermi wavevector q_TF is too small`. With
`qtf_method = "electrons"` that same error usually means `nelec` is wrong.

On finer $\mathbf{q}$-grids this matters less: the $\Gamma$ point carries a smaller
Brillouin-zone weight, so the substituted head contributes proportionately less to the
final result.

---

## Mapping k+q onto the k-grid

For each q-point, `mantel.x` maps every k+q back onto the k-grid, wrapping into the first
Brillouin zone. Any k+q that finds no match is fatal:

```
Error: Some k+q points could not be mapped to existing k-points.
```

This normally means the Yambo q-grid is not commensurate with the QE k-grid — check `qe_kgrid` against `yambo_kgrid`.

---

## Parallelism

`mantel.x` is currently OpenMP-only; set the thread count with `OMP_NUM_THREADS` (the default is
every available core). The main loop over k-points within each q-point is distributed with
a dynamic schedule, and the dielectric build and k+q search are threaded separately.
