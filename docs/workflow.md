# Workflow

Two scripts run the whole calculation from a QE SCF input, both driven by the same
`mantel.in`. They live in `bin/`, alongside the four executables `make install` puts
there — **put `bin/` on your `PATH` first**, since the scripts find each other and the
binaries by name.

```
scf.in, mantel.in
  │
  ├─ mantel_prep.sh ──┬─ qe_driver.sh       pw.x scf + bands  → xml/{scf,bands}.xml, <wfc_dir>/wfc*.dat
  │                   └─ yambo_driver.sh    pw.x scf + nscf,  → xml/nscf.xml,
  │                                         p2y, yambo RPA      <yambo_dir>/{SAVE,RPA}
  │
  └─ mantel_run.sh ───┬─ mantel_xml.py      → mantel.nml, band_energies.bin, q_weights.bin
                      ├─ wfc2bin.x          → <wfc_dir>/ik-*.bin, G_vectors.bin, cartesian_k.bin
                      ├─ prepare_yambo.py   → epsm1_unpadded.bin, yambo_qs.bin, yambo_Gs.bin
                      ├─ mantel.x           → W_iq*.bin, ikp_iq*.bin, ik.bin
                      ├─ isoenergy.x        → W_ee.dat, dos.dat
                      └─ mu.x               → mu.dat
```

Stage 1 needs Quantum ESPRESSO and Yambo on `PATH`. Stage 2 needs the mantel binaries and
a Python environment with `yambopy`.

---

## Stage 1 — `mantel_prep.sh`

```bash
$ mantel_prep.sh -c mantel.in -n 16
```

| Flag | Default | Description |
|---|---|---|
| `-c` | — | **Required.** The `mantel.in` file |
| `-n` | 32 | MPI ranks for QE and Yambo |
| `-h` | — | Help |

Everything else comes from the input file — there are no per-parameter overrides. Output
is appended to `mantel_prep.log`. The `mantel_prep.sh` script calls two lower level scripts: 
`qe_driver.sh` and `yambo_driver.sh`

### `qe_driver.sh` — wavefunctions

Reads `scf_in`, `qe_kgrid`, `nbnd` and `wfc_dir` from `&qe`, then:

1. `qe_input.py` builds `bands.in` from your SCF input at the requested grid and band count.
2. `pw.x` runs the SCF, checked for `JOB DONE.`; the XML is copied to `xml/scf.xml`.
3. `pw.x` runs the bands calculation; its XML becomes `xml/bands.xml`.
4. The QE save directory is rsynced into `<wfc_dir>`, dropping `charge-density.dat` and
   the pseudopotentials.

`outdir` and `prefix` are read out of the SCF input, so mantel finds the save directory
wherever QE put it.

### `yambo_driver.sh` — inverse dielectric

Reads `yambo_kgrid`, `chi_bands`, `NGsBlkXs` and `yambo_dir` from `&yambo` — the first
three are mandatory and the script stops if any is unset. Then:

1. `qe_input.py` builds `yambo.scf.in` and `yambo.nscf.in` (the NSCF on the Yambo grid,
   with `chi_bands` bands).
2. Both run under `pw.x`; the NSCF XML becomes `xml/nscf.xml`.
3. `p2y` converts the save directory, and `SAVE` is moved to `<yambo_dir>/SAVE`.
4. A static-RPA `yambo_RPA.in` is generated and run as `yambo -J RPA`, checked for an
   `ndb.em1s` database in `<yambo_dir>/RPA`.

> **The QE `outdir` is deleted at the end of this stage.** Everything later stages need has
> been copied into `xml/`, `<wfc_dir>` and `<yambo_dir>` by that point, but any other QE
> output you wanted from `outdir` will be gone.

---

## Stage 2 — `mantel_run.sh`

```bash
$ mantel_run.sh -c mantel.in
```

Only `-c` and `-h`. Threading is by environment variable, not by flag:

```bash
$ OMP_NUM_THREADS=16 mantel_run.sh -c mantel.in
```

Before starting it checks that the executables are on `PATH`, that `yambopy` imports, that
`<yambo_dir>/SAVE` and `<yambo_dir>/RPA` exist, and that all three `xml/*.xml` files are
present. Output is appended to `mantel_run.log`.

| # | Step | Produces | Log |
|---|---|---|---|
| 1 | `mantel_xml.py` | `mantel.nml`, `band_energies.bin`, `q_weights.bin` | `mantel_run.log` |
| 2 | `wfc2bin.x` | `<wfc_dir>/ik-*.bin`, `G_vectors.bin`, `cartesian_k.bin` | `wfc2bin.out` |
| 3 | `prepare_yambo.py` | `epsm1_unpadded.bin`, `yambo_qs.bin`, `yambo_Gs.bin` | `mantel_run.log` |
| 4 | `mantel.x` | `W_iq*.bin`, `ikp_iq*.bin`, `ik.bin` | `mantel.out` |
| 5 | `isoenergy.x` | `W_ee.dat`, `dos.dat` | `isoenergy.out` |
| 6 | `mu.x` | `mu.dat` | `mu.out` |

Each step is timed and the script stops at the first failure, naming the log to read.


---

## Running the steps by hand

The stage-2 steps are independent programs; the script only sequences them. To rerun one:

```bash
$ mantel_xml.py                                 # reads xml/{scf,bands,nscf}.xml
$ wfc2bin.x       < mantel.in > wfc2bin.out
$ prepare_yambo.py YAMBO/SAVE YAMBO/RPA
$ mantel.x        < mantel.in > mantel.out
$ isoenergy.x     < mantel.in > isoenergy.out
$ mu.x            < mantel.in > mu.out
```

This is worth knowing because the expensive step is `mantel.x`. Changing `numE` or `sigma`
only needs `isoenergy.x` rerun; changing `min_sigma` or `nef` only needs `mu.x`. Neither
touches `W_iq*.bin`.

`mantel.x` itself can be restarted mid-run by setting `iq_min`, since it writes each
q-point's output as that q-point completes.

---

## Helper scripts

| Script | Usage |
|---|---|
| `mantel_gen.py` | `mantel_gen.py [-v] <out>.mantel.in` — writes a template; `-v` annotates every variable |
| `mantel_xml.py` | `mantel_xml.py [--scf F] [--bands F] [--nscf F]` — defaults to `xml/{scf,bands,nscf}.xml` |
| `qe_input.py` | `qe_input.py <in> <out> --mode {bands,scf-yambo,nscf-yambo} [--nbnd N] [--kgrid "N N N"]` |
| `prepare_yambo.py` | `prepare_yambo.py <SAVE dir> <RPA job dir>` |

`qe_input.py` derives every QE input from your original SCF file, so the calculations stay
consistent with each other — edit `scf.in` rather than the generated `bands.in`,
`yambo.scf.in` or `yambo.nscf.in`, which are overwritten on each run.
