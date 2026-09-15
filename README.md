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
You will still need to follow the conda instructions listed later to setup a suitable environment for the python scripts


Once setup is complete, you can start running the Tutorials in `/examples`.


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

