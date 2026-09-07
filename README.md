# Mantel

 [![CI](https://github.com/Kieran-Bozier/mantel/actions/workflows/ci.yml/badge.svg?branch=developer)](https://github.com/Kieran-Bozier/mantel/actions/workflows/ci.yml)

### Overview

`Mantel` computes the screened Coulomb interaction matrix elements $W_{\mathbf{k},n , \mathbf{k+q},m}$ in the Bloch basis using DFT wavefunctions from [`Quantum ESPRESSO`](https://www.quantum-espresso.org/) and an inverse dielectric matrix from [`Yambo`](https://www.yambo-code.eu/). 

The core algorithm uses FFT-based density products combined with the static inverse dielectric matrix $\epsilon^{-1}_{G,G'}(\mathbf{q}, \omega \rightarrow 0)$ from Yambo to evaluate:

$$
\begin{aligned}
W_{\mathbf{k},n,\mathbf{k+q},m} &= \sum_{\mathbf{G},\mathbf{G'}} \bigg( \frac{1}{V}\frac{4\pi}{\lvert\mathbf{q+G}\rvert \lvert\mathbf{q+G'}\rvert} \epsilon^{-1}_{\mathbf{G},\mathbf{G'}}(\mathbf{q}, 0)\\
&\quad \times 
\rho_{\mathbf{k},n,\mathbf{k+q},m}(\mathbf{G}) \rho^*_{\mathbf{k},n,\mathbf{k+q},m}(\mathbf{G'}) \bigg)
\end{aligned}
$$

where $\mathbf{k}$ is the initial wavevector, $\mathbf{k+q}$ is the final wavevector, $n$ is the initial band index and $m$ is the final band index. The summation is performed over reciprocal lattice vectors $\mathbf{G}, \mathbf{G'}$ and the scattering momentum $\mathbf{q}$ is restricted to the first Brillouin zone. The unit cell volume is denoted by $V$, and $\epsilon^{-1}\_{\mathbf{G},\mathbf{G'}}(\mathbf{q}, 0)$ is the static inverse dielectric matrix, which is calculated here using the Random Phase Approximation (RPA). Higher levels of theory are accessible by modifying the `Yambo` input. The terms $\rho\_{\mathbf{k},n,\mathbf{k+q},m}$ are the plane wave matrix elements and are given by

$$
\rho\_{\mathbf{k},n,\mathbf{k+q},m}(\mathbf{G}) = \left\langle \mathbf{k+q}, m \right\vert e^{+i (\mathbf{q} + \mathbf{G})\cdot\mathbf{r}} \left\vert \mathbf{k}, n \right\rangle
$$

When solving the isotropic Eliashberg equations, we perform an isoenergy averaging of the screened Coulomb interaction. This is performed by the `isoenergy.x` code, and gives

$$
W(\varepsilon,\varepsilon') = \sum\_{\mathbf{k},n , \mathbf{k+q},m} W\_{\mathbf{k},n , \mathbf{k+q},m} \frac{\delta(\varepsilon - \varepsilon\_{\mathbf{k},n})}{N(\varepsilon)} \frac{\delta(\varepsilon' - \varepsilon\_{\mathbf{k+q},m})}{N(\varepsilon')}.
$$

The resulting `W_ee.dat` file can be passed to [`IsoME`](https://github.com/cheil/IsoME.jl) to solve the Isotropic Eliashberg equations.



### Quickstart
If you have `${MKLROOT}` set, you should be able to compile the codes with:
```
$ make
$ make install
```
You will still need to follow the conda instructions listed later to
setup a suitable environment for the python scripts

Provided Quantum ESPRESSO and Yambo are compiled, running the calculations is straightforward, and only requires a Quantum ESPRESSO scf input.
```
$ ls *
scf.in
```
Create the mantel.in input using
```
$ mantel_gen.py -v mantel.in
```
Manually modify to set parameters as desired. Then run
the full pipeline with
```
$ mantel_prep.sh -c mantel.in
   ... [ output here ]  ...

$ mantel_run.sh -c mantel.in
   ... [ output here ] ...
```
This should return a `W_ee.dat` file.

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
To build the optimised executables, use
```
$ make              # optimised build: -O3 -fopenmp -march=native
$ make install      # install mantel.x and wfc2bin to bin/
$ make clean        # remove build artefacts
```

By default, unless you have MKLROOT set, `make` uses `pkg-config` to locate FFTW3. If FFTW is not on your `PKG_CONFIG_PATH`, or you do not have `pkg-config`, override with:
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

The pipeline consists of two high-level scripts 
#### Step 1. `mantel_prep.sh`
This script prepares all the inputs required for `mantel`, by running a `Quantum ESPRESSO` bands calculation to find the wavefunction files, and also running a `Yambo` calculation (at static RPA level) to obtain the inverse dielectric.

#### Step 2. `mantel_run.sh`
This script performs the calculation of W. The `wfc2bin.x` converts the `wfc.dat` format to the `.bin`, while `prepare_yambo.py` writes the inverse dielectric in a `.bin`. The `mantel.x` code combines these to yield `W_iq.bin` files, with the static screened Coulomb interaction in the Bloch basis. Lastly, `isoenergy.x` performs the isoenergy averaging to return `W_ee.dat` and `mu.x` calculates $\mu = N_F \times \langle \langle W \rangle \rangle _{FS}$.


A summary of the codes is shown below. All codes come with a `-h` helper.

|     Code      |     Description                  |
|---------------|----------------------------------|
| `mantel_gen.py` | Generates `mantel.in` template. Use `-v` flag to include comments explaining each variable                 |
| `mantel_xml.py` | Reads the `xml` file from each Quantum ESPRESSO run, and write the `mantel.nml` file, which records information about the runs |
| `wfc2bin.x`    | Converts the converts the `wfc#.dat` to the `ik-#.bin` format |
| `mantel.x`   | Calculates $W_{n,\mathbf{k}, m, \mathbf{k+q}}$ and stores in `W_iq.bin` for each $q$ |
| `isoenergy.x`  |  Performs isoenergy average to return $W(\varepsilon, \varepsilon')$ in `W_ee.dat` |
| `mu.x`         |  Calculates $\mu = N_F \times \langle \langle W \rangle \rangle_{FS}$ for different Gaussian smearings|
| `qe_driver.sh` |  Obtains the QE wavefunctions   |
| `yambo_driver.sh` | Runs the RPA Yambo calculation |



---

## Further Details
More information about how to run each of the codes can be found in the `/docs/` directory





## Running the test suite

```bash
test/mantel_test.sh         # generate test data (Al, Nb, Ta, H₃S) and run full pipeline
test/mantel_test.sh -f      # generate test data only, no execution
```

> **Note:** The test script requires Quantum ESPRESSO and pseudopotentials. Edit the `PSEUDO_DIR` and `SCRATCH_DIR` variables at the top of `test/mantel_test.sh` before running. See the comments in that file for details.

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

