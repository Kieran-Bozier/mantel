# Post-Processing Utilities

The `bin/` directory contains four Python scripts that handle data conversion and
analysis after `mantel.x` finishes. They are called automatically by `mantel-run.sh`
but can also be run standalone.

---

## `prepare_yambo.py` — Extract Yambo Dielectric Data

Reads the Yambo SAVE and RPA databases (via yambopy) and writes the dielectric matrix
and associated G-vector/q-point information as Fortran-ordered binary files for `mantel.x`.

### Usage

```bash
bin/prepare_yambo.py <yambo_save_dir> <yambo_job_dir>
```

| Argument | Description |
|---|---|
| `<yambo_save_dir>` | Path to the Yambo SAVE directory (e.g. `YAMBO/SAVE`) |
| `<yambo_job_dir>` | Path to the Yambo RPA job directory (e.g. `YAMBO/RPA`) |

### Dependencies

- `yambopy`
- `numpy`

### Output files

| File | Shape | Type | Description |
|---|---|---|---|
| `epsm1_unpadded.bin` | (N_Gy, N_Gy, N_q) | complex128 | Inverse dielectric matrix ε⁻¹ |
| `yambo_qs.bin` | (3, N_q) | float64 | Q-point vectors in Cartesian coordinates (Bohr⁻¹, scaled by 2π) |
| `yambo_Gs.bin` | (3, N_Gy) | int32 | G-vector Miller indices used by Yambo |

All files use the common binary header format (see [mantel.x.md](mantel.x.md#output-files)).

---

## `bin_converter.py` — Binary ↔ NumPy Converter

Converts Fortran-style `.bin` files to NumPy `.npy` format (or vice versa). Used to
make the `mantel.x` output accessible to Python post-processing scripts.

### Usage

```bash
bin/bin_converter.py <input_file> [--ord AXES] [--out output_file]
```

| Argument | Description |
|---|---|
| `<input_file>` | Input `.bin` file to convert |
| `--ord AXES` | Comma-separated axis permutation, e.g. `1,2,3,0` (optional) |
| `--out output_file` | Output filename (default: input name with `.npy` extension) |

### Examples

```bash
# Convert W matrix for q-point 1
bin/bin_converter.py W_iq1.bin
# → produces W_iq1.npy

# Convert k-point mapping with axis transpose
bin/bin_converter.py ik.bin --ord 0

# Convert all W matrices in a loop
for f in W_iq*.bin; do bin/bin_converter.py "$f"; done
```

### Supported data types

| type_id (header) | NumPy dtype |
|---|---|
| 1 | int32 |
| 2 | float64 |
| 3 | complex128 |

The converter reads Fortran column-major (order='F') data and saves standard C-order `.npy` files.

---

## `W_ee.py` — Isoenergy-Averaged Interaction

Computes W(E,E'), the screened Coulomb interaction averaged over all states at energy E
scattering into all states at energy E'. This is the primary physical output of the
mantel pipeline.

### Usage

```bash
bin/W_ee.py <yambo_nscf_out> <bands_out> <Fermi_energy> [options]
```

| Argument | Description |
|---|---|
| `<yambo_nscf_out>` | Yambo NSCF output file (provides q-point weights) |
| `<bands_out>` | QE bands output file (provides band energies at each k-point) |
| `<Fermi_energy>` | Fermi energy in eV |

### Options

| Flag | Default | Description |
|---|---|---|
| `--sigma FLOAT` | 0.1 | Gaussian smearing width in eV |
| `--numE INT` | 2000 | Number of energy grid points |
| `--minE FLOAT` | -12.0 | Minimum energy relative to Fermi level (eV) |
| `--maxE FLOAT` | 35.0 | Maximum energy relative to Fermi level (eV) |
| `--nmin INT` | 1 | Minimum band index to include (1-based) |
| `--ncores INT` | 32 | Number of parallel worker processes |
| `--test` | off | Run in test mode using pre-computed reference files |

### Input files required (in working directory)

| File | Description |
|---|---|
| `ik.npy` | K-point index array |
| `W_iq*.npy` | W(n,m,k) matrices from `bin_converter.py` |
| `ikp_iq*.npy` | k'=k+q index mappings from `bin_converter.py` |

### Output files

| File | Shape | Description |
|---|---|---|
| `W_ee_raw.npy` | (N_E, N_E) | W(E,E') matrix in eV |
| `dos_raw.npy` | (N_E, 2) | Density of states: column 0 = energy (eV), column 1 = DOS |
| `W_ee.dat` | text | Gnuplot-format table: E, E', W(E,E') |

### Algorithm summary

For each q-point (parallelised over cores), the contribution to W(E,E') is:

```
W(E,E') += (w_q / N_k) Σ_{k,n,m} G(E, ε_{nk}) · W(n,m,k,q) · G(E', ε_{mk'})
```

where G(E, ε) is a Gaussian of width `--sigma` centred at ε, and w_q is the q-point
weight from the Yambo NSCF output. The final result is converted from Hartree to eV.

---

## `plotter.py` — Visualisation

Generates publication-quality plots of W(E,E') and the density of states.

### Usage

```bash
bin/plotter.py <W_file.npy> <dos_file.npy> [options]
```

| Argument | Description |
|---|---|
| `<W_file.npy>` | `W_ee_raw.npy` produced by `W_ee.py` |
| `<dos_file.npy>` | `dos_raw.npy` produced by `W_ee.py` |

### Options

| Flag | Default | Description |
|---|---|---|
| `--seed NAME` | (empty) | Prefix for output filenames |
| `--dosdat PATH` | (none) | Path to a tetrahedra `.dos.dat` file for comparison |
| `--emin FLOAT` | grid minimum | Minimum energy for plot axes (eV) |
| `--emax FLOAT` | grid maximum | Maximum energy for plot axes (eV) |

### Output files

| File | Description |
|---|---|
| `<seed>_W_ee_plots.png` | Multi-panel overview: DOS, 1/DOS, W(E,E'), and normalised W |
| `<seed>_W_ee_diagonal.png` | Diagonal W(E,E) vs energy |
| `<seed>_W_ee_final.pdf` | Publication-quality W(E,E') heatmap |
| `<seed>_W_ee_diagonal.dat` | Numerical data for the diagonal plot |

When `--dosdat` is provided, additional comparison panels using the tetrahedra DOS are
added to the overview figure.

### Example

```bash
bin/plotter.py W_ee_raw.npy dos_raw.npy --seed Al --emin -5 --emax 15
```
