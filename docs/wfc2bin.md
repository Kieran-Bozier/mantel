# `wfc2bin` — QE Wavefunction Converter

`wfc2bin` converts Quantum ESPRESSO wavefunction files (`wfc*.dat`) into padded real-space
binary cubes that `mantel.x` can read. For each k-point it reads the plane-wave
coefficients from QE's internal format, zero-pads them onto a uniform real-space grid of
size (2·Gmax+1)³, and writes the result as a compact binary file. It also writes the
corresponding G-vector list and Cartesian k-point coordinates.

---

## Required Input

- A QE `wfc_dir` directory containing `wfc*.dat` files (one per k-point, produced by a
  QE bands or SCF calculation with `wf_collect = .true.`)
- The `G_vectors.bin` file is not required as input — `wfc2bin` generates it

---

## Configuration

`wfc2bin` reads its parameters from the `&wfc2bin` and `&qe` namelist blocks in the
unified `.mantel.in` file (passed via standard input):

```fortran
&qe
   wfc_dir  = "WFC"   ! directory containing wfc*.dat files
   nbnd     = 30      ! total number of bands in the QE calculation
/

&wfc2bin
   Gmax = 12   ! real-space grid half-size: output grid = (2*Gmax+1)^3
/
```

### Parameters

| Parameter | Block | Type | Description |
|---|---|---|---|
| `wfc_dir` | `&qe` | string | Path to the directory containing `wfc*.dat` files |
| `nbnd` | `&qe` | integer | Total number of bands in the QE calculation |
| `Gmax` | `&wfc2bin` | integer | Grid half-size; the output real-space grid is (2·Gmax+1)³ |
| `in_min` | `&mantel` | integer | First band index to extract (1-based) |
| `in_max` | `&mantel` | integer | Last band index to extract (1-based) |

---

## Running

`wfc2bin` is normally invoked automatically by `mantel-run.sh`. To run it standalone:

```bash
wfc2bin < seed.mantel.in
```

The working directory must contain `seed.mantel.in` and the `wfc_dir` directory must be
populated with QE output.

---

## Output Files

All output files are written to the current working directory (G-vectors and k-points) or
the `WFC/` subdirectory (wavefunction cubes):

| File | Shape | Type | Description |
|---|---|---|---|
| `WFC/ik-<N>.bin` | (nx, ny, nz, N_bands) | complex128 | Real-space wavefunction cube for k-point N |
| `G_vectors.bin` | (3, N_G) | int32 | Miller indices of all G-vectors on the padded grid |
| `cartesian_k.bin` | (3, N_k) | float64 | Cartesian coordinates of all k-points (Bohr⁻¹) |

The grid dimensions are `nx = ny = nz = 2·Gmax + 1`. Each `ik-<N>.bin` file stores the
wavefunctions for bands `in_min` through `in_max` at k-point N.

---

## Choosing Gmax

`Gmax` determines the real-space grid resolution. A larger value captures more
high-frequency plane-wave components but increases memory and FFT cost quadratically:

| Gmax | Grid size | Points | Memory per k-point (30 bands) |
|---|---|---|---|
| 8  | 17³ | 4,913  | ~2 MB |
| 10 | 21³ | 9,261  | ~4 MB |
| 12 | 25³ | 15,625 | ~7 MB |
| 15 | 31³ | 29,791 | ~14 MB |

As a rule of thumb, `Gmax` should be at least half the QE kinetic-energy cutoff expressed
in reciprocal lattice units. The test suite uses `Gmax = 5` for speed; production
calculations typically use `Gmax = 10–15`.
