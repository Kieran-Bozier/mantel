# Testing

Two pytest suites check a build without needing Quantum ESPRESSO or Yambo. From the
repository root:

```bash
$ make
$ pytest test/reference test/unit/python
```

Both need `numpy` and `pytest`, which the `mantel` conda environment from
[installation.md](installation.md) provides. CI runs both suites on Linux and macOS.

---

## Unit tests

`test/unit/python` checks the Python helper scripts in `bin/` and needs no compiled code.

| File | Checks |
|---|---|
| `test_mantel_gen.py` | the `mantel.in` template written by `mantel_gen.py` |
| `test_mantel_xml.py` | reading the QE XML files, and writing the `.bin` files and `mantel.nml` |
| `test_qe_input.py` | deriving the bands and Yambo inputs from an SCF input |

---

## Reference tests

`test/reference` runs `wfc2bin.x`, `mantel.x` and `isoenergy.x` on a small, frozen
aluminium calculation (2×2×2 grids, 10 bands, `Gmax = 5`) and compares what each one
writes against a stored snapshot in `test/reference/data/`. Each binary starts from the
previous stage's snapshot rather than a fresh run, so a failure points at one binary.

| Binary | Compared against its snapshot |
|---|---|
| `wfc2bin.x` | bit for bit, since it does no arithmetic |
| `mantel.x` | to a relative tolerance of 1e-8 |
| `isoenergy.x` | to a relative tolerance of 1e-8, plus a check that $W(\varepsilon,\varepsilon')$ is symmetric |

`mantel.x` and `isoenergy.x` use FFTs and BLAS, so their last few digits change with
the thread count and between FFTW and MKL. The tolerance allows for that; a failure
means the output has moved by more than rounding explains.

> The tests look for the binaries in `build/`, then `bin/`. If one is missing, its tests
> are **skipped**, not failed: pytest reports `4 skipped` instead of `4 passed`. Check
> the summary line, and run `make` first.

`mu.x` has no reference test.

---

## End-to-end runs

The full pipeline, including the Quantum ESPRESSO and Yambo steps, is tested by running
a tutorial. Each tutorial in `examples/` has a `full_run/` directory with the inputs and
a `reference/` directory with outputs to compare against. See [tutorial.md](tutorial.md).
