#!/bin/bash
set -euo pipefail

# yambo_driver.sh
# Runs the Yambo part of the calculation

# ---- 1. Default parameters ----
mpinp=32           # Default MPI cores


usage() {
    echo "Usage: $0 -c [seed].mantel.in"
    echo ""
    echo "Options:"
    echo "  -c   Input file (required), e.g. Al.mantel.in"
    echo "  -n   MPI ranks for QE (default: 32)"
    echo "  -h   Show this help message"
    echo ""
    exit "${1:-1}"
}


# Function to print an error message and exit
fail() {
    echo "Error: $*" >&2
    exit 1
}

# Read a key from a named namelist block in a file.
# Handles: whitespace around =, surrounding quotes.
# If a key appears multiple times within the block, the last occurrence wins.
read_cfg() {
    local file="$1" block="$2" key="$3"
    # Use awk to extract lines between &block and next /
    awk "/^[[:space:]]*&${block}[[:space:]]*(![^)]*)?$/,/^[[:space:]]*\//" "$file" |
        grep -E "^[[:space:]]*${key}[[:space:]]*=" |
        tail -1 |
        #Remove stuff up to and including =
        sed 's/^[^=]*=[[:space:]]*//' |
        #Remove any inline comment
        sed 's/[[:space:]]*!.*$//' |
        #Remove any trailing namelist comma
        sed 's/[[:space:]]*,[[:space:]]*$//' |
        #Trim trailing whitespace
        sed 's/[[:space:]]*$//' |
        #Remove any quotes
        sed "s/^['\"]//; s/['\"]$//"
}

# --- Safe rm function ---
safe_rm_outdir() {
  local dir="$1"

  # Resolve to an absolute path
  local canon
  canon="$(readlink -f "$dir" 2>/dev/null)" || canon=""

  # Refuse to delete anything dangerous
  case "$canon" in
    ""|/|/home|"$HOME"|/tmp|/etc|/usr|/var)
      echo "ERROR: refusing to delete '${canon}'" >&2
      return 1 ;;
  esac

  # Refuse if we're sitting inside it
  local cwd
  cwd="$(readlink -f .)"
  if [ "$cwd" = "$canon" ]; then
    echo "ERROR: outdir is the working directory" >&2
    return 1
  fi

  rm -rf "$canon"
}

cfg_file=""
while getopts "c:n:h" opt; do
    case ${opt} in
        c ) cfg_file=$OPTARG ;;
        n ) mpinp=$OPTARG ;; 
        h ) usage 0 ;;
        \? ) echo "Invalid option: -$OPTARG" >&2; usage ;;
        :  ) echo "Option -$OPTARG requires an argument." >&2; usage ;;
    esac
done
shift $((OPTIND-1))
[ $# -eq 0 ] || fail "Unexpected argument: $1"
[ -z "$cfg_file" ] && fail "Input file is required. Use -c <file>.mantel.in."
[ -f "$cfg_file" ] || fail "Input file '$cfg_file' not found."


# Read in the mantel.in values
yambo_kgrid=$(read_cfg "$cfg_file" yambo yambo_kgrid || true)
chi_bands=$(read_cfg   "$cfg_file" yambo chi_bands   || true)
ngsblk=$(read_cfg      "$cfg_file" yambo NGsBlkXs    || true)
yambo_dir=$(read_cfg   "$cfg_file" yambo yambo_dir   || true)
scf_in=$(read_cfg      "$cfg_file" qe    scf_in      || true)

# Check and validate input
if [ -z "$yambo_dir" ]; then yambo_dir=YAMBO; fi


[ -z "$scf_in" ]      && fail "'scf_in' not set in &qe block of $cfg_file."
[ -f "${scf_in}" ] || fail "SCF input ${scf_in} not found."

[ -z "$chi_bands" ]   && fail "'chi_bands' not set in &yambo block of $cfg_file."
[ -z "$ngsblk" ]      && fail "'NGsBlkXs' not set in &yambo block of $cfg_file."
[ -z "$yambo_kgrid" ] && fail "'yambo_kgrid' not set in &yambo block of $cfg_file."


# Outdir can be empty - if so, default to current directory. Otherwise, extract the value from the scf input file.
outdir=$(grep -E "^[[:space:]]*outdir[[:space:]]*=" "$scf_in" | head -1 | awk -F"=" '{gsub(/[" \047,]/,"",$2); print $2}' || true)
outdir="${outdir:-.}"
outdir="$(readlink -f "$outdir")" 
prefix=$(grep -E "^[[:space:]]*prefix[[:space:]]*=" "$scf_in" | head -1 | awk -F"=" '{gsub(/[" \047,]/,"",$2); print $2}' || true)
[ -z "$prefix" ] && fail "could not read prefix from $scf_in"
workdir=$(pwd)

# Check commands
for cmd in pw.x mpirun p2y yambo qe_input.py; do
    command -v "$cmd" >/dev/null || fail "'$cmd' not found in PATH. ..."
done



t_start=$SECONDS

log() { echo "[$(date '+%H:%M:%S')] $*"; }

# ---- 5. Confirmation ----
echo "Configuration:"
echo "----------------------------"
echo "  Cores       :      $mpinp"
echo "  Chi_bands   :      $chi_bands"
echo "  NGsBlk      :      $ngsblk"
echo "  Yambo_dir   :      $yambo_dir"
echo "  Yambo kgrid :      $yambo_kgrid"
echo "----------------------------"

#Build the yambo scf
qe_input.py "$scf_in" yambo.scf.in  --mode scf-yambo  --nbnd "$chi_bands" 
qe_input.py "$scf_in" yambo.nscf.in --mode nscf-yambo --nbnd "$chi_bands" --kgrid "$yambo_kgrid"


build_yambo_in(){
    local actual_nbnd=$1
    local actual_ngsblk=$2

    cat > yambo_RPA.in << EOL          
#                         YAMBO                                             
#                                                                     
# Version 5.2.3 Revision 22799 Hash (prev commit) bad66dc080          
#                      Branch is (HEAD                                
#                   MPI+HDF5_MPI_IO Build                             
#                 http://www.yambo-code.eu                            
#
screen                           # [R] Inverse Dielectric/Response Matrix
em1s                             # [R][Xs] Statically Screened Interaction
dipoles                          # [R] Oscillator strenghts (or dipoles)
Chimod= "HARTREE"                # [X] IP/Hartree/ALDA/LRC/PF/BSfxc
% BndsRnXs
   1 | ${actual_nbnd} |                         # [Xs] Polarization function bands
%
NGsBlkXs= ${actual_ngsblk}                Ry    # [Xs] Response block size
% LongDrXs
 1.000000 | 1.000000 | 1.000000 |        # [Xs] [cc] Electric Field
%
EOL

    echo "Written yambo_RPA.in for Yambo calculation"
}


# Build the yambo scf file
log "Starting Yambo SCF calculation..."
mpirun -n ${mpinp} pw.x < yambo.scf.in > yambo.scf.out
grep -q "JOB DONE." yambo.scf.out || { echo "Error: SCF calculation failed"; exit 1; }
log "SCF calculation completed."

# Build the nscf file
log "Starting Yambo NSCF calculation..."
mpirun -n ${mpinp} pw.x < yambo.nscf.in > yambo.nscf.out
grep -q "JOB DONE." "yambo.nscf.out" || { echo "Error: NSCF calculation failed"; exit 1; }
mkdir -p "${workdir}/xml"
cp "${outdir}/${prefix}.save/data-file-schema.xml" "${workdir}/xml/nscf.xml"
log "NSCF calculation completed."


mkdir -p "${yambo_dir}"
cd "$outdir/${prefix}.save/"

log "Initializing Yambo..."
p2y || { echo "Error: p2y conversion failed"; exit 1; }
[ -d "SAVE" ] || { echo "Error: p2y did not produce SAVE directory"; exit 1; }
mv SAVE "${workdir}/${yambo_dir}/SAVE"
cd "${workdir}/${yambo_dir}"

log "Running Yambo..."
yambo || { echo "Error: yambo setup failed"; exit 1; }

build_yambo_in "$chi_bands" "$ngsblk"
log "Running Yambo RPA screening..."
mpirun -n ${mpinp} yambo -Input yambo_RPA.in -J RPA
ls RPA/ndb.em1s* >/dev/null 2>&1 || { echo "Error: Yambo RPA produced no ndb.em1s database"; exit 1; }


#Ensure outdir is removed to remove confusion for later steps

safe_rm_outdir "$outdir" || log "WARNING: outdir cleanup skipped"

log "Yambo calculation completed. Total elapsed: $(( SECONDS - t_start ))s"