# Mantel — Project Overview

Mantel computes the **screened Coulomb interaction W(n,m,k,q)** in the Bloch basis. Given
Kohn-Sham wavefunctions from a Quantum ESPRESSO (QE) DFT calculation and a dielectric
matrix ε⁻¹(G,G',q) from Yambo's random-phase approximation (RPA), mantel evaluates the
matrix element ⟨nk|W(q)|mk'⟩ for all bands n, m and k-points k, k'=k+q. These matrix
elements are used downstream to compute physically observable quantities such as the
isoenergy-averaged electron–electron interaction W(E,E'), which characterises how strongly
electrons at energy E scatter off electrons at energy E'. This quantity is central to
many-body perturbation theory calculations of, for example, phonon-mediated and purely
electronic pairing in superconductors.

---

## Prerequisites

### System tools
- **gfortran** ≥ 9 (or any Fortran 2008 compiler)
- **FFTW3** (with OpenMP support; Homebrew path: `/opt/homebrew/opt/fftw`)
- **LAPACK** and **BLAS**
- **OpenMP** (bundled with gfortran)
- **GNU make**

### External codes
- **Quantum ESPRESSO** (QE) — DFT SCF + bands calculations
- **Yambo** — RPA dielectric matrix calculation
- **yambopy** — Python interface to Yambo databases (required by `prepare_yambo.py`)

### Python packages
```
numpy
matplotlib
tqdm
yambopy
```

A conda environment works well:
```bash
conda create -n mantel python=3.10 numpy matplotlib tqdm
pip install yambopy
```

---

## Building

All compilation is done from the repository root:

```bash
make                  # optimised build: -O3 -fopenmp -march=native (default)
make BUILD=profile    # debug/profiling build: -O0 -g -pg
make install          # install mantel.x and wfc2bin to bin/
make clean            # remove build artefacts
```

This produces two executables:
- `mantel.x` — the main screened Coulomb calculator
- `wfc2bin` — the QE wavefunction converter

After `make install`, both executables are placed in `bin/`.

---

## Full Pipeline

```
QE DFT (SCF + bands)
        │
        ▼
    wfc2bin
  (convert wfc.dat → WFC/ik-*.bin, G_vectors.bin, cartesian_k.bin)
        │
        ▼
  prepare_yambo.py
  (extract Yambo ε⁻¹ → epsm1_unpadded.bin, yambo_qs.bin, yambo_Gs.bin)
        │
        ▼
    mantel.x
  (compute W(n,m,k,q) → W_iq*.bin, ik.bin, ikp_iq*.bin)
        │
        ▼
  bin_converter.py
  (convert .bin → .npy)
        │
        ▼
     W_ee.py
  (compute W(E,E') → W_ee_raw.npy, dos_raw.npy, W_ee.dat)
        │
        ▼
   plotter.py
  (generate plots → *.png, *.pdf)
```

The two shell scripts `mantel-prep.sh` and `mantel-run.sh` automate stages 1 and 2
respectively; see [workflow.md](workflow.md) for details.

---

## Unified Input File

All tools share a single configuration file `<seed>.mantel.in` containing four namelist
blocks and a `CELL_PARAMETERS` section:

```fortran
&qe
   qe_kgrid = "8 8 8"   ! k-grid used in the QE calculation
   nbnd     = 30         ! total number of bands
   wfc_dir  = "WFC"      ! directory containing wfc*.dat files
/

&yambo
   yambo_kgrid = "6 6 6" ! k-grid used in the Yambo calculation
   chi_bands   = 30       ! number of bands for the polarisability
   NGsBlkXs    = 25       ! dielectric matrix size cutoff (Ry)
   yambo_dir   = "YAMBO"  ! Yambo working directory
/

&wfc2bin
   Gmax = 12   ! real-space grid half-size: grid = (2*Gmax+1)^3
/

&mantel
   num_electrons = 3   ! number of valence electrons
   in_min        = 1   ! first band index to compute W for (1-based)
   in_max        = 10  ! last  band index to compute W for (1-based)
/

CELL_PARAMETERS bohr
  -1.988860722  -0.000000000   1.988860722
   0.000000000   1.988860722   1.988860722
  -1.988860722   1.988860722  -0.000000000
```

- `&qe` and `&wfc2bin` are used by `wfc2bin`
- `&qe` and `&mantel` (plus `CELL_PARAMETERS`) are read by `mantel.x`
- All four blocks are used by the workflow scripts

---

## Quick-Start: Aluminium Test Case

```bash
# 1. Build
make && make install

# 2. Set up environment variables for the test suite
export PSEUDO_DIR=/path/to/pseudopotentials
export SCRATCH_DIR=/dev/shm

# 3. Generate test data and run the full pipeline for all 4 test materials
test/mantel-test.sh

# Or just generate the input files without running:
test/mantel-test.sh -f
```

For a manual run on a single material:
```bash
cd test/Al/
# Stage 1: QE SCF + bands + Yambo RPA
bin/mantel-prep.sh -c Al.mantel.in -n 8

# Stage 2: wfc2bin → prepare_yambo → mantel.x → post-processing
bin/mantel-run.sh -c Al.mantel.in
```

Results appear as `Al-fortran_W_ee_final.pdf` and related files in the `test/Al/` directory.

---

## Per-Tool Documentation

| Document | Contents |
|---|---|
| [mantel.x.md](mantel.x.md) | Main executable: inputs, config, outputs, parallelism |
| [wfc2bin.md](wfc2bin.md) | QE wavefunction converter |
| [workflow.md](workflow.md) | Shell scripts `mantel-prep.sh` and `mantel-run.sh` |
| [post-processing.md](post-processing.md) | Python utilities: prepare_yambo, bin_converter, W_ee, plotter |
| [testing.md](testing.md) | Test suite: materials, usage, expected output |
