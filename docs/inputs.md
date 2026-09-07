# Input files

The mantel codes read two files.

| File | Written by | Hand-edited? |
|---|---|---|
| `mantel.in` | you, from a `mantel_gen.py` template | **yes** — this is where you set up a calculation |
| `mantel.nml` | `mantel_xml.py`, from the QE `.xml` output | **no** — regenerate it rather than editing it |

`mantel.in` holds the parameters you choose. `mantel.nml` holds facts recorded from the
Quantum ESPRESSO and Yambo runs — lattice vectors, electron count, Fermi energy, grid
sizes — which the codes need but which you should never have to type in yourself.

Generate a template of the first with:

```bash
$ mantel_gen.py -v mantel.in     # -v includes an explanatory comment on every variable
$ mantel_gen.py    mantel.in     # bare template, no comments
```

The second appears automatically once `mantel_run.sh` reaches its `mantel_xml.py` step,
which reads `xml/scf.xml`, `xml/bands.xml` and `xml/nscf.xml`.

Every binary takes `mantel.in` on **standard input**, so the filename is yours to choose —
`<seed>.mantel.in` is the convention used throughout these docs:

```bash
$ wfc2bin.x   < Al.mantel.in
$ mantel.x    < Al.mantel.in
$ isoenergy.x < Al.mantel.in
$ mu.x        < Al.mantel.in
```

`mantel.nml` is different: it is always read from a file of exactly that name in the
working directory.

---

## Which code reads which block

A missing block is not an error — each code falls back to the defaults below and prints a
note. A malformed block is fatal.

| Block | File | Read by |
|---|---|---|
| `&qe` | `mantel.in` | `wfc2bin.x`, `mantel.x`, `qe_driver.sh` |
| `&yambo` | `mantel.in` | `yambo_driver.sh`, `mantel_run.sh` — **no Fortran code reads this block** |
| `&wfc2bin` | `mantel.in` | `wfc2bin.x` |
| `&mantel` | `mantel.in` | `wfc2bin.x`, `mantel.x`, `isoenergy.x`, `mu.x` |
| `&isoenergy` | `mantel.in` | `isoenergy.x` |
| `&mu` | `mantel.in` | `mu.x` |
| `&structure` | `mantel.nml` | `mantel.x` |
| `&system` | `mantel.nml` | `mantel.x`, `isoenergy.x`, `mu.x` |
| `&grids` | `mantel.nml` | `wfc2bin.x` |
| `&bands` | `mantel.nml` | recorded for provenance; not currently read by any binary |
| `&provenance` | `mantel.nml` | recorded for provenance; not read |

### Reading the entries below

Each variable is marked **required** or optional:

- **required** — has no usable default. The code stops with an error if you leave it as
  the template generates it.
- optional — the default shown is fine for most runs.

Some variables use a **sentinel value**: a magic number that selects a *mode* rather than
supplying a quantity. These are called out in a quote block, because `-1` does not mean
the same thing everywhere — in `iq_max` it means "all q-points", in `nef` it disables a
correction, and in `in_max` it is an unset marker that deliberately stops the run.

---

## `mantel.in`

### `&qe`

#### `qe_kgrid`
`string` · **required** · e.g. `"6 6 6"`

Electronic $\mathbf{k}$ grid that the wavefunctions are evaluated for. `qe_driver.sh` uses
it to build the bands input. The value actually used by the run is recorded independently
in `&grids` of `mantel.nml`.

#### `nbnd`
`integer` · **required**

Number of bands used when finding the Quantum ESPRESSO wavefunctions. If you want a plot
of $W(\varepsilon,\varepsilon')$ where the energies extend above the Fermi energy, set
this larger than the QE default.

#### `wfc_dir`
`string` · optional · default `"./WFC"`

Directory holding the wavefunctions. `wfc2bin.x` reads `wfc_dir/wfc#.dat` from here and
writes `wfc_dir/ik-#.bin` back into the same directory; `mantel.x` then reads those
`ik-#.bin` files.

#### `scf_in`
`string` · **required** · default `"scf.in"`

The SCF input file. `qe_driver.sh` and `yambo_driver.sh` use it as the starting point for
the bands and NSCF inputs they generate.

---

### `&yambo`

Read only by the shell scripts. If you drive the binaries by hand, this block is inert.

#### `yambo_kgrid`
`string` · **required** · e.g. `"6 6 6"`

The set of allowed $\mathbf{q}$ scatterings.

#### `chi_bands`
`integer` · **required**

Total number of bands used for the Yambo calculation to evaluate the polarizability and
inverse dielectric. Since Yambo uses the empty-bands approach, this number should be
large — likely double the number of occupied bands.

#### `NGsBlkXs`
`integer` · **required** · units: Ry

Energy cutoff for the G-vectors used when representing the inverse dielectric
$\epsilon^{-1}_{\mathbf{G},\mathbf{G'}}(\mathbf{q})$. Typically requires much lower values
than those used in the QE `ecutwfc` — on the order of 10–25 Ry.

#### `yambo_dir`
`string` · optional · default `"./YAMBO"`

Directory where the Yambo files are stored. `mantel_run.sh` expects `yambo_dir/SAVE` and
`yambo_dir/RPA` to exist before it will start.

---

### `&wfc2bin`

#### `Gmax`
`integer` · **required**

Determines the dimensions of the grid the wavefunctions are stored on. Currently cubic
grids only: the grid size is $(2 G_\mathrm{max} + 1)$ in each direction.

---

### `&mantel`

Read by all four binaries, so a change here affects the whole pipeline.

#### `in_min`
`integer` · optional · default `1` · 1-indexed

Lower band number to evaluate $W_{n,\mathbf{k},m,\mathbf{k+q}}$ for.

#### `in_max`
`integer` · **required** · default `-1` · 1-indexed

Upper band number to evaluate $W_{n,\mathbf{k},m,\mathbf{k+q}}$ for.

> **The `-1` default is an unset marker, not "all bands".** `in_max < in_min` is a fatal
> error, so a file left as generated always stops with
> `Error: in_max ( -1 ) must be >= in_min ( 1 )`. This is deliberate — the band window is
> a physics choice with a direct cost in runtime, so there is no sensible default to guess.
> Set it explicitly. Note that this is the *opposite* convention to `iq_max` below.

#### `iq_min`
`integer` · optional · default `1`

Starting q-point index. Setting it to something other than `1` allows for restarts.

#### `iq_max`
`integer` · optional · default `-1`

Final q-point index.

> **`-1` means "all q-points".** Any other value is checked against the number of q-points
> available at runtime and must satisfy `1 <= iq_min <= iq_max <= nqs`.

#### `qtf_method`
`string` · optional · default `"fit"`

Method used to calculate the Thomas–Fermi screening wavevector $q_\mathrm{TF}$, which
handles the $\mathbf{q} \to 0$ divergence of the bare Coulomb interaction.

| Value | Method | |
|---|---|---|
| `"fit"` | Least-squares fit over the `qtf_fit_nq` smallest wavevectors | **recommended** |
| `"electrons"` | A rough $q_\mathrm{TF}$ calculated from the number of electrons | discouraged |

#### `qtf_fit_nq`
`integer` · optional · default `3`

Number of points to use when performing the least-squares fit. Only consulted when
`qtf_method = "fit"`.

---

### `&isoenergy`

Read by `isoenergy.x` only.

#### `numE`
`integer` · optional · default `200`

Number of energy points between `minE` and `maxE`. Sets the energy resolution.

#### `minE`
`real` · optional · default `-20.0` · units: eV

Lower bound of the energy grid, with respect to the Fermi energy.

#### `maxE`
`real` · optional · default `20.0` · units: eV

Upper bound of the energy grid, with respect to the Fermi energy. Must be greater than
`minE`.

#### `sigma`
`real` · optional · default `0.2` · units: eV

Width of the Gaussians used when evaluating the Dirac delta functions. Must be non-zero.

---

### `&mu`

Read by `mu.x` only. `mu.x` sweeps the smearing width rather than using a single value,
so the first three variables define that sweep.

#### `min_sigma`
`real` · optional · default `0.01` · units: eV

Lower bound of the Gaussian width. Must be positive.

#### `max_sigma`
`real` · optional · default `1.0` · units: eV

Upper bound of the Gaussian width. Must be greater than or equal to `min_sigma`.

#### `num_sigma`
`integer` · optional · default `100`

Number of smearings in the sweep. Must be at least 2.

#### `nef`
`real` · optional · default `-1.0` · units: states/eV/spin

Density of states at the Fermi energy, $N_F$. Because Gaussian smearing often gets $N_F$
incorrect, you can pass in a value from an external high-quality calculation — for example
a tetrahedral DOS calculation — and `mu.x` will emit a rescaled $\mu$ alongside the
Gaussian one.

> **`-1.0` disables the correction**, leaving the rescaled $\mu$ column set to `-1`.

Watch the units: a QE `.dos.dat` file is typically states/eV, so it needs halving before
it goes in here.

---

## `mantel.nml`

Generated by `mantel_xml.py` from the files in `./xml`. You should not need to edit it —
if a value looks wrong, fix the QE input and regenerate. It is always read from a file
named exactly `mantel.nml` in the working directory.

### `&structure`

Read by `mantel.x`.

| Field | Type | Meaning |
|---|---|---|
| `alat` | real | Quantum ESPRESSO `alat` parameter |
| `volume` | real | Unit cell volume. Must be positive |
| `cell_a1_au` | real(3) | Lattice vector $\mathbf{a}_1$, in bohr |
| `cell_a2_au` | real(3) | Lattice vector $\mathbf{a}_2$, in bohr |
| `cell_a3_au` | real(3) | Lattice vector $\mathbf{a}_3$, in bohr |

### `&system`

Read by `mantel.x`, `isoenergy.x` and `mu.x`.

| Field | Type | Meaning |
|---|---|---|
| `prefix` | string | Quantum ESPRESSO calculation prefix |
| `nelec` | integer | Number of electrons. Must be positive |
| `scf_fermi` | real | Fermi energy in eV, read from the SCF output |

### `&bands`

Recorded for provenance; not currently read by any binary.

| Field | Type | Meaning |
|---|---|---|
| `bands_nbnd` | integer | Bands used when finding the QE wavefunctions — the `&qe` `nbnd` the run actually used |
| `chi_nbnd` | integer | Bands used by Yambo for the polarizability and inverse dielectric — the `&yambo` `chi_bands` the run actually used |

### `&grids`

Read by `wfc2bin.x`, which uses `nks`.

| Field | Type | Meaning |
|---|---|---|
| `qe_kgrid` | string | Electronic $\mathbf{k}$ grid the wavefunctions were evaluated for |
| `yambo_qgrid` | string | Set of allowed $\mathbf{q}$ scatterings, taking initial state $\mathbf{k}, n$ to final state $\mathbf{k+q}, m$ |
| `nks` | integer | Number of points in the $\mathbf{k}$ grid. Must be non-zero |
| `nqs` | integer | Number of points in the $\mathbf{q}$ grid. Must be non-zero |

### `&provenance`

Recorded for provenance; not read.

| Field | Type | Meaning |
|---|---|---|
| `source_scf` | string | Path to the SCF `.xml` |
| `source_bands` | string | Path to the bands `.xml` — the calculation the wavefunctions came from |
| `source_nscf` | string | Path to the NSCF `.xml` — the calculation Yambo used for the inverse dielectric |
| `generated` | string | Timestamp the file was written |
