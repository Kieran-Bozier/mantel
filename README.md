# Mantel

### Bloch-basis evaluation of the screened Coulomb interaction 

`Mantel` computes the screened Coulomb interaction matrix elements $W_{\mathbf{k},n , \mathbf{k+q},m}$ in the Bloch basis using DFT wavefunctions from [Quantum ESPRESSO](https://www.quantum-espresso.org/) and an inverse dielectric matrix from [Yambo](https://www.yambo-code.eu/). 

The core algorithm uses FFT-based density products combined with the static inverse dielectric matrix $\epsilon^{-1}_{G,G'}(\mathbf{q}, \omega \rightarrow 0)$ from Yambo to evaluate:

$$
\begin{aligned}
W_{\mathbf{k},n,\,\mathbf{k+q},m} &= \sum_{\mathbf{G}\mathbf{G'}} \bigg( \frac{1}{V}\frac{4\pi}{\lvert\mathbf{q+G}\rvert\,\lvert\mathbf{q+G'}\rvert} \epsilon^{-1}_{\mathbf{G},\mathbf{G'}}(\mathbf{q}, 0)\\
&\quad \times 
\rho_{\mathbf{k},n,\mathbf{k+q},m}(\mathbf{G}) \rho^*_{\mathbf{k},n,\mathbf{k+q},m}(\mathbf{G'}) \bigg)
\end{aligned}
$$

where $\mathbf{k}$ is the initial wavevector, $\mathbf{k+q}$ is the final wavevector, $n$ is the initial band index and $m$ is the final band index. The summation is performed over reciprocal lattice vectors $\mathbf{G}, \mathbf{G'}$ and the scattering momentum $\mathbf{q}$ is restricted to the first Brillouin zone. The unit cell volume is denoted by $V$, and $\epsilon^{-1}_{\mathbf{G},\mathbf{G'}}(\mathbf{q}, 0)$ is the static inverse dielectric matrix, which is calculated here using the Random Phase Approximation (RPA). The terms $\rho_{\mathbf{k},n,\mathbf{k+q},m}$ are the plane wave matrix elements and are given by

$$
    \rho_{\mathbf{k},n,\mathbf{k+q},m}(\mathbf{G}) = \bra{\mathbf{k+q}, m} e^{+i (\mathbf{q} + \mathbf{G})\cdot\mathbf{r}} \ket{\mathbf{k}, n}_{u.c.} 
$$
where the matrix element is evaluated as an integral over the unit cell.



### Quickstart
If you have `${MKLROOT}` set, you should be able to compile the codes with:
```
$ make
$ make install
```
You will still need to follow the conda instructions listed later to
setup a suitable environment for the python scripts

---

## Dependencies

### Fortran code
To compile the fortran codes `wfc2bin.x`, `mantel.x` and `isoenergy.x`, you require:

| Dependency    | Notes                                   |
|---------------|-----------------------------------------|
| gfortran ≥ 9  |                                         |
| FFTW3         | With OpenMP support (`libfftw3_omp`)    |
| LAPACK + BLAS | Standard linear algebra                 |
| OpenMP        | Parallelisation over k-points           |


If you are running on a system with the intel MKL available, then
the makefile will find all of these, provided you specify the MKLROOT
`$ export MKLROOT=/path/to/mklroot`

If not, you can install fftw and lapack using:
- On macOS (Homebrew): 
`$ brew install fftw lapack`

- On Linux (apt): 
`$ sudo apt install gfortran libfftw3-dev liblapack-dev libblas-dev`

- On HPC clusters: 
Load the relevant modules (e.g. `module load fftw lapack`).

### Python scripts
Most of the python scripts require `numpy`, and the `prepare_yambo.py` script also require `yambopy` to read the output from Yambo.

See [Python environment setup](#python-environment-setup) below for setup.

---

## Build
```
$ make              # optimised build: -O3 -fopenmp -march=native
$ make install      # install mantel.x and wfc2bin to bin/
$ make clean        # remove build artefacts
```

By default, unless you have MKLROOT set (at which point the makefile 
uses this), make uses `pkg-config` to locate FFTW3. If FFTW is not on your `PKG_CONFIG_PATH`, or you do not have `pkg-config`, override with:
```
$ make FFTW_DIR=/path/to/fftw
```
For example, with a manual install at `/opt/fftw`:
```
$ make FFTW_DIR=/opt/fftw
```

A profile/debug build is also available:
```
$ make BUILD=profile   # -O0 -g -pg
```

---

## Python environment setup

Several of the Python scripts require `numpy` and the `yambopy` package. One approach is to use `conda`:

1. Install conda
If you do not have conda, install [Miniconda](https://docs.conda.io/en/latest/miniconda.html) or [Anaconda](https://www.anaconda.com/).

2. Create the `mantel` environment
A minimal conda environment file is provided. Run this once from the repo root:
```
$ conda env create -f environment.yml
```

This will:
- Create a conda environment named `mantel`
- Install `numpy`, `matplotlib`, and `tqdm` from conda-forge (preferred over pip for these packages)
- Install `yambopy` via pip (not available on conda-forge)

3. Activate the environment
This can be done with
```
$ conda activate mantel
```
You must activate this environment before running any of the Python scripts. Add this to your shell startup (`.bashrc`, `.zshrc`) or job scheduler script if needed.

4. Verify
Run
```
$ python -c "import yambopy, numpy, matplotlib, tqdm; print('Environment OK')"
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
QE DFT -> Yambo -> wfc2bin -> prepare_yambo.py -> mantel.x -> bin_converter.py -> W_ee.py -> plotter.py
```
|======|==================|===================================================|
| Step | Tool             | Description                                       |
|------|------------------|---------------------------------------------------|
| 1    | Quantum ESPRESSO | Run DFT calculation, produce wavefunction files   |
| 2    | Yambo            | Calculates the inv. dielectric at RPA level       |
| 3    | wfc2bin          | Convert QE wavefunctions to binary format         |
| 4    | prepare_yambo.py | Extract G-vectors, qpoints, ε⁻¹ from Yambo output |
| 5    | mantel.x         | Compute W(n,m,k), the W matrix elements           |
| 6    | bin_converter.py | Convert output binaries to .npy for analysis      |
| 7    | W_ee.py          | Compute isoenergy average of W                    |
| 8    | plotter.py       | Plot results                                      |
|======|==================|===================================================|

---

## Running `mantel.x`

`mantel.x` reads its configuration from stdin. Create an input file:

$ cat Al.mantel.in
&qe
   qe_kgrid = "6 6 6"
   nbnd     = 10
   wfc_dir  = "WFC"
/

&yambo
   yambo_kgrid = "6 6 6"
   chi_bands   = 50
   NGsBlkXs    = 4
   yambo_dir   = "YAMBO"
/

&wfc2bin
   Gmax = 5
/

&mantel
   num_electrons = 3
   in_min        = 1
   in_max        = 10
/

CELL_PARAMETERS angstrom
  -2.005927973   0.000000000   2.005927973
  -0.000000000   2.005927973   2.005927973
  -2.005927973   2.005927973   0.000000000


Then run:
$ mantel.x < input.in

Or for a multi-threaded run:
$ OMP_NUM_THREADS=8 mantel.x < input.in


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
