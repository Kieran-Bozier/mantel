# mantel

**Bloch-basis evaluation of the screened Coulomb interaction**

`mantel` computes the screened Coulomb interaction matrix elements W(n,m,k) in the Bloch basis using DFT wavefunctions and a dielectric matrix from [Yambo](https://www.yambo-code.eu/). It is designed for use in GW and beyond-DFT calculations where the full W in the band basis is required.

The core algorithm uses FFT-based density products combined with the inverse dielectric matrix ε⁻¹(G,G',q) from Yambo to evaluate:

```
W(n,m,k) = ∑_{G,G'} ρ*_{nm,k}(G) · v(G+q) · ε⁻¹(G,G',q) · ρ_{nm,k}(G')
```

---

## Dependencies

### Fortran code

| Dependency | Notes |
|---|---|
| gfortran ≥ 9 | C++ standard library via ISO C bindings |
| FFTW3 | With OpenMP support (`libfftw3_omp`) |
| LAPACK + BLAS | Standard linear algebra |
| OpenMP | Parallelisation over k-points |

On macOS (Homebrew):
```bash
brew install fftw lapack
```

On Linux (apt):
```bash
sudo apt install gfortran libfftw3-dev liblapack-dev libblas-dev
```

On HPC clusters, load the relevant modules (e.g. `module load fftw lapack`).

### Python scripts

See [Python environment setup](#python-environment-setup) below.

---

## Build

```bash
make              # optimised build: -O3 -fopenmp -march=native
make install      # install mantel.x and wfc2bin to bin/
make clean        # remove build artefacts
```

By default, `make` uses `pkg-config` to locate FFTW3. If FFTW is not on your `PKG_CONFIG_PATH`, override with:

```bash
make FFTW_DIR=/path/to/fftw
```

For example, with a manual install at `/opt/fftw`:
```bash
make FFTW_DIR=/opt/fftw
```

A profile/debug build is also available:
```bash
make BUILD=profile   # -O0 -g -pg
```

---

## Python environment setup

The Python post-processing scripts (`prepare_yambo.py`, `W_ee.py`, `bin_converter.py`, `plotter.py`) require **conda** and the `yambopy` package.

### 1. Install conda

If you do not have conda, install [Miniconda](https://docs.conda.io/en/latest/miniconda.html) or [Anaconda](https://www.anaconda.com/).

### 2. Create the `mantel` environment

A minimal conda environment file is provided. Run this once from the repo root:

```bash
conda env create -f environment.yml
```

This will:
- Create a conda environment named `mantel`
- Install `numpy`, `matplotlib`, and `tqdm` from conda-forge (preferred over pip for these packages)
- Install `yambopy` via pip (not available on conda-forge)

### 3. Activate the environment

```bash
conda activate mantel
```

You must activate this environment before running any of the Python scripts. Add this to your shell startup (`.bashrc`, `.zshrc`) or job scheduler script if needed.

### 4. Verify

```bash
python -c "import yambopy, numpy, matplotlib, tqdm; print('Environment OK')"
```

### Note for HPC job scripts

Job schedulers (SLURM, PBS, etc.) typically do not source your shell profile, so `conda activate` may not run automatically. Explicitly activate the environment in your job script:

```bash
#!/bin/bash
#SBATCH --job-name=mantel
# ... other SLURM options ...

source $(conda info --base)/etc/profile.d/conda.sh
conda activate mantel

python bin/W_ee.py ...
```

---

## Full pipeline

```
QE DFT → wfc2bin → prepare_yambo.py → mantel.x → bin_converter.py → W_ee.py → plotter.py
```

| Step | Tool | Description |
|---|---|---|
| 1 | Quantum ESPRESSO | Run DFT calculation, produce wavefunction files |
| 2 | `wfc2bin` | Convert QE wavefunctions to binary format |
| 3 | `bin/prepare_yambo.py` | Extract G-vectors, k-points, ε⁻¹ from Yambo output |
| 4 | `mantel.x` | Compute W(n,m,k) |
| 5 | `bin/bin_converter.py` | Convert output binaries for analysis |
| 6 | `bin/W_ee.py` | Compute electron-electron interaction energy |
| 7 | `bin/plotter.py` | Plot results |

---

## Running `mantel.x`

`mantel.x` reads its configuration from stdin. Create an input file:

```fortran
&config
   wfc_dir       = "WFC"
   num_electrons = 3
   in_min        = 1
   in_max        = 3
/
CELL_PARAMETERS bohr
  -1.988860722  -0.000000000   1.988860722
   0.000000000   1.988860722   1.988860722
  -1.988860722   1.988860722  -0.000000000
```

Then run:

```bash
bin/mantel.x < input.in
```

Or for a multi-threaded run:

```bash
OMP_NUM_THREADS=8 bin/mantel.x < input.in
```

See `mantel.x --help` for a full description of input/output files.

### Required input files

The following binary files must be present in the working directory before running `mantel.x`:

```
G_vectors.bin
cartesian_k.bin
yambo_qs.bin
yambo_Gs.bin
epsm1_unpadded.bin
WFC/ik-1.bin
WFC/ik-2.bin
...
```

These are produced by `wfc2bin` and `prepare_yambo.py`.

---

## Running the test suite

```bash
bin/mantel-test.sh         # generate test data (Al, Nb, Ta, H₃S) and run full pipeline
bin/mantel-test.sh -f      # generate test data only, no execution
```

> **Note:** The test script requires Quantum ESPRESSO and pseudopotentials. Edit the `PSEUDO_DIR` and `SCRATCH_DIR` variables at the top of `bin/mantel-test.sh` before running. See the comments in that file for details.

---

## Citing

If you use `mantel` in your research, please cite:

```
Kieran Bozier, University of Cambridge (2026).
mantel: Bloch-basis evaluation of the screened Coulomb interaction.
https://github.com/kieranbozier/mantel
```

A `CITATION.cff` file is included for machine-readable citation (used by GitHub's "Cite this repository" button).

---

## License

MIT — see [LICENSE](LICENSE).
