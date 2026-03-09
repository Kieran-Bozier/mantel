# Workflow Scripts

The two shell scripts `mantel-prep.sh` and `mantel-run.sh` automate the full calculation
pipeline. Both live in `bin/` and are installed there by `make install`. They share the
same unified `.mantel.in` configuration file.

---

## `mantel-prep.sh` — Stage 1: DFT + Dielectric Matrix

`mantel-prep.sh` orchestrates Stage 1 of the pipeline:
1. Run a QE self-consistent field (SCF) calculation
2. Run a QE bands (NSCF) calculation to generate wavefunctions on the k-grid
3. Run Yambo to compute the RPA dielectric matrix ε⁻¹(G,G',q)

**QE and Yambo must be in your PATH** before running this script.

### Usage

```bash
bin/mantel-prep.sh -c <seed>.mantel.in [options]
```

### Flags

| Flag | Argument | Default | Description |
|---|---|---|---|
| `-c` | `<seed>.mantel.in` | — | **Required.** Unified input file |
| `-n` | integer | 32 | Number of MPI ranks for QE and Yambo |
| `-s` | string | derived from `-c` | Override the seed name |
| `-q` | `"N N N"` | from `&qe` | Override the QE k-grid |
| `-b` | integer | from `&qe` | Override `nbnd` (number of bands) |
| `-y` | `"N N N"` | from `&yambo` | Override the Yambo k-grid |
| `-B` | integer | from `&yambo` | Override `chi_bands` (polarisability bands) |
| `-G` | integer | from `&yambo` (25) | Override `NGsBlkXs` in Ry |
| `-g` | integer | from `&wfc2bin` (12) | Override `Gmax` |
| `-i` | integer | from `&mantel` | Override `in_min` (first band index) |
| `-j` | integer | from `&mantel` | Override `in_max` (last band index) |
| `-h` | — | — | Print help and exit |

### What it produces

| Output | Description |
|---|---|
| `<wfc_dir>/` | QE wavefunction files `wfc*.dat` |
| `<yambo_dir>/SAVE/` | Yambo SAVE database |
| `<yambo_dir>/RPA/` | Yambo RPA dielectric matrix database |
| `<seed>_prep.log` | Full log of all QE and Yambo output |

### Example

```bash
# Run with 16 MPI ranks, overriding the k-grid
bin/mantel-prep.sh -c Al.mantel.in -n 16 -q "10 10 10"
```

---

## `mantel-run.sh` — Stage 2: Compute W and Post-Process

`mantel-run.sh` runs the six-step Stage 2 pipeline starting from the QE/Yambo outputs
produced by `mantel-prep.sh`.

### Usage

```bash
bin/mantel-run.sh -c <seed>.mantel.in [options]
```

### Flags

| Flag | Argument | Default | Description |
|---|---|---|---|
| `-c` | `<seed>.mantel.in` | — | **Required.** Unified input file |
| `-s` | string | derived from `-c` | Override the seed name |
| `-g` | integer | from `&wfc2bin` (12) | Override `Gmax` |
| `-i` | integer | from `&mantel` (1) | Override `in_min` |
| `-j` | integer | from `&mantel` (6) | Override `in_max` |
| `-y` | string | from `&yambo` (YAMBO) | Override Yambo output directory |
| `-h` | — | — | Print help and exit |

### Pipeline steps

**Step 1 — `wfc2bin`**: Convert QE wavefunction files to binary cubes

```
Input:  <wfc_dir>/wfc*.dat
Output: WFC/ik-*.bin, G_vectors.bin, cartesian_k.bin
```

**Step 2 — `prepare_yambo.py`**: Extract Yambo dielectric data to binary format

```
Input:  <yambo_dir>/SAVE, <yambo_dir>/RPA
Output: epsm1_unpadded.bin, yambo_qs.bin, yambo_Gs.bin
```

**Step 3 — `mantel.x`**: Compute the screened Coulomb interaction W(n,m,k)

```
Input:  G_vectors.bin, cartesian_k.bin, yambo_qs.bin, yambo_Gs.bin,
        epsm1_unpadded.bin, WFC/ik-*.bin, <seed>.mantel.in
Output: W_iq*.bin, ik.bin, ikp_iq*.bin, <seed>.mantel.out
```

**Step 4 — `bin_converter.py`**: Convert Fortran binary files to NumPy format

```
Input:  W_iq*.bin, ikp_iq*.bin, ik.bin
Output: W_iq*.npy, ikp_iq*.npy, ik.npy
```

**Step 5 — `W_ee.py`**: Compute the isoenergy-averaged interaction W(E,E')

```
Input:  ik.npy, W_iq*.npy, ikp_iq*.npy,
        <seed>.bands.out (band energies),
        <seed>_yambo.nscf.out (q-point weights),
        Fermi energy (extracted from <seed>.scf.out)
Output: W_ee_raw.npy, dos_raw.npy, W_ee.dat
```

**Step 6 — `plotter.py`**: Generate publication plots

```
Input:  W_ee_raw.npy, dos_raw.npy
Output: <seed>-fortran_W_ee_plots.png
        <seed>-fortran_W_ee_diagonal.png
        <seed>-fortran_W_ee_final.pdf
```

### Fermi energy extraction

The script automatically extracts the Fermi energy from the QE SCF output file
`<seed>.scf.out` and passes it to `W_ee.py`. No manual input is needed.

### Logging

All output is appended to `<seed>_mantel.log` in the working directory.

### Example

```bash
# Run Stage 2 with 4 OpenMP threads
OMP_NUM_THREADS=4 bin/mantel-run.sh -c Al.mantel.in
```
