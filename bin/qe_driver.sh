#!/bin/bash
set -euo pipefail

####################################################################################
#           This script runs the QE bands calculation to find                      #
#             the Bloch wavefunctions (stored as wfc#.dat)                         #
#         and stores them in the final directory (default: WFC)                    #
####################################################################################

# --- Default Values ---
mpinp=32           # Default MPI cores

# --- Usage/Help Function ---
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
        #Remove any quotes
        sed "s/^['\"]//; s/['\"]$//" |
        #Trim trailing whitespace
        sed 's/[[:space:]]*$//'
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


# Check the input file exists
[ -z "$cfg_file" ] && fail "Input file is required. Use -c <seed>.mantel.in."
[ -f "$cfg_file" ] || fail "Input file '$cfg_file' not found."

# Read from the namelist
qe_kgrid=$(read_cfg "$cfg_file" qe qe_kgrid || true)
nbnd=$(read_cfg "$cfg_file" qe nbnd     || true)
wfc_dir=$(read_cfg "$cfg_file" qe wfc_dir || true)
scf_in=$(read_cfg "$cfg_file" qe scf_in || true)

if [ -z "$wfc_dir" ]; then wfc_dir=WFC; fi
[ -z "$scf_in" ] && fail "SCF input file not found."



# Check commands
for cmd in pw.x mpirun qe_input.py; do
    command -v "$cmd" >/dev/null || fail "'$cmd' not found in PATH. ..."
done
[ -f "${scf_in}" ] || fail "SCF input ${scf_in} not found."

t_start=$SECONDS

#Log command. Prefix any message with a timestamp
log() {
     echo "[$(date '+%H:%M:%S')] $*"; 
}

# --- 5. Debug / Confirmation  ---
echo "Configuration:"
echo "--------------------------"
echo "  Cores:          $mpinp"
echo "  scf_in:         $scf_in"
echo "  qe nbnd:        $nbnd"
echo "  qe kgrid:       ${qe_kgrid}"
echo "--------------------------"

# Build the .bands input
qe_input.py "${scf_in}" "bands.in" --mode bands --nbnd "$nbnd" --kgrid "$qe_kgrid"


# Outdir can be empty - if so, default to current directory. Otherwise, extract the value from the scf input file.
outdir=$(grep -E "^[[:space:]]*outdir[[:space:]]*=" "$scf_in" | head -1 | awk -F"=" '{gsub(/[" \047,]/,"",$2); print $2}' || true)
outdir="${outdir:-.}"
prefix=$(grep -E "^[[:space:]]*prefix[[:space:]]*=" "$scf_in" | head -1 | awk -F"=" '{gsub(/[" \047,]/,"",$2); print $2}' || true)
[ -z "$prefix" ] && fail "could not read prefix from $scf_in"


#Run SCF calculation
log "Starting SCF calculation..."
mpirun -n ${mpinp} pw.x < "${scf_in}" > scf.out
grep -q "JOB DONE." scf.out || { echo "Error: SCF calculation failed"; exit 1; }
mkdir -p xml && cp "${outdir}/${prefix}.save/data-file-schema.xml" xml/scf.xml
log "SCF calculation completed."

#Run bands calculation
log "Starting Bands calculation..."
mpirun -n ${mpinp} pw.x -in bands.in > bands.out
grep -q "JOB DONE." bands.out || { echo "Error: Bands calculation failed"; exit 1; }
cp "${outdir}/${prefix}.save/data-file-schema.xml" xml/bands.xml
log "Bands calculation completed."

#Copy wfc.dat files to final directory
log "Copying wavefunction files to final directory..."
mkdir -p ${wfc_dir}
rsync -aW --info=stats2 "${outdir}/${prefix}.save/" "${wfc_dir}/"
rm -f ${wfc_dir}/charge-density.dat
rm -f ${wfc_dir}/*.upf
log "Wavefunction files copied to ${wfc_dir}."


#Ensure the outdir is removed to avoid confusion for later steps
safe_rm_outdir "${outdir}" || log "WARNING: outdir cleanup skipped"

log "All done. Total elapsed: $(( SECONDS - t_start ))s"

