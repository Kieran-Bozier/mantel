# `mantel.x` — Screened Coulomb Calculator

`mantel.x` computes the screened Coulomb interaction W(n,m,k) in the Bloch basis. For
each irreducible q-point it builds the screened interaction V_c(G,G',q) = v(G+q)·ε⁻¹(G,G',q)
from the pre-prepared Yambo dielectric matrix, then contracts it with real-space density
products ρ(r) = ψ\*_{nk}(r)·ψ_{mk+q}(r) (evaluated via FFT) to obtain W(n,m,k) for every
k-point and band pair. The q=0 Coulomb singularity is replaced by Thomas-Fermi screening.

---

## Required Input Files

All files must be present in the working directory before running `mantel.x`:

| File | Description |
|---|---|
| `G_vectors.bin` | G-vector Miller indices, shape (3, N_G), int32 |
| `cartesian_k.bin` | Cartesian k-point coordinates, shape (3, N_k), float64 (Bohr⁻¹) |
| `yambo_qs.bin` | Yambo q-point vectors, shape (3, N_q), float64 (Bohr⁻¹) |
| `yambo_Gs.bin` | Yambo G-vector Miller indices, shape (3, N_Gy), int32 |
| `epsm1_unpadded.bin` | Dielectric matrix ε⁻¹, shape (N_Gy, N_Gy, N_q), complex128 |
| `WFC/ik-*.bin` | Wavefunction cubes, one per k-point, shape (nx, ny, nz, N_bands), complex128 |

These files are produced by `wfc2bin` and `prepare_yambo.py`. See [wfc2bin.md](wfc2bin.md)
and [post-processing.md](post-processing.md) for details.

---

## Configuration

`mantel.x` reads its configuration from **standard input** using Fortran namelists. Pass
the `.mantel.in` file via shell redirection:

```bash
mantel.x < seed.mantel.in
```

### `&qe` namelist

| Parameter | Type | Description |
|---|---|---|
| `wfc_dir` | string | Directory containing `WFC/ik-*.bin` wavefunction files |
| `qe_kgrid` | string | QE k-grid string, e.g. `"8 8 8"` (read but not used by mantel.x directly) |
| `nbnd` | integer | Total number of bands (read but not used by mantel.x directly) |

### `&mantel` namelist

| Parameter | Type | Description |
|---|---|---|
| `num_electrons` | integer | Number of valence electrons (used to compute k_F for Thomas-Fermi screening) |
| `in_min` | integer | First band index to compute W for (1-based, inclusive) |
| `in_max` | integer | Last band index to compute W for (1-based, inclusive) |

### `CELL_PARAMETERS` block

Specifies the primitive lattice vectors. Units can be `bohr` or `angstrom`:

```fortran
CELL_PARAMETERS bohr
  a1x  a1y  a1z
  a2x  a2y  a2z
  a3x  a3y  a3z
```

These vectors are used to compute reciprocal lattice vectors and the real-space FFT grid.

---

## Running

```bash
# Basic run
mantel.x < seed.mantel.in

# Explicit output file
mantel.x < seed.mantel.in > seed.mantel.out 2>&1

# Control the number of OpenMP threads
OMP_NUM_THREADS=8 mantel.x < seed.mantel.in > seed.mantel.out

# Print help
mantel.x --help
```

---

## Output Files

| File | Description |
|---|---|
| `W_iq<N>.bin` | W(n,m,k) matrix for q-point N, shape (N_bands, N_bands, N_k), complex128 |
| `ik.bin` | K-point index mapping, shape (N_k,), int32 |
| `ikp_iq<N>.bin` | Mapped k'=k+q indices for each q-point N, shape (N_k,), int32 |

### Binary file format

All `.bin` files share a common header:

```
int32   rank          — number of array dimensions
int32   type_id       — 1=int32, 2=float64, 3=complex128
int32   dim[0]        — size along dimension 0
...
int32   dim[rank-1]   — size along dimension rank-1
<data>                — Fortran column-major (fastest index first)
```

Use `bin_converter.py` to convert these to NumPy `.npy` format. See
[post-processing.md](post-processing.md).

---

## Parallelism

`mantel.x` uses **OpenMP** to parallelise the inner loop over k-points for each q-point.
Set the thread count with the `OMP_NUM_THREADS` environment variable:

```bash
export OMP_NUM_THREADS=16
mantel.x < seed.mantel.in
```

By default, OpenMP uses all available cores. For large systems with many k-points and
bands, the dominant cost is the FFT-based density products; scaling is typically linear
up to the number of k-points per q-point.

---

## Notes

### q=0 (Γ-point) special case

At q=0 the bare Coulomb potential v(G+q) diverges. Mantel replaces this singularity with
**Thomas-Fermi screening**:

```
v_TF(q→0) = 4π / (q² + q_TF²)
```

where the Thomas-Fermi wavevector q_TF = √(4k_F/π) is computed from the Fermi wavevector
k_F = (3π²n)^{1/3} using `num_electrons` and the unit cell volume.

### Yambo q-point convention

Yambo may return q-vectors in the Wigner-Seitz cell of the reciprocal lattice rather than
the first Brillouin zone. When mapping k'=k+q back onto the k-grid, mantel checks both
k+q and -(k+q) as fallback, ensuring correct k' identification regardless of Yambo's
q-point folding convention.
