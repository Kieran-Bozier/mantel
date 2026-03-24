#!/bin/bash
set -euo pipefail

####################################################################################
#           This script runs the QE bands calculation to find                      #
#             the Bloch wavefunctions (stored as wfc#.dat)                         #
#         and stores them in the final directory (default: WFC)                    #
####################################################################################

# --- 1. Default Values ---
mpinp=32           # Default MPI cores
final_dir="WFC"    # Default output directory
seed=""            # Seed is empty initially
kgrid=""           # kgrid is empty initially
nbnd_override=""   # Optional explicit band count; if unset, uses 1.4 × SCF nbnd

# --- 2. Usage/Help Function ---
usage() {
    echo "Usage: $0 [OPTIONS] seed kgrid"
    echo ""
    echo "Arguments:"
    echo "  seed              The name of the system (e.g., 'silicon')"
    echo "  kgrid             kgrid used in bands calculation (cubic grid)"
    echo ""
    echo "Options:"
    echo "  -n, --np <int>    Number of MPI cores (Default: 32)"
    echo "  -b, --nbnd <int>  Number of bands for bands calculation (Default: 1.4 × SCF nbnd)"
    echo "  -d, --dir <path>  Name of final directory (Default: WFC)"
    echo "  -h, --help        Show this help message"
    echo ""
    exit 1
}

# --- 3. Argument Parsing Loop ---
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -n|--np)
            mpinp="$2"
            shift 2
            ;;
        -b|--nbnd)
            nbnd_override="$2"
            shift 2
            ;;
        -d|--dir)
            final_dir="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        -*) # Handle unknown flags
            echo "Error: Unknown option: $1"
            usage
            ;;
        *) # Handle positional argument (seed)
            if [ -z "$seed" ]; then
                seed="$1"
                shift 1
            elif [ -z "$kgrid" ]; then
                kgrid="$1"
                shift 1
            else
                echo "Error: Too many positional arguments provided."
                usage
            fi
            ;;
    esac
done

# --- 4. Validation ---
if [ -z "$seed" ] || [ -z "$kgrid" ]; then
    echo "Error: You must provide a seed name and kgrid (e.g Al 12)."
    usage
fi

t_start=$SECONDS

#Log command. Prefix any message with a timestamp
log() {
     echo "[$(date '+%H:%M:%S')] $*"; 
}

# --- 5. Debug / Confirmation  ---
echo "Configuration:"
echo "--------------------------"
echo "  Seed:           $seed"
echo "  Cores:          $mpinp"
echo "  Output:         $final_dir"
echo "  Bands kgrid:    $kgrid"
echo "--------------------------"

# function to build the .bands input
build_bands() {
    local seed=$1
    local kgrid=$2

    nbnd=$(grep 'Kohn-Sham' ${seed}.scf.out | awk '{print $5}')
    [ -z "$nbnd" ] && { echo "Error: could not extract nbnd from SCF output"; exit 1; }
    if [ -n "$nbnd_override" ]; then
        new_nbnd=$nbnd_override
        echo "Using explicit nbnd = ${new_nbnd} for bands calculation"
    else
        new_nbnd=$(awk -v nbnd="$nbnd" 'BEGIN{nbnd=int(nbnd*1.4); print nbnd}')
    fi

    cp ${seed}.scf.in ${seed}.bands.in
    sed -i "s/scf/bands/" ${seed}.bands.in

    #Check if nbnd already set - if not, set it
    if ! grep -q "nbnd" "${seed}.bands.in"; then
        sed -i "/^[[:space:]]*ibrav/a nbnd = ${new_nbnd}" "${seed}.bands.in"
        echo "Nbnd not set in scf file, so setting nbnd to ${new_nbnd} for bands calculation"
    fi

    #check if verbosity set to high
    if ! grep -q "verbosity" "${seed}.bands.in"; then
    sed -i "/^[[:space:]]*outdir/a \ \ verbosity = 'high'" "${seed}.bands.in"
    echo "Setting verbosity to high for bands calculation"
    fi

    sed -i '/^K_POINTS/{N;d;}' ${seed}.bands.in
    kmesh.pl "${kgrid}" >> ${seed}.bands.in
}



outdir=$(grep 'outdir' ${seed}.scf.in | awk -F "=" '{gsub(/[" \047]/,"",$2); print $2}')

#Run SCF calculation
log "Starting SCF calculation..."
mpirun -n ${mpinp} pw.x < ${seed}.scf.in > ${seed}.scf.out
grep -q "JOB DONE." ${seed}.scf.out || { echo "Error: SCF calculation failed"; exit 1; }
log "SCF calculation completed."

#Build the bands file and run bands calculation
build_bands "${seed}" "${kgrid}"
log "Starting Bands calculation..."
mpirun -n ${mpinp} pw.x -in ${seed}.bands.in > ${seed}.bands.out
grep -q "JOB DONE." ${seed}.bands.out || { echo "Error: Bands calculation failed"; exit 1; }
log "Bands calculation completed."

#Copy wfc.dat files to final directory
log "Copying wavefunction files to final directory..."
mkdir -p ${final_dir}
rsync -aW --info=stats2 ${outdir}/${seed}.save/ ${final_dir}/
rm -f ${final_dir}/charge-density.dat
rm -f ${final_dir}/*.upf
log "Wavefunction files copied to ${final_dir}."


#Ensure the outdir is removed to avoid confusion for later steps
[ -d "${outdir}" ] && rm -rf "${outdir}"

log "All done. Total elapsed: $(( SECONDS - t_start ))s"

