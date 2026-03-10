#!/bin/bash

##############################################################################################
#        This script runs the second stage of the calculation                                #
#        ---------------------------------------------------------------                     #Can
#         (1)    Runs wfc2bin to convert QE wfc.dat files to .bin format                     #
#         (2)    Runs prepare_yambo to write yambo results in .bin format                    #
#         (3)    Runs mantel.x to compute the W_nkmp                                         #
#         (4)    Runs bin_converter.py to convert .bin to .npy for Python post-processing    #
#         (5)    Runs W_ee.py to compute isoenergy average                                   #
#         (6)    Runs plotter.py to plot the final W_ee and DOS results                      #
##############################################################################################

# ----------   Helpers   ----------

usage() {
    echo "Usage: $0 -c <seed>.mantel.in [-s seed] [-g Gmax] [-i in_min] [-j in_max] [-y yambo_dir]"
    echo ""
    echo "Run the full mantel workflow for a material: wfc2bin -> prepare_yambo ->"
    echo "mantel.x -> bin_converter -> W_ee -> plotter."
    echo ""
    echo "Options:"
    echo "  -c   Input file (required), e.g. Al.mantel.in"
    echo "  -s   Seed name (overrides filename-derived seed)"
    echo "  -g   Max G-vector cutoff passed to wfc2bin (overrides &wfc2bin block)"
    echo "  -i   Minimum band index (overrides &mantel block)"
    echo "  -j   Maximum band index (overrides &mantel block)"
    echo "  -y   Yambo output directory (overrides &yambo block)"
    echo "  -h   Show this help message"
    echo ""
    echo "Required files in the working directory:"
    echo "  <seed>.mantel.in  — mantel.x namelist input"
    echo "  <seed>.scf.out    — QE SCF output (for Fermi energy)"
    echo "  <seed>_yambo.nscf.out, <seed>.bands.out — for W_ee.py"
    echo "  <wfc_dir>/        — wavefunction .dat files from wfc2bin"
    echo "  <yambo_dir>/SAVE, <yambo_dir>/RPA — Yambo dielectric data"
    exit 1
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
        #Remove any quotes
        sed "s/^['\"]//; s/['\"]$//" |
        #Trim trailing whitespace
        sed 's/[[:space:]]*$//'
}

is_positive_int() {
    [[ "$1" =~ ^[1-9][0-9]*$ ]]
}

timestamp() { 
    date +"%H:%M:%S"; 
}

#Keep track of steop number and timings
STEP=0; TOTAL=6; STEP_START=0
step() {
    STEP=$((STEP + 1))
    STEP_START=$SECONDS
    echo "[$(timestamp)] [$STEP/$TOTAL] $1"
}

step_done() {
    echo "[$(timestamp)] [$STEP/$TOTAL] done  ($((SECONDS - STEP_START))s)"
}

# ----------   Parse flags   ----------

cfg_file=""

while getopts "c:g:i:j:s:y:h" opt; do
    case ${opt} in
        c ) cfg_file=$OPTARG ;;
        g ) cli_Gmax=$OPTARG ;;
        i ) cli_in_min=$OPTARG ;;
        j ) cli_in_max=$OPTARG ;;
        s ) cli_seed=$OPTARG ;;
        y ) cli_yambo_dir=$OPTARG ;;
        h ) usage ;;
        \? ) echo "Invalid option: -$OPTARG" >&2; usage ;;
        :  ) echo "Option -$OPTARG requires an argument." >&2; usage ;;
    esac
done

shift $((OPTIND-1))

# ----------   Load config file   ----------

[ -z "$cfg_file" ] && fail "Input file is required. Use -c <seed>.mantel.in."
[ -f "$cfg_file" ] || fail "Input file '$cfg_file' not found."

# Derive seed from filename (e.g. Al.mantel.in → Al) unless overridden
seed="${cfg_file%%.*}"
[ -n "${cli_seed:-}" ] && seed=$cli_seed

# Read from namelist blocks
Gmax=$(read_cfg "$cfg_file" "wfc2bin" "Gmax")
in_min=$(read_cfg "$cfg_file" "mantel" "in_min")
in_max=$(read_cfg "$cfg_file" "mantel" "in_max")
yambo_dir=$(read_cfg "$cfg_file" "yambo" "yambo_dir")
wfc_dir=$(read_cfg "$cfg_file" "qe" "wfc_dir")

# Apply defaults for optional values
[ -z "$Gmax" ]      && Gmax=12
[ -z "$in_min" ]    && in_min=1
[ -z "$in_max" ]    && in_max=6
[ -z "$yambo_dir" ] && yambo_dir=YAMBO
[ -z "$wfc_dir" ]   && wfc_dir=WFC

# CLI overrides (highest priority)
[ -n "${cli_Gmax:-}" ]     && Gmax=$cli_Gmax
[ -n "${cli_in_min:-}" ]   && in_min=$cli_in_min
[ -n "${cli_in_max:-}" ]   && in_max=$cli_in_max
[ -n "${cli_yambo_dir:-}" ] && yambo_dir=$cli_yambo_dir

# ----------   Argument validation   ----------

[ -z "$seed" ] && fail "'seed' could not be derived from filename."

is_positive_int "$Gmax"   || fail "-g Gmax must be a positive integer (got '$Gmax')."
is_positive_int "$in_min" || fail "-i in_min must be a positive integer (got '$in_min')."
is_positive_int "$in_max" || fail "-j in_max must be a positive integer (got '$in_max')."
[ "$in_min" -le "$in_max" ] || fail "-i in_min ($in_min) must be <= -j in_max ($in_max)."

# ----------   Logging   ----------

LOG_FILE="${seed}_mantel.log"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "[$(timestamp)] Logging to ${LOG_FILE}"

echo "========================================"
echo "  mantel-run  $(date '+%Y-%m-%d %H:%M:%S')"
echo "  seed=$seed  Gmax=$Gmax  bands=$in_min..$in_max"
echo "  yambo_dir=$yambo_dir  wfc_dir=$wfc_dir"
echo "  config=$cfg_file"
echo "========================================"
RUN_START=$SECONDS

# ----------   Pre-flight checks   ----------
#Check the commands exist
for cmd in wfc2bin mantel.x prepare_yambo.py bin_converter.py W_ee.py plotter.py; do
    command -v "$cmd" &>/dev/null || fail "'$cmd' not found in PATH."
done

#Check we are in an environment with yambopy
python -c "import yambopy" 2>/dev/null || fail "yambopy not found — please activate the correct conda        
  environment first."


[ -d "${wfc_dir}" ]               || fail "${wfc_dir}/ directory not found."
[ -d "${yambo_dir}/SAVE" ]        || fail "${yambo_dir}/SAVE directory not found."
[ -d "${yambo_dir}/RPA" ]         || fail "${yambo_dir}/RPA directory not found."
[ -f "${seed}.mantel.in" ] || fail "${seed}.mantel.in not found."
[ -f "${seed}.scf.out" ]  || fail "${seed}.scf.out not found (needed for Fermi energy)."
[ -f "${seed}_yambo.nscf.out" ] || fail "${seed}_yambo.nscf.out not found."
[ -f "${seed}.bands.out" ]      || fail "${seed}.bands.out not found."

# ----------   Pipeline   ----------

# wfc2bin
step "wfc2bin"
cd "${wfc_dir}" || fail "Could not enter ${wfc_dir}/."
wfc2bin "${Gmax}" "${in_min}" "${in_max}" wfc*.dat || fail "wfc2bin failed."
mv G_vectors.bin ../ || fail "Could not move G_vectors.bin."
mv cartesian_k.bin ../ || fail "Could not move cartesian_k.bin."
cd ../ || fail "Could not return from ${wfc_dir}/."
step_done

# Prepare yambo arrays
step "prepare_yambo"
prepare_yambo.py "${yambo_dir}/SAVE" "${yambo_dir}/RPA" || fail "prepare_yambo.py failed."
step_done

# mantel.x
step "mantel.x"
mantel.x < "${seed}.mantel.in" > "${seed}.mantel.out" || fail "mantel.x failed. See ${seed}.mantel.out."
step_done

# Convert .bin to .npy
step "bin_converter"
[ -f "ik.bin" ] || fail "No output files from mantel.x — check ${seed}.mantel.out."
# nullglob: if a glob matches no files, bash normally passes the literal pattern
# string to the loop body. Setting nullglob makes it expand to nothing instead,
# so the loop simply doesn't run. We restore the default afterwards.
shopt -s nullglob
for i in W_iq*.bin; do
    bin_converter.py "${i}" --ord "2,0,1" > /dev/null || fail "bin_converter.py failed on ${i}."
done
for i in ikp_iq*.bin; do
    bin_converter.py "${i}" > /dev/null || fail "bin_converter.py failed on ${i}."
done
shopt -u nullglob
bin_converter.py "ik.bin" || fail "bin_converter.py failed on ik.bin."
step_done

# W_ee.py
step "W_ee"
Ef=$(grep "Fermi" "${seed}.scf.out" | awk '{print $5}')
[ -n "$Ef" ] || fail "Could not extract Fermi energy from ${seed}.scf.out."
echo "[$(timestamp)] Fermi energy: ${Ef} eV"
W_ee.py "${seed}_yambo.nscf.out" "${seed}.bands.out" "${Ef}" \
    --sigma 0.8 --numE 200 --minE "-20" --maxE 20 || fail "W_ee.py failed."
step_done

# plotter.py
step "plotter"
plotter.py W_ee_raw.npy dos_raw.npy --seed "${seed}-fortran" --emin "-20" --emax 20 \
    || fail "plotter.py failed."
step_done

echo "========================================"
echo "  All steps completed.  Total: $((SECONDS - RUN_START))s"
echo "========================================"

wait
