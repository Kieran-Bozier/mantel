#!/bin/bash
set -euo pipefail

# yambo_driver.sh
# Runs the Yambo part of the calculation

# ---- 1. Default parameters ----
mpinp=32           # Default MPI cores
nbnd=""            # Required: number of bands (must be set via -b)
ngsblk=25          # Default NGsBlkXs (Ry)
final_dir="YAMBO"  # Default final directory
seed=""            # Required: seed name (must be set via positional argument)
kgrid=""           # Required: kgrid for nscf (must be set via positional argument)

# ---- 2. Usage function ----
usage() {
    echo "Usage: $0 [OPTIONS] seed kgrid"
    echo ""
    echo "Arguments:"
    echo "  seed              The name of the system (e.g., 'silicon')"
    echo "  kgrid             The kgrid used in the nscf calculation, which sets the Yambo grid"
    echo ""
    echo "Options:"
    echo "  -n, --np <int>       Number of MPI cores (Default: 32)"
    echo "  -b, --nbnd <int>     Number of bands (Required)"
    echo "  -g, --ngsblk <int>   NGsBlkXs value in Ry (Default: 25)"
    echo "  -d, --dir <path>     Name of final directory (Default: YAMBO)"
    echo "  -h, --help           Show this help message"
    echo ""
    exit 1
}

# ---- 3. Argument Parsing Loop ----
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -n|--np)
            mpinp="$2"
            shift 2 # Consume flag and value
            ;;
        -b|--nbnd)
            nbnd="$2"
            shift 2
            ;;
        -g|--ngsblk)
            ngsblk="$2"
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

# ---- 4. Validation ----
if [ -z "$seed" ] || [ -z "$kgrid" ]; then
    echo "Error: You must provide a seed name and kgrid (e.g Al 12)."
    usage
fi

if [ -z "$nbnd" ]; then
    echo "Error: You must specify the number of bands with -b/--nbnd."
    usage
fi

t_start=$SECONDS

log() { echo "[$(date '+%H:%M:%S')] $*"; }

# ---- 5. Confirmation ----
echo "Configuration:"
echo "--------------------------"
echo "  Seed:       $seed"
echo "  Cores:      $mpinp"
echo "  Bands:      $nbnd"
echo "  Output:     $final_dir"
echo "  nscf kgrid: $kgrid"
echo "--------------------------"


build_yambo_scf() {
    local seed=$1
    local nbnd=$2

    cp "${seed}.scf.in" "${seed}_yambo.scf.in"

    # --- Sort out bands ---
    # Always write the user-supplied nbnd, overwriting any existing value.
    if grep -q "nbnd" "${seed}_yambo.scf.in"; then
        # Matches 'nbnd', optional spaces, '=', optional spaces, and the number.
        # Replaces only that part, preserving trailing commas or comments.
        sed -i "s/nbnd[[:space:]]*=[[:space:]]*[0-9]*/nbnd = ${nbnd}/" "${seed}_yambo.scf.in"
        echo "Overwriting existing 'nbnd' with ${nbnd}"
    else
        sed -i "/^[[:space:]]*ibrav/a \ \ nbnd = ${nbnd}," "${seed}_yambo.scf.in"
        echo "Setting nbnd to ${nbnd}"
    fi

    # --- Other Parameters ---

    # Check if verbosity set to high
    if ! grep -q "verbosity" "${seed}_yambo.scf.in"; then
        sed -i "/^[[:space:]]*outdir/a \ \ verbosity = 'high'" "${seed}_yambo.scf.in"
        echo "Setting verbosity to high"
    fi

    # Check if force_symmorphic is set
    if ! grep -q "force_symmorphic" "${seed}_yambo.scf.in"; then
        sed -i "/^[[:space:]]*occupations/a \ \ force_symmorphic = .true." "${seed}_yambo.scf.in"
        echo "Setting force_symmorphic to true"
    fi

    echo "Written ${seed}_yambo.scf.in"
}



build_yambo_nscf(){
    local seed=$1
    local kgrid=$2
    cp "${seed}_yambo.scf.in" "${seed}_yambo.nscf.in"

    #change calculation
    sed -i "s/scf/nscf/" "${seed}_yambo.nscf.in"

    #set kgrid
    sed -i "/K_POINTS automatic/{n;s/.*/$kgrid 0 0 0/;}" "${seed}_yambo.nscf.in"

    echo "Written ${seed}_yambo.nscf.in for Yambo calculation"
}

build_yambo_in(){
    local seed=$1
    local actual_nbnd=$2
    local actual_ngsblk=$3

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
build_yambo_scf "$seed" "$nbnd"
mpirun -n ${mpinp} pw.x < "${seed}_yambo.scf.in" > "${seed}_yambo.scf.out"
grep -q "JOB DONE." "${seed}_yambo.scf.out" || { echo "Error: SCF calculation failed"; exit 1; }
log "SCF calculation completed."

# Build the nscf file
log "Starting Yambo NSCF calculation..."
build_yambo_nscf "$seed" "$kgrid"
mpirun -n ${mpinp} pw.x < "${seed}_yambo.nscf.in" > "${seed}_yambo.nscf.out"
grep -q "JOB DONE." "${seed}_yambo.nscf.out" || { echo "Error: NSCF calculation failed"; exit 1; }
log "NSCF calculation completed."

workdir=$(pwd)
mkdir -p "${final_dir}"
outdir=$(grep 'outdir' "${seed}_yambo.scf.in" | awk -F "=" '{gsub(/[" \047]/,"",$2); print $2}')
cd "$outdir/${seed}.save/"

log "Initializing Yambo..."
p2y
mv SAVE "${workdir}/${final_dir}/SAVE"
cd "${workdir}/${final_dir}"

log "Running Yambo..."
yambo

build_yambo_in "$seed" "$nbnd" "$ngsblk"
log "Running Yambo RPA screening..."
mpirun -n ${mpinp} yambo -Input yambo_RPA.in -J RPA

#Ensure outdir is removed to remove confusion for later steps
outdir=$(grep 'outdir' ${seed}.scf.in | awk -F "=" '{gsub(/[" \047]/,"",$2); print $2}')
[ -d "${outdir}" ] && rm -rf "${outdir}"



log "Yambo calculation completed. Total elapsed: $(( SECONDS - t_start ))s"