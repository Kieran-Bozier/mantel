#!/bin/bash

# mantel-prep.sh — Stage 1 of the mantel pipeline
# Runs QE (SCF + bands) followed by Yambo (SCF + NSCF + RPA).
# Stage 2 (wfc2bin → mantel.x → post-processing) is handled by mantel-run.sh.
#
# Reads parameters from a unified <seed>.mantel.in file with four namelist blocks:
#   &qe       — qe_kgrid, nbnd, wfc_dir
#   &yambo    — yambo_kgrid, chi_bands, NGsBlkXs, yambo_dir
#   &wfc2bin  — Gmax
#   &mantel   — in_min, in_max (shared with mantel.x)

# ----------   Helpers   ----------

usage() {
    echo "Usage: $0 -c <seed>.mantel.in [-n num_np] [overrides: -s -q -y -b -B -g -i -j -G]"
    echo ""
    echo "Run the DFT prep stage: QE (SCF + bands) → Yambo (SCF + NSCF + RPA)."
    echo "Results are then ready for Stage 2: mantel-run.sh."
    echo ""
    echo "Options:"
    echo "  -c   Input file (required), e.g. Al.mantel.in"
    echo "  -n   MPI ranks for QE/Yambo (default: 32)"
    echo "  -s   Seed name (overrides filename-derived seed)"
    echo "  -q   QE k-grid, e.g. '8 8 8' (overrides &qe block)"
    echo "  -b   QE nbnd (overrides &qe block)"
    echo "  -y   Yambo k-grid, e.g. '6 6 6' (overrides &yambo block)"
    echo "  -B   chi_bands for Yambo (overrides &yambo block)"
    echo "  -G   NGsBlkXs in Ry (overrides &yambo block)"
    echo "  -g   Gmax cutoff for mantel-run (overrides &wfc2bin block)"
    echo "  -i   in_min (overrides &mantel block)"
    echo "  -j   in_max (overrides &mantel block)"
    echo "  -h   Show this help message"
    echo ""
    echo "Input file format (four namelist blocks):"
    echo "  &qe"
    echo "     qe_kgrid = \"8 8 8\""
    echo "     nbnd     = 30"
    echo "     wfc_dir  = \"WFC\""
    echo "  /"
    echo "  &yambo"
    echo "     yambo_kgrid = \"6 6 6\""
    echo "     chi_bands   = 30"
    echo "     NGsBlkXs    = 25"
    echo "     yambo_dir   = \"YAMBO\""
    echo "  /"
    echo "  &wfc2bin"
    echo "     Gmax = 12"
    echo "  /"
    echo "  &mantel"
    echo "     num_electrons = 3"
    echo "     in_min        = 1"
    echo "     in_max        = 10"
    echo "  /"
    exit 1
}

fail() {
    echo "Error: $*" >&2
    exit 1
}

timestamp() { date +"%H:%M:%S"; }

# Read a key from a named namelist block in a file.
# Handles: whitespace around =, surrounding quotes.
# If a key appears multiple times within the block, the last occurrence wins.
read_cfg() {
    local file="$1" block="$2" key="$3"
    awk "/^[[:space:]]*&${block}[[:space:]]*(![^)]*)?$/,/^[[:space:]]*\//" "$file" \
        | grep -E "^[[:space:]]*${key}[[:space:]]*=" \
        | tail -1 \
        | sed 's/^[^=]*=[[:space:]]*//' \
        | sed "s/^['\"]//; s/['\"]$//" \
        | sed 's/[[:space:]]*$//'
}

is_positive_int() {
    [[ "$1" =~ ^[1-9][0-9]*$ ]]
}

STEP=0; TOTAL=2; STEP_START=0
step() {
    STEP=$((STEP + 1))
    STEP_START=$SECONDS
    echo "[$(timestamp)] [$STEP/$TOTAL] $1"
}

step_done() {
    echo "[$(timestamp)] [$STEP/$TOTAL] done  ($((SECONDS - STEP_START))s)"
}

# ----------   Defaults   ----------

num_np=32
cfg_file=""

# ----------   Parse flags   ----------

while getopts "c:n:s:q:b:y:B:G:g:i:j:h" opt; do
    case ${opt} in
        c ) cfg_file=$OPTARG ;;
        n ) num_np=$OPTARG ;;
        s ) cli_seed=$OPTARG ;;
        q ) cli_qe_kgrid=$OPTARG ;;
        b ) cli_nbnd=$OPTARG ;;
        y ) cli_yambo_kgrid=$OPTARG ;;
        B ) cli_chi_bands=$OPTARG ;;
        G ) cli_ngsblk=$OPTARG ;;
        g ) cli_Gmax=$OPTARG ;;
        i ) cli_in_min=$OPTARG ;;
        j ) cli_in_max=$OPTARG ;;
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
seed="$(basename "${cfg_file}")"
seed="${seed%%.*}"
[ -n "${cli_seed:-}" ] && seed=$cli_seed

# Read from namelist blocks
qe_kgrid=$(read_cfg "$cfg_file" "qe" "qe_kgrid")
nbnd=$(read_cfg "$cfg_file" "qe" "nbnd")
wfc_dir=$(read_cfg "$cfg_file" "qe" "wfc_dir")
yambo_kgrid=$(read_cfg "$cfg_file" "yambo" "yambo_kgrid")
chi_bands=$(read_cfg "$cfg_file" "yambo" "chi_bands")
NGsBlkXs=$(read_cfg "$cfg_file" "yambo" "NGsBlkXs")
yambo_dir=$(read_cfg "$cfg_file" "yambo" "yambo_dir")
Gmax=$(read_cfg "$cfg_file" "wfc2bin" "Gmax")
in_min=$(read_cfg "$cfg_file" "mantel" "in_min")
in_max=$(read_cfg "$cfg_file" "mantel" "in_max")

# Apply defaults for optional values
[ -z "$NGsBlkXs" ] && NGsBlkXs=25
[ -z "$Gmax" ]     && Gmax=12
[ -z "$wfc_dir" ]  && wfc_dir=WFC
[ -z "$yambo_dir" ] && yambo_dir=YAMBO

# CLI overrides (highest priority)
[ -n "${cli_qe_kgrid:-}" ]   && qe_kgrid=$cli_qe_kgrid
[ -n "${cli_nbnd:-}" ]       && nbnd=$cli_nbnd
[ -n "${cli_yambo_kgrid:-}" ] && yambo_kgrid=$cli_yambo_kgrid
[ -n "${cli_chi_bands:-}" ]  && chi_bands=$cli_chi_bands
[ -n "${cli_ngsblk:-}" ]     && NGsBlkXs=$cli_ngsblk
[ -n "${cli_Gmax:-}" ]       && Gmax=$cli_Gmax
[ -n "${cli_in_min:-}" ]     && in_min=$cli_in_min
[ -n "${cli_in_max:-}" ]     && in_max=$cli_in_max

# ----------   Validation   ----------

[ -z "$seed" ]        && fail "'seed' could not be derived from filename."
[ -z "$qe_kgrid" ]    && fail "'qe_kgrid' not found in &qe block (or -q)."
[ -z "$yambo_kgrid" ] && fail "'yambo_kgrid' not found in &yambo block (or -y)."
[ -z "$chi_bands" ]   && fail "'chi_bands' not found in &yambo block (or -B)."
[ -z "$in_min" ]      && fail "'in_min' not found in &mantel block (or -i)."
[ -z "$in_max" ]      && fail "'in_max' not found in &mantel block (or -j)."

is_positive_int "$num_np"   || fail "num_np must be a positive integer (got '$num_np')."
is_positive_int "$chi_bands" || fail "chi_bands must be a positive integer (got '$chi_bands')."
is_positive_int "$NGsBlkXs" || fail "NGsBlkXs must be a positive integer (got '$NGsBlkXs')."
is_positive_int "$Gmax"     || fail "Gmax must be a positive integer (got '$Gmax')."
is_positive_int "$in_min"   || fail "in_min must be a positive integer (got '$in_min')."
is_positive_int "$in_max"   || fail "in_max must be a positive integer (got '$in_max')."
[ "$in_min" -le "$in_max" ] || fail "in_min ($in_min) must be <= in_max ($in_max)."
[ -f "${seed}.scf.in" ]     || fail "${seed}.scf.in not found."

for cmd in qe_driver.sh yambo_driver.sh; do
    command -v "$cmd" &>/dev/null || fail "'$cmd' not found in PATH."
done

# ----------   Logging   ----------

LOG_FILE="${seed}_prep.log"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "[$(timestamp)] Logging to ${LOG_FILE}"

echo "========================================"
echo "  mantel-prep  $(date '+%Y-%m-%d %H:%M:%S')"
echo "  seed=$seed  np=$num_np"
echo "  qe_kgrid='$qe_kgrid'  nbnd=${nbnd:-auto}"
echo "  yambo_kgrid='$yambo_kgrid'  chi_bands=$chi_bands  NGsBlkXs=$NGsBlkXs Ry"
echo "  Gmax=$Gmax  bands=$in_min..$in_max"
echo "  config=$cfg_file"
echo "========================================"
RUN_START=$SECONDS

# ----------   Pipeline   ----------

# Stage 1a: QE
step "QE (SCF + bands)"
qe_args=(-n "$num_np")
[ -n "$nbnd" ] && qe_args+=(--nbnd "$nbnd")
[ -n "$wfc_dir" ] && qe_args+=(-d "$wfc_dir")
qe_driver.sh "${qe_args[@]}" "$seed" "$qe_kgrid" || fail "qe_driver.sh failed."
step_done

# Stage 1b: Yambo
step "Yambo (SCF + NSCF + RPA)"
yambo_driver.sh -n "$num_np" -b "$chi_bands" -g "$NGsBlkXs" -d "$yambo_dir" "$seed" "$yambo_kgrid" \
    || fail "yambo_driver.sh failed."
step_done

echo "========================================"
echo "  Prep complete.  Total: $((SECONDS - RUN_START))s"
echo ""
echo "  Next step — run mantel-run.sh:"
echo "    mantel-run.sh -c ${cfg_file}"
echo "========================================"

wait
