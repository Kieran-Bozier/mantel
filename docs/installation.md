# Installation 

---

## Prerequisites 
`Mantel` requires both the `Quantum ESPRESSO` and `Yambo` codes to be compiled. 
- [`Quantum ESPRESSO`](https://www.quantum-espresso.org/)
- [`Yambo`](https://www.yambo-code.eu/)

The code has been tested against `Quantum ESPRESSO 7.2` and `Yambo 5.2.4`.

---

## Dependencies

### Fortran code
To compile the fortran codes `wfc2bin.x`, `mantel.x`, `isoenergy.x` and `mu.x` you require:

| Dependency    | Notes                                   |
|---------------|-----------------------------------------|
| gfortran ≥ 9  |                                         |
| FFTW3         | With OpenMP support (`libfftw3_omp`)    |
| LAPACK + BLAS | Any implementation **except** Accelerate on macOS — use OpenBLAS |
| OpenMP        | Parallelisation performed over k-points           |

If Intel MKL is available it supplies FFTW3, BLAS and LAPACK together, and `make` selects it automatically whenever `MKLROOT` is set, and takes precedence unless a different `config` file is specified. The `MKLROOT` variable is normally set for you:
```
$ source /opt/intel/oneapi/setvars.sh     # Intel oneAPI
$ module load mkl                         # typical HPC module
```

If `MKLROOT` is not set, you can install fftw and a BLAS/LAPACK implementation yourself:
- On macOS (Homebrew):\
`$ brew install gcc fftw openblas`

- On Linux (apt):\
`$ sudo apt install gfortran libfftw3-dev liblapack-dev libblas-dev`

- On HPC clusters:\
  Load whatever your system provides. On Cray/HPE machines (LUMI, ARCHER2):
`$ module load PrgEnv-gnu cray-fftw cray-libsci`


### Python scripts
Most of the python scripts require `numpy`, and the `prepare_yambo.py` script also requires `yambopy` to read the output from Yambo.

See [Python environment setup](#python-environment-setup) below for setup.

---

## Build
To build the optimised executables, use
```
$ make              # optimised build: -O3 -fopenmp -march=native
$ make install      # install binaries to bin/
$ make clean        # remove build artefacts
```

Check it worked — you should have four executables:
```
$ ls build/*.x
build/isoenergy.x  build/mantel.x  build/mu.x  build/wfc2bin.x
```

### Platform configuration

Everything machine-specific lives in `config/<name>.mk`, and `make` picks one automatically:

| Config    | Chosen when      | FFTW and BLAS from                             |
|-----------|------------------|------------------------------------------------|
| `mkl`     | `MKLROOT` is set | Intel MKL, which supplies both                 |
| `cray`    | `PE_ENV` is set  | the `ftn` wrapper (`cray-fftw`, `cray-libsci`) |
| `darwin`  | macOS            | Homebrew (`brew --prefix`)                     |
| `generic` | anything else    | `pkg-config`, and the system LAPACK/BLAS       |

Linux and macOS builds are covered by continuous integration. The `cray` and `mkl` configurations are maintained but not exercised by CI.


To list them and see which is active:
```
$ make configs
```

To force one:
```
$ make CONFIG=generic
```

On the `darwin` and `generic` configs you can point at an FFTW install directly, if Homebrew or `pkg-config` cannot find it:
```
$ make FFTW_DIR=/opt/fftw
```

### Other build options

```
$ make BUILD=profile   # -O0 -g -pg -fcheck=all, for debugging
$ make ARCH=           # drop -march=native
```

Use `ARCH=` when the build machine differs from the run machine, or when you need results to agree bit-for-bit between machines: `-march=native` changes vectorisation and therefore floating-point summation order. The `cray` config sets it empty already, since the login node's architecture is not the compute node's.

---

## Python environment setup

Several of the Python scripts require `numpy` and the `yambopy` package. One approach is to use `conda`:

1. Install conda
   If you do not have conda, install [Miniconda](https://docs.conda.io/en/latest/miniconda.html).

2. Create the `mantel` environment
   A minimal conda environment file is provided. Run this once from the repo root:
   ```
   $ conda env create -f environment.yml
   ```

   This will:
   - Create a conda environment named `mantel`
   - Install `numpy`, `matplotlib` and `scienceplots` from conda-forge (preferred over pip for these packages)
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
   $ python -c "import yambopy, numpy, matplotlib, pytest; print('Environment OK')"
   ```


## Next steps
If compilation succeeded, run the [test suite](testing.md) to confirm the binaries reproduce the reference results, then follow the [tutorial](tutorial.md) for a first end-to-end calculation.