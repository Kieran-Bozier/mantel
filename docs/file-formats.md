# File formats

Mantel moves data between its stages in two kinds of file.

| Kind | Files | Purpose |
|---|---|---|
| **`.bin`** | `W_iq*.bin`, `ik-*.bin`, `epsm1_unpadded.bin`, … | Internal transfer between stages. One self-describing container, shared by the Fortran codes and the Python helpers |
| **`.dat`** | `W_ee.dat`, `dos.dat`, `mu.dat` | Final results. Plain text and gnuplot-ready; `W_ee.dat` is the hand-off to [IsoME](https://github.com/cheil/IsoME.jl) |

Nothing in the pipeline uses NumPy `.npy`; those appear only if you convert a `.bin`
yourself for inspection.

---

## The files the pipeline produces

`numBands` below is `in_max - in_min + 1` — the band window from `&mantel`, not the full
`nbnd` of the QE run. See [inputs.md](inputs.md#in_min).

| File | Rank | Type | Dimensions | Written by | Read by |
|---|---|---|---|---|---|
| `band_energies.bin` | 2 | float64 | (`nbnd`, `nks`) | `mantel_xml.py` | `isoenergy.x`, `mu.x` |
| `q_weights.bin` | 1 | float64 | (`nqs`) | `mantel_xml.py` | `isoenergy.x`, `mu.x` |
| `epsm1_unpadded.bin` | 3 | complex128 | (`N_Gy`, `N_Gy`, `nqs`) | `prepare_yambo.py` | `mantel.x` |
| `yambo_qs.bin` | 2 | float64 | (3, `nqs`) | `prepare_yambo.py` | `mantel.x` |
| `yambo_Gs.bin` | 2 | int32 | (3, `N_Gy`) | `prepare_yambo.py` | `mantel.x` |
| `G_vectors.bin` | 2 | int32 | (3, `N_G`) | `wfc2bin.x` | `mantel.x` |
| `cartesian_k.bin` | 2 | float64 | (3, `nks`) | `wfc2bin.x` | `mantel.x` |
| `<wfc_dir>/ik-<N>.bin` | 4 | complex128 | (`nx`, `ny`, `nz`, `numBands`) | `wfc2bin.x` | `mantel.x` |
| `W_iq<N>.bin` | 3 | complex128 | (`numBands`, `numBands`, `nks`) | `mantel.x` | `isoenergy.x`, `mu.x` |
| `ik.bin` | 1 | int32 | (`nks`) | `mantel.x` | — |
| `ikp_iq<N>.bin` | 1 | int32 | (`nks`) | `mantel.x` | `isoenergy.x`, `mu.x` |

`cartesian_k.bin` holds QE's `xk` copied straight from the `wfc#.dat` header;
`prepare_yambo.py` scales the Yambo q-vectors by 2π so `yambo_qs.bin` matches that same
convention. `yambo_Gs.bin` and `G_vectors.bin` hold integer Miller indices, and
`ik-<N>.bin` has `nx = ny = nz = 2*Gmax + 1`.

`W_iq<N>.bin` and `ikp_iq<N>.bin` get one file per q-point, with `N` running over the
range set by `iq_min` and `iq_max`.

---

## `W_ee.dat`

The isoenergy-averaged interaction $W(\varepsilon,\varepsilon')$ from `isoenergy.x` — the
file you pass to IsoME.

Two comment lines, then gnuplot block format: `numE` blocks of `numE` rows **separated by
a blank line**, with $\varepsilon$ fixed within a block and $\varepsilon'$ running over
the grid.

```
# Fermi energy [eV] = 0.  Smearing width (sigma) [eV] = .200000
# energy (e) [eV]      energy (e') [eV]       W(e,e') [eV]
-2.0000000000E+01     -2.0000000000E+01      0.0000000000E+00
-2.0000000000E+01     -1.9798994975E+01      0.0000000000E+00
...
```

| Column | Quantity | Units |
|---|---|---|
| 1 | $\varepsilon$, relative to the Fermi energy | eV |
| 2 | $\varepsilon'$, relative to the Fermi energy | eV |
| 3 | $W(\varepsilon,\varepsilon')$ | eV |

**Energies are relative to the Fermi level** — hence the reported Fermi energy of zero,
the shift is already applied. Grid and smearing come from `numE`, `minE`, `maxE` and
`sigma` in `&isoenergy`.

---

## `dos.dat`

The Gaussian-smeared density of states on the same energy grid, written by `isoenergy.x`
alongside `W_ee.dat`.

```
# Energy (eV)    dos (states/eV/spin)
# Sigma = .200000 eV
-2.0000000000E+01      0.0000000000E+00
...
```

| Column | Quantity | Units |
|---|---|---|
| 1 | Energy, relative to the Fermi energy | eV |
| 2 | Density of states | states/eV/spin |

Note the **per-spin** normalisation — a QE `.dos.dat` is typically states/eV, twice this.
The same factor applies to `nef` (see [inputs.md](inputs.md#nef)). There is no
integrated-DOS column yet, unlike a QE `.dos.dat`.

---

## `mu.dat`

The Coulomb pseudopotential $\mu = N_F \langle\langle W \rangle\rangle_{FS}$ from `mu.x`,
as a function of smearing width. The same table goes to stdout.

The header records the run it came from:

```
# mu(sigma) from mantel
# Fermi energy [eV] =     8.278157
# Bands  in_min = 1  in_max = 10
# Q-pts  iq_min = 1  iq_max = -1
# No external N_F supplied - mu rescaled column set to -1
#   sigma (eV)  N_F (states/eV/spin)  N_F (states/Ry/spin)     W(0,0) (eV)          mu  mu (dos rescaled)
```

| Column | Quantity | Units |
|---|---|---|
| 1 | `sigma` — Gaussian smearing width | eV |
| 2 | `N_F` — density of states at the Fermi energy | states/eV/spin |
| 3 | `N_F` — the same, in Rydberg units | states/Ry/spin |
| 4 | `W(0,0)` — the Fermi-surface-averaged interaction | eV |
| 5 | `mu` — $N_F \langle\langle W \rangle\rangle_{FS}$, from the Gaussian $N_F$ | dimensionless |
| 6 | `mu (dos rescaled)` — the same, using the external `nef` | dimensionless |

One row per smearing, sweeping `min_sigma` to `max_sigma` in `num_sigma` steps.

The `nef` you supplied changes the header:

- **left at `-1.0`** — `# No external N_F supplied`, and **column 6 is `-1` throughout**:
  a marker, not a value.
- **set** — `# External N_F = …` plus `# Ratio to Gaussian N_F at smallest sigma = …`.
  That ratio is the quickest check on the smearing: far from 1 means column 5 is
  unreliable and column 6 is the one to read.

---

## The `.bin` files

A small self-describing header followed by the raw array data:

```
int32       rank          number of array dimensions (1–4)
int32       type_id       1 = int32, 2 = float64, 3 = complex128
int32       dims[0]       extent along dimension 0
   ...                    (rank entries in total)
int32       dims[rank-1]
<array data>              rank-dimensional array, Fortran column-major
```

> **The file is a flat byte stream.** `array_io.f90` opens with
> `access='stream', form='unformatted'`, so the four-byte markers that normally bracket a
> Fortran `write` are absent — a reader assuming sequential access misparses every file.
> It is also what lets the Python helpers work with just `struct` and `numpy`.

The data is **column-major** (first index fastest), so NumPy must reshape with
`order='F'`. Getting it wrong yields a correctly-sized array of transposed nonsense rather
than an error.

### Example

`W_iq1.bin` from the reference data, with 10 bands and 8 k-points:

```
rank       = 3
type_id    = 3            (complex128)
dims       = 10, 10, 8
array data = 10*10*8 * 16 = 12,800 bytes
```

---

## Reading and writing `.bin`

### From Fortran

`src/array_io.f90` provides two generic interfaces:

```fortran
use array_io, only: save_array, load_array

call save_array("W_iq1.bin", W)      ! W is allocated and filled
call load_array("W_iq1.bin", W)      ! W is allocatable, intent(out)
```

Both are overloaded for ranks 1–4 in `real(dp)`, `complex(dp)` and `integer` — twelve
combinations — and `load_array` allocates the destination from the header.

It is also strict: `rank` and `type_id` are checked against the variable passed, and a
mismatch is a fatal error rather than a reinterpretation. Loading a complex array into a
real one fails loudly instead of corrupting silently.

### From Python

`tools/bin_converter.py` converts a `.bin` to a NumPy `.npy`:

```bash
$ tools/bin_converter.py W_iq1.bin                 # → W_iq1.npy
$ tools/bin_converter.py W_iq1.bin --out W.npy     # explicit output name
$ tools/bin_converter.py W_iq1.bin --ord 2,0,1     # transpose while converting
```

| Argument | Description |
|---|---|
| `input_file` | The `.bin` file to convert |
| `--out` | Output filename. Defaults to the input name with a `.npy` extension |
| `--ord` | Comma-separated axis permutation, applied after reading. Needs one entry per dimension |

`tools/npy_converter.py` does the reverse, picking `type_id` from the dtype so the result
loads in `array_io`.
