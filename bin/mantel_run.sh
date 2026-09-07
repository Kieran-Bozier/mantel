#!/bin/bash
set -euo pipefail


##############################################################################################
#        This script runs the second stage of the calculation                                #
#        ---------------------------------------------------------------                     #
#         (1)    Runs mantel_xml.py to create the mantel.nml file                            #
#         (2)    Runs wfc2bin to convert QE wfc.dat files to .bin format                     #
#         (3)    Runs prepare_yambo to write yambo results in .bin format                    #
#         (4)    Runs mantel.x to compute the W_nkmp                                         #
#         (5)    Runs isoenergy.x to compute W_ee.dat                                        #
#         (6)    Runs mu.x to compute mu.dat                                                 #
##############################################################################################

# ----------   Helpers   ----------

usage() {
    echo "Usage: $0 -c [seed].mantel.in"
    echo ""
    echo "Run the full mantel workflow for a material"
    echo ""
    echo "Options:"
    echo "  -c   Input file (required), e.g. Al.mantel.in"
    echo "  -h   Show this help message"
    echo ""
    echo "Required files in the working directory:"
    echo "  <seed>.mantel.in  — mantel.x namelist input"
    echo "  <xml_dir>         - xml files from scf, bands and nscf runs"
    echo "  <wfc_dir>/        — wavefunction .dat files for wfc2bin"
    echo "  <yambo_dir>/SAVE, <yambo_dir>/RPA — Yambo dielectric data"
    exit "${1:-1}"
}

# Function to print an error message and exit
fail() {
    echo "Error: $*" >&2
    exit 1
}

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


timestamp() { 
    date +"%H:%M:%S"; 
}

#Keep track of step number and timings
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

while getopts "c:h" opt; do
    case ${opt} in
        c ) cfg_file=$OPTARG ;;
        h ) usage 0 ;;
        \? ) echo "Invalid option: -$OPTARG" >&2; usage ;;
        :  ) echo "Option -$OPTARG requires an argument." >&2; usage ;;
    esac
done

shift $((OPTIND-1))
[ $# -eq 0 ] || fail "Unexpected argument: $1"

# ----------   Load config file   ----------

[ -z "$cfg_file" ] && fail "Input file is required. Use -c <seed>.mantel.in."
[ -f "$cfg_file" ] || fail "Input file '$cfg_file' not found."

# Read from namelist blocks
yambo_dir=$(read_cfg "$cfg_file" "yambo" "yambo_dir" || true)

# Apply defaults for optional values
if [ -z "$yambo_dir" ]; then yambo_dir=YAMBO; fi

# ----------   Logging   ----------

LOG_FILE="mantel_run.log"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "[$(timestamp)] Logging to ${LOG_FILE}"

echo "========================================"
echo "  mantel_run  $(date '+%Y-%m-%d %H:%M:%S')"
echo "  config=$cfg_file"
echo "========================================"
RUN_START=$SECONDS

# ----------   Pre-flight checks   ----------
#Check the commands exist
for cmd in mantel_xml.py wfc2bin.x prepare_yambo.py mantel.x isoenergy.x mu.x; do
    command -v "$cmd" &>/dev/null || fail "'$cmd' not found in PATH."
done

#Check we are in an environment with yambopy
python3 -c "import yambopy" 2>/dev/null || fail "yambopy not found — please activate the correct conda environment first."


[ -d "${yambo_dir}/SAVE" ]        || fail "${yambo_dir}/SAVE directory not found."
[ -d "${yambo_dir}/RPA" ]         || fail "${yambo_dir}/RPA directory not found."

for f in xml/scf.xml xml/bands.xml xml/nscf.xml; do
    [ -f "$f" ] || fail "$f not found (needed by mantel_xml.py)."
done

# ----------   Pipeline   ----------

#mantel_xml
step "mantel_xml"
mantel_xml.py || fail "mantel_xml.py failed."
step_done

# wfc2bin
step "wfc2bin"
wfc2bin.x < "${cfg_file}" > "wfc2bin.out" || fail "wfc2bin failed. See wfc2bin.out"
step_done

# Prepare yambo arrays
step "prepare_yambo"
prepare_yambo.py "${yambo_dir}/SAVE" "${yambo_dir}/RPA" || fail "prepare_yambo.py failed."
step_done

# mantel.x
step "mantel.x"
mantel.x < "${cfg_file}" > "mantel.out" || fail "mantel.x failed. See mantel.out."
step_done

#isoenergy.x
step "isoenergy.x"
isoenergy.x < "${cfg_file}" > "isoenergy.out" || fail "isoenergy.x failed. See isoenergy.out"
step_done

#mu.x
step "mu.x"
mu.x < "${cfg_file}" > mu.out || fail "mu.x failed."
step_done


echo "========================================"
echo "  All steps completed.  Total: $((SECONDS - RUN_START))s"
echo "========================================"

wait