# Overview

`mantel` computes the statically screened Coulomb interaction $W$ in the Bloch basis, from
DFT wavefunctions produced by [Quantum ESPRESSO](https://www.quantum-espresso.org/) and an
inverse dielectric matrix produced by [Yambo](https://www.yambo-code.eu/).

This pipeline produces $W(\varepsilon,\varepsilon')$ - the
interaction averaged onto pairs of isoenergy surfaces - written as `W_ee.dat` in the format
[IsoME](https://github.com/cheil/IsoME.jl) reads when solving the isotropic Eliashberg
equations. The Coulomb parameter $\mu$ falls out of the same data, which can be used to calculate the Coulomb pseudopotential.

The full expressions are in [mantel.x.md](mantel.x.md) and
[isoenergy.x.md](isoenergy.x.md); the README states them in one place.

---

## Where to start

1. [installation.md](installation.md) — build the Fortran, create the conda environment.
2. [tutorial.md](tutorial.md) — the worked examples in `examples/`. Tutorial01 is a small
   Nb run that checks the executables behave; Tutorial02 is a standard Al calculation.
3. [workflow.md](workflow.md) — what the two driver scripts actually do, step by step.
4. [inputs.md](inputs.md) — every variable, once you are setting up your own material.

To check a build without running QE or Yambo:

```bash
$ make && pytest test/reference
```

See [testing.md](testing.md).

---



## How the pieces fit together

Three codes each supply one ingredient, and `mantel.x` combines them:

| Ingredient | Comes from | Reaches mantel as |
|---|---|---|
| Bloch wavefunctions $u_{n\mathbf{k}}$ | QE bands run | `<wfc_dir>/ik-*.bin` via `wfc2bin.x` |
| Band energies, q-weights, cell, $E_F$ | QE XML files | `band_energies.bin`, `q_weights.bin`, `mantel.nml` via `mantel_xml.py` |
| $\epsilon^{-1}_{\mathbf{G},\mathbf{G}'}(\mathbf{q},0)$ | Yambo static RPA | `epsm1_unpadded.bin` via `prepare_yambo.py` |

`mantel.x` forms density products by FFT, contracts them with the screened Coulomb kernel,
and writes one $W$ matrix per q-point. `isoenergy.x` and `mu.x` then reduce those matrices
to the quantities you actually use.

---

## The pipeline

Everything starts from a single QE SCF input and a single `mantel.in`. Two scripts run the
rest:

```
scf.in  +  mantel.in
   │
   ├─ Stage 1 — mantel_prep.sh  (needs QE and Yambo)
   │    qe_driver.sh       pw.x scf + bands    → xml/{scf,bands}.xml, <wfc_dir>/wfc*.dat
   │    yambo_driver.sh    pw.x scf + nscf,    → xml/nscf.xml,
   │                       p2y, yambo RPA        <yambo_dir>/{SAVE,RPA}
   │
   └─ Stage 2 — mantel_run.sh  (needs the mantel binaries and yambopy)
        mantel_xml.py      → mantel.nml, band_energies.bin, q_weights.bin
        wfc2bin.x          → <wfc_dir>/ik-*.bin, G_vectors.bin, cartesian_k.bin
        prepare_yambo.py   → epsm1_unpadded.bin, yambo_qs.bin, yambo_Gs.bin
        mantel.x           → W_iq*.bin, ikp_iq*.bin, ik.bin
        isoenergy.x        → W_ee.dat, dos.dat
        mu.x               → mu.dat
```

```bash
$ mantel_gen.py -v mantel.in  # template, with every variable commented
$ mantel_prep.sh -c mantel.in -n 16
$ mantel_run.sh  -c mantel.in
```

Both stages log to `mantel_prep.log` and `mantel_run.log`, stop at the first failure, and
name the file to read. Stage 2's steps are ordinary programs that the script only
sequences, so any one of them can be rerun by hand - see
[workflow.md](workflow.md#running-the-steps-by-hand). That matters because `mantel.x` is
the expensive step, and changing a smearing or an energy grid only needs `isoenergy.x` or
`mu.x` run again.

> `make install` puts the four executables in `bin/`, alongside the scripts. **Put `bin/`
> on your `PATH`** - the scripts find each other and the binaries by name.

---

## The programs

| Program | Does | Docs |
|---|---|---|
| `wfc2bin.x` | Maps QE `wfc*.dat` onto a fixed G cube of side `2*Gmax+1` | [wfc2bin.md](wfc2bin.md) |
| `mantel.x` | Computes $W$ for every band pair and k-point, one file per q-point | [mantel.x.md](mantel.x.md) |
| `isoenergy.x` | Averages $W$ onto isoenergy surfaces, giving $W(\varepsilon,\varepsilon')$ | [isoenergy.x.md](isoenergy.x.md) |
| `mu.x` | Fermi-surface average, giving $\mu = N_F \langle\langle W \rangle\rangle_{FS}$ against smearing | [mu.x.md](mu.x.md) |

All four read `mantel.in` on **standard input** and take `-h`. All four are OpenMP-only;
set `OMP_NUM_THREADS`.

Helper scripts live in `bin/` too: `mantel_gen.py` writes an input template, `mantel_xml.py`
turns the QE XML into `mantel.nml`, `qe_input.py` derives the bands and Yambo inputs from
your SCF input, `prepare_yambo.py` exports the Yambo databases, and `plot.py` plots
`W_ee.dat` and `dos.dat`. `tools/` holds `.bin` ⇄ `.npy` converters for poking at
intermediate files.

---

## Input files

Two files configure a run, and nothing appears in both:

| File | Written by | Holds |
|---|---|---|
| `<seed>.mantel.in` | you, from `mantel_gen.py` | the choices: grids, band windows, cutoffs, smearings |
| `mantel.nml` | `mantel_xml.py`, from the QE XML | the facts: lattice vectors, `nelec`, $E_F$, k- and q-point counts |

`mantel.in` is a set of Fortran namelist blocks — `&qe`, `&yambo`, `&wfc2bin`, `&mantel`,
`&isoenergy`, `&mu` - and each program reads only the blocks it owns, so one file serves
the whole pipeline. Every variable is documented in [inputs.md](inputs.md).

Never edit `mantel.nml` by hand; regenerate it with `mantel_xml.py`.

---

## What you get out

| File | Contents |
|---|---|
| `W_iq<N>.bin` | $W$ for q-point `N`, shape (`numBands`, `numBands`, `nks`) |
| `ik.bin`, `ikp_iq<N>.bin` | k-point list, and the k′ = k+q index map per q-point |
| `W_ee.dat` | $W(\varepsilon,\varepsilon')$ on the `&isoenergy` grid — the file IsoME reads |
| `dos.dat` | Gaussian DOS on the same grid, for checking the smearing |
| `mu.dat` | $N_F$, $W(0,0)$ and $\mu$ against smearing width |

Layouts, headers and the `.bin` header format are in
[file-formats.md](file-formats.md).

---

## Document map

| Document | Covers |
|---|---|
| [installation.md](installation.md) | Dependencies, build configs, Python environment |
| [tutorial.md](tutorial.md) | The worked examples in `examples/` |
| [workflow.md](workflow.md) | `mantel_prep.sh`, `mantel_run.sh` and the helper scripts |
| [inputs.md](inputs.md) | Every `mantel.in` and `mantel.nml` variable |
| [wfc2bin.md](wfc2bin.md) | `wfc2bin.x`, and choosing `Gmax` |
| [mantel.x.md](mantel.x.md) | `mantel.x`, the $\mathbf{q}\to0$ treatment, parallelism |
| [isoenergy.x.md](isoenergy.x.md) | `isoenergy.x` and the isoenergy average |
| [mu.x.md](mu.x.md) | `mu.x`, and rescaling with an external $N_F$ |
| [file-formats.md](file-formats.md) | `.bin`, `W_ee.dat`, `dos.dat`, `mu.dat` |
| [testing.md](testing.md) | The test suite |
