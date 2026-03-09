# Test Suite

The test suite in `test/mantel-test.sh` generates input files for four representative
materials and optionally runs the full mantel pipeline on each one. It is the recommended
way to verify that your installation works end-to-end.

---

## Prerequisites

Set the following environment variables before running:

| Variable | Description |
|---|---|
| `PSEUDO_DIR` | Path to the directory containing QE pseudopotential files |
| `SCRATCH_DIR` | Fast temporary storage for QE output (default: `/dev/shm`) |

```bash
export PSEUDO_DIR=/path/to/pseudopotentials
export SCRATCH_DIR=/dev/shm   # or /tmp on macOS
```

QE, Yambo, and the mantel executables must all be in your `PATH`.

---

## Usage

```bash
# Generate test input files AND run the full pipeline for all 4 materials
test/mantel-test.sh

# Generate input files only — do not run any calculations
test/mantel-test.sh -f

# Print help
test/mantel-test.sh -h
```

The `-f` flag is useful for inspecting or editing the generated input files before
committing to a full run.

---

## Test Materials

| Material | Formula | K-grid | nbnd | num_electrons | in_min | in_max | Gmax | Yambo K-grid |
|---|---|---|---|---|---|---|---|---|
| Aluminium | Al | 6×6×6 | 10 | 3 | 1 | 10 | 5 | 6×6×6 |
| Niobium | Nb | 6×6×6 | 20 | 13 | 1 | 20 | 5 | 6×6×6 |
| Tantalum | Ta | 6×6×6 | 20 | 13 | 1 | 20 | 5 | 6×6×6 |
| Hydrogen sulfide | H₃S | 6×6×6 | 13 | 18 | 1 | 13 | 5 | 6×6×6 |

All four use `Gmax = 5` (a coarse grid chosen for speed) and a 6×6×6 k-mesh. Production
calculations would typically use `Gmax = 10–15` and a denser k-grid.

---

## Output Structure

Each material gets its own subdirectory under `test/`:

```
test/
  Al/
    Al.scf.in          QE SCF input
    Al.mantel.in       Unified mantel input
    WFC/               QE wavefunction files
    YAMBO/             Yambo SAVE and RPA directories
    G_vectors.bin      G-vector list (from wfc2bin)
    cartesian_k.bin    K-point coordinates (from wfc2bin)
    epsm1_unpadded.bin Dielectric matrix (from prepare_yambo.py)
    W_iq*.bin          W matrices (from mantel.x)
    W_ee_raw.npy       W(E,E') matrix
    dos_raw.npy        Density of states
    Al-fortran_W_ee_final.pdf   Publication plot
    Al_prep.log        Stage 1 log
    Al_mantel.log      Stage 2 log
  Nb/
    ...
  Ta/
    ...
  H3S/
    ...
```

---

## What a Passing Test Looks Like

After a successful run:

- `W_iq*.bin` files exist for each q-point (number depends on the Yambo k-grid)
- `W_ee_raw.npy` is present and non-zero
- `<seed>-fortran_W_ee_final.pdf` is generated
- No `ERROR` lines appear in `<seed>_prep.log` or `<seed>_mantel.log`

A quick sanity check:

```bash
# Check that W matrices were written
ls test/Al/W_iq*.bin

# Check the log for errors
grep -i error test/Al/Al_mantel.log

# Convert and inspect the W matrix shape
cd test/Al
bin/bin_converter.py W_iq1.bin
python3 -c "import numpy as np; W = np.load('W_iq1.npy'); print(W.shape, W.dtype)"
```

The shape should be `(N_bands, N_bands, N_k)` and dtype `complex128`.
