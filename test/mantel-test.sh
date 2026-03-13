#!/bin/bash
set -euo pipefail

# This script creates a set of test data that mantel
# can then be run on.
run_mantel=1

# Always run relative to the test/ directory so artifacts land there
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR" || { echo "Error: could not cd to ${SCRIPT_DIR}"; exit 1; }

# =============================================================================
# User configuration — edit these two variables before running
# =============================================================================

# PSEUDO_DIR: path to your pseudopotential files (used by Quantum ESPRESSO).
# These are not included in the repository; download them separately, e.g.
# from https://www.pseudo-dojo.org/
#
# You can override this without editing the script by setting the variable
# in your environment before running:
#   PSEUDO_DIR=/my/pseudos test/skydd-test.sh
# (syntax: ${VAR:-default} uses VAR if set in the environment, else default)
PSEUDO_DIR="${PSEUDO_DIR:./pseudopotentials/pseudo-dojo-LDA/}"

# SCRATCH_DIR: fast temporary directory for Quantum ESPRESSO output files
# (wavefunctions, charge densities). These files are large and temporary —
# they are only needed until wfc2bin has converted them, after which they
# can be safely deleted.
#
# Good choices:
#   /dev/shm        — RAM-backed tmpfs on Linux (fastest, wiped on reboot)
#   $TMPDIR         — system temp dir (set automatically on many HPC clusters)
#   /scratch/...    — fast parallel filesystem on HPC clusters
#   /tmp            — safe fallback, but slower
#
# Default is /tmp. For best performance, set this to /dev/shm (Linux) or
# your HPC scratch filesystem.
SCRATCH_DIR="${SCRATCH_DIR:-/dev/shm}"

# =============================================================================

usage() {
    echo "Usage: $0 [-f] [-h]"
    echo ""
    echo "This script creates a set of test data that mantel can then be run on."
    echo "Options:"
    echo "  -f   Only create files, do not run mantel"
    echo "  -h   Show this help message"
    exit 1
}

# Parse command-line options
while getopts "fh" opt; do
    case ${opt} in
        f )
            run_mantel=0
            ;;
        h )
            usage
            ;;
        \? )
            echo "Invalid option: -$OPTARG" >&2
            usage
            ;;
        : )
            echo "Option -$OPTARG requires an argument." >&2
            usage
            ;;
    esac
done
shift $((OPTIND-1))

fail() { 
  echo "Error: $*" >&2; exit 1; 
}

# -------------     Aluminium example    -----------------
mkdir -p Al

cat > Al/Al.scf.in << EOF
&CONTROL
  calculation='scf'
  restart_mode='from_scratch'
  prefix='Al'
  pseudo_dir='${PSEUDO_DIR}'
  outdir='${SCRATCH_DIR}/Al'
/

&SYSTEM
  ibrav=0,
  nbnd=10
  nat=1,
  ntyp=1,
  nspin=1
  ecutwfc = 50,
  occupations = 'smearing',
  smearing = 'mp',
  degauss = 0.025
/

&ELECTRONS
  conv_thr = 1.0d-10
  mixing_beta = 0.7
/
ATOMIC_SPECIES
 Al  26.9815386 Al.upf

CELL_PARAMETERS (angstrom)
  -2.005927973   0.000000000   2.005927973
  -0.000000000   2.005927973   2.005927973
  -2.005927973   2.005927973   0.000000000

ATOMIC_POSITIONS {crystal}
Al            0.0000000000        0.0000000000        0.0000000000

K_POINTS automatic
  6 6 6  0  0  0
EOF

cat > Al/Al.mantel.in << EOF
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
EOF



# --------------  Niobium example   -----------------
mkdir -p Nb
cat > Nb/Nb.scf.in << EOF
&CONTROL
  calculation='scf'
  restart_mode='from_scratch'
  prefix='Nb'
  pseudo_dir='${PSEUDO_DIR}'
  outdir='${SCRATCH_DIR}/Nb'
  verbosity='high'
/

&SYSTEM
  nbnd=20
  ibrav=0,
  nat=1,
  ntyp=1,
  nspin=1
  ecutwfc = 100,
  occupations = 'smearing',
  smearing = 'mp',
  degauss = 0.025
/

&ELECTRONS
  conv_thr = 1.0d-10
  mixing_beta = 0.7
/
ATOMIC_SPECIES
 Nb  92.90638 Nb.upf

CELL_PARAMETERS (angstrom)
   1.655821841   1.655821841   1.655821841
  -1.655821841   1.655821841   1.655821841
  -1.655821841  -1.655821841   1.655821841

ATOMIC_POSITIONS {crystal}
Nb            0.0000000000        0.0000000000        0.0000000000

K_POINTS automatic
  6  6  6  0  0  0
EOF

cat > Nb/Nb.mantel.in << EOF
&qe
   qe_kgrid = "6 6 6"
   nbnd     = 20
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
   num_electrons = 13
   in_min        = 1
   in_max        = 20
/

CELL_PARAMETERS angstrom
   1.655821841   1.655821841   1.655821841
  -1.655821841   1.655821841   1.655821841
  -1.655821841  -1.655821841   1.655821841
EOF



# --------------    Tantalum example   -----------------
mkdir -p Ta
cat > Ta/Ta.scf.in << EOF
&CONTROL
  calculation='scf'
  restart_mode='from_scratch'
  prefix='Ta'
  pseudo_dir='${PSEUDO_DIR}'
  outdir='${SCRATCH_DIR}/Ta'
/
&SYSTEM
  ibrav=0,
  nbnd=20
  nat=1,
  ntyp=1,
  nspin=1
  ecutwfc = 100,
  occupations = 'smearing',
  smearing = 'mp',
  degauss = 0.025
  la2F = .true.
/
&ELECTRONS
  conv_thr = 1.0d-10
  mixing_beta = 0.7
/
ATOMIC_SPECIES
 Ta  180.94788 Ta.upf

CELL_PARAMETERS angstrom
  -1.622772917   1.622772917   1.622772917
   1.622772917  -1.622772917   1.622772917
   1.622772917   1.622772917  -1.622772917

ATOMIC_POSITIONS crystal
Ta            0.0000000000        0.0000000000        0.0000000000

K_POINTS automatic
  6  6  6  0  0  0
EOF

cat > Ta/Ta.mantel.in << EOF
&qe
   qe_kgrid = "6 6 6"
   nbnd     = 20
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
   num_electrons = 13
   in_min        = 1
   in_max        = 20
/

CELL_PARAMETERS angstrom
  -1.622772917   1.622772917   1.622772917
   1.622772917  -1.622772917   1.622772917
   1.622772917   1.622772917  -1.622772917
EOF



# --------------   H3S example   -----------------
mkdir -p H3S
cat > H3S/H3S.scf.in << EOF
&CONTROL
  calculation='scf'
  restart_mode='from_scratch'
  prefix='H3S'
  pseudo_dir='${PSEUDO_DIR}'
  outdir='${SCRATCH_DIR}/H3S'
  tstress=.true.
  tprnfor=.true.
/

&SYSTEM
  ibrav=0,
  nat=8,
  ntyp=2,
  nspin=1
  ecutwfc = 100,
  occupations = 'smearing'
  smearing = 'mp'
  degauss = 0.025
/

&ELECTRONS
  conv_thr = 1.0d-10
  mixing_beta = 0.7
/

ATOMIC_SPECIES
S    32.07    S.upf
H    1.008    H.upf

CELL_PARAMETERS angstrom
   2.984151747   0.000000000   0.000000000
   0.000000000   2.984151747   0.000000000
   0.000000000   0.000000000   2.984151747

ATOMIC_POSITIONS crystal
S             0.0000000000        0.0000000000        0.0000000000
S             0.5000000000        0.5000000000        0.5000000000
H             0.5000000000        0.0000000000        0.0000000000
H             0.0000000000        0.5000000000        0.0000000000
H             0.5000000000        0.5000000000        0.0000000000
H             0.0000000000        0.0000000000        0.5000000000
H             0.5000000000        0.0000000000        0.5000000000
H             0.0000000000        0.5000000000        0.5000000000

K_POINTS automatic
  6  6  6  0  0  0
EOF

cat > H3S/H3S.mantel.in << EOF
&qe
   qe_kgrid = "6 6 6"
   nbnd     = 20
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
   num_electrons = 18
   in_min        = 1
   in_max        = 20
/

CELL_PARAMETERS angstrom
   2.984151747   0.000000000   0.000000000
   0.000000000   2.984151747   0.000000000
   0.000000000   0.000000000   2.984151747
EOF




#####       Now run
# Check required executables are available before attempting to run
if [ $run_mantel -eq 1 ]; then
    command -v mantel-prep.sh &>/dev/null || fail "'mantel-prep.sh' not found in PATH."
    command -v mantel-run.sh  &>/dev/null || fail "'mantel-run.sh' not found in PATH."
fi

#Check we are in an environment with yambopy
python -c "import yambopy" 2>/dev/null || fail "yambopy not found — please activate the correct conda        
  environment first."


if [ $run_mantel -eq 1 ]; then
    echo "Running mantel on test data..."
    #------------- Aluminium --------------
    cd Al || { echo "Error: could not enter Al/"; exit 1; }
    mantel-prep.sh -c Al.mantel.in
    mantel-run.sh -c Al.mantel.in
    cd ../
    echo "Aluminium done."

    #------------- Niobium --------------
    cd Nb || { echo "Error: could not enter Nb/"; exit 1; }
    mantel-prep.sh -c Nb.mantel.in
    mantel-run.sh -c Nb.mantel.in
    cd ../
    echo "Niobium done."

    #------------- Tantalum --------------
    cd Ta || { echo "Error: could not enter Ta/"; exit 1; }
    mantel-prep.sh -c Ta.mantel.in
    mantel-run.sh -c Ta.mantel.in
    cd ../
    echo "Tantalum done."

    #------------- H3S --------------
    cd H3S || { echo "Error: could not enter H3S/"; exit 1; }
    mantel-prep.sh -c H3S.mantel.in
    mantel-run.sh -c H3S.mantel.in
    cd ../
    echo "H3S done"

    echo "Done."
else
    echo "Test data created. Not running mantel as per user request."
fi
