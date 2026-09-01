#!/bin/bash
set -euo pipefail

# mantel_prep.sh — Stage 1 of the mantel pipeline
# Runs QE (SCF + bands) followed by Yambo (SCF + NSCF + RPA).
# Stage 2 (wfc2bin → mantel.x → post-processing) is handled by mantel_run.sh.


# ----------   Helpers   ----------

usage() {
    echo "Usage: $0 -c [seed].mantel.in [-n num_np] [-h]"
    echo ""
    echo "Run the DFT prep stage: QE (SCF + bands) → Yambo (SCF + NSCF + RPA)."
    echo "Results are then ready for Stage 2: mantel_run.sh."
    echo ""
    echo "Options:"
    echo "  -c   Input file (required), e.g. Al.mantel.in"
    echo "  -n   MPI ranks for QE/Yambo (default: 32)"
    echo "  -h   Show this help message"
    echo ""
    echo "Template Input file can be generated with: "
    echo "\$ mantel_gen.py [seed].mantel.in"
    echo ""
    echo "Or for a Template with more details on variables:"
    echo "\$ mantel_gen.py -v [seed].mantel.in"
    exit "${1:-1}"
}

is_positive_int() {
    [[ "$1" =~ ^[1-9][0-9]*$ ]]
}

fail() {
    echo "Error: $*" >&2
    exit 1
}

timestamp() { date +"%H:%M:%S"; }

STEP=0; TOTAL=2; STEP_START=0
step() {
    STEP=$((STEP + 1))
    STEP_START=$SECONDS
    echo "[$(timestamp)] [$STEP/$TOTAL] $1"
}

step_done() {
    echo "[$(timestamp)] [$STEP/$TOTAL] done  ($((SECONDS - STEP_START))s)"
}

# Defaults
num_np=32
cfg_file=""

# Parse
while getopts "c:n:h" opt; do
    case ${opt} in
        c ) cfg_file=$OPTARG ;;
        n ) num_np=$OPTARG ;;
        h ) usage 0 ;;
        \? ) echo "Invalid option: -$OPTARG" >&2; usage ;;
        :  ) echo "Option -$OPTARG requires an argument." >&2; usage ;;
    esac
done
shift $((OPTIND-1))
[ $# -eq 0 ] || fail "Unexpected argument: $1"
is_positive_int "$num_np" || fail "-n must be a positive integer (got '$num_np')."

[ -z "$cfg_file" ] && fail "Input file is required. Use -c <seed>.mantel.in."
[ -f "$cfg_file" ] || fail "Input file '$cfg_file' not found."


for cmd in  pw.x qe_input.py p2y yambo; do
    command -v "$cmd" &>/dev/null || fail "'$cmd' not found in PATH.
Stage 1 requires Quantum ESPRESSO and Yambo - see README Dependencies."
done


for cmd in qe_driver.sh yambo_driver.sh; do
    command -v "$cmd" &>/dev/null || fail "'$cmd' not found in PATH.
Unable to find qe_driver.sh and yambo_driver.sh"
done

# ----------   Logging   ----------

LOG_FILE="mantel_prep.log"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "[$(timestamp)] Logging to ${LOG_FILE}"

echo "========================================"
echo "  mantel_prep  $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================"
RUN_START=$SECONDS


# Stage 1: QE
step "QE (SCF + bands)"
qe_driver.sh -c "$cfg_file" -n "$num_np" || fail "qe_driver.sh failed."
step_done

# Stage 2: Yambo
step "Yambo (SCF + NSCF + RPA)"
yambo_driver.sh -c "$cfg_file" -n "$num_np" || fail "yambo_driver.sh failed."
step_done

echo "========================================"
echo "  Prep complete.  Total: $((SECONDS - RUN_START))s"
echo ""
echo "  Next step — run mantel_run.sh:"
echo "    mantel_run.sh -c ${cfg_file}"
echo "========================================"

wait
