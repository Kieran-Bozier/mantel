# `wfc2bin.x` — QE Wavefunction Converter

`wfc2bin.x` converts Quantum ESPRESSO wavefunction files (`wfc*.dat`) into the `ik-*.bin`
format `mantel.x` reads. For each k-point it takes the plane-wave coefficients and
scatters them onto a cubic $(2 G_\mathrm{max}+1)^3$ grid indexed by Miller index, in FFT
wrap-around order, zero everywhere no coefficient was stored.


---

## Inputs

Configuration comes from `<seed>.mantel.in` on standard input, plus `mantel.nml` in the
working directory. Every variable is documented in [inputs.md](inputs.md).

| Source | Read | Used for |
|---|---|---|
| `&wfc2bin` | `Gmax` | grid size |
| `&mantel` | `in_min`, `in_max` | which bands to extract |
| `&qe` | `wfc_dir` | where the wavefunctions live |
| `mantel.nml` `&grids` | `nks` | how many k-points to expect |

> **`&qe` must also set `nbnd` and `scf_in`, which `wfc2bin.x` never uses.** They are
> validated when the block is read, so omitting them stops the run.

It reads `<wfc_dir>/wfc<i>.dat` for `i = 1 … nks`, and checks up front that all of them
exist rather than failing partway through.

Two QE settings are rejected outright:

- **`npol /= 1`** — non-collinear and spin-orbit wavefunctions are not supported.
- **`gamma_only = .true.`** — this stores only half the G-vectors, which `mantel.x`
  cannot use. Rerun QE without the gamma-only optimisation.

---

## Running

Normally invoked by `mantel_run.sh`. Standalone:

```bash
$ wfc2bin.x < seed.mantel.in
$ wfc2bin.x -h
```

k-points are processed in parallel with OpenMP (dynamic schedule); set `OMP_NUM_THREADS`
to control the thread count.

---

## Outputs

| File | Contents |
|---|---|
| `<wfc_dir>/ik-<N>.bin` | G-space coefficient cube for k-point `N`, shape (`nx`, `ny`, `nz`, `numBands`) |
| `G_vectors.bin` | Miller indices of every G in the box, shape (3, `(2*Gmax+1)³`) |
| `cartesian_k.bin` | k-point coordinates, copied from the `wfc*.dat` headers |

Shapes and the binary layout are in [file-formats.md](file-formats.md). The cubes are
written back into `wfc_dir` alongside the `wfc*.dat` files they came from, not into a
separate directory. `nx = ny = nz = 2*Gmax + 1`, and `numBands = in_max - in_min + 1`.

---

## Choosing Gmax

`Gmax` is a cutoff on the Miller index: any G-vector with a component outside
`[-Gmax, Gmax]` is **discarded**, so too small a value silently throws away part of the
wavefunction.

You do not have to guess. After filling each cube, `wfc2bin.x` compares the norm it kept
against the norm QE wrote, and warns per band when more than 0.1% is lost:

```
WARNING [WFC/ik-3.bin] band 7 retained |c|^2 fraction =   0.987421
```

**Raise `Gmax` until these warnings stop.** A clean run means the box holds essentially
the whole wavefunction.

Cost grows as the cube does — cubically in `Gmax`, in both this stage and every FFT
`mantel.x` later performs — so take the smallest value that runs clean:

| Gmax | Grid | Points | Memory per k-point (30 bands) |
|---|---|---|---|
| 8  | 17³ | 4,913  | ~2 MB |
| 10 | 21³ | 9,261  | ~4 MB |
| 12 | 25³ | 15,625 | ~7 MB |
| 15 | 31³ | 29,791 | ~14 MB |

The test suite uses `Gmax = 5` for speed; production calculations are typically 8–15.
