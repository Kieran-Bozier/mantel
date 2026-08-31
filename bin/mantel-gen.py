#!/usr/bin/env python3

#############################################################################
#                   Writes an template .mantel.in file                      #
#############################################################################
import argparse 
from datetime import datetime



def default_input():
    contents = f"""! mantel.in file generated on {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}
&qe
    qe_kgrid         = ""
    nbnd            = 
    wfc_dir         = "./WFC"
    scf_in          = "scf.in"
/

&yambo
    yambo_kgrid     = ""
    chi_bands       =    
    NGsBlkXs        =
    yambo_dir       = "./YAMBO"
/

&wfc2bin
    Gmax            =
/

&mantel
    in_min          = 
    in_max          =
    iq_min          = 1
    iq_max          = -1
    qtf_method      = "fit"
    qtf_fit_nq      = 3
/

&isoenergy
    numE             = 200
    minE             = -20.0
    maxE             = 20.0
    sigma            = 0.2
/"""
    return contents


def verbose_input():
    contents = f"""! mantel.in file generated on {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}
&qe
    ! Electronic k grid
    qe_kgrid         = ""

    ! Number of electronic bands - set large if want plot W(e,e') up to high energies
    nbnd            = 
    
    ! Directory where the QE wavefunctions are stored
    wfc_dir         = "./WFC"

    ! scf input file
    scf_in          = "scf.in" 
/

&yambo
    ! Electronic grid used in Yambo, this is the q grid for the inverse dielectric function
    yambo_kgrid     = ""

    ! Number of bands used to compute dielectric. Needs to be large to allow transitions to empty bands
    chi_bands       =    

    ! G cutoff energy for dielectric function. Determines how many G included for \epsilon_G,G'(q,w). 
    NGsBlkXs        =

    ! Directory where the Yambo output files are stored
    yambo_dir       = "./YAMBO"
/

&wfc2bin
    ! Determines size of cubic grid wfc are stored on. Grid size is (2Gmax + 1)**3
    Gmax            =
/

&mantel
    ! Minimum band to include when evaluating W_nkmp
    in_min          = 1

    ! Maximum band to include when evaluating W_nkmp. Set -1 to include upper limit of QE nbnd
    in_max          = -1

    ! Minimum q to include when evaluating W_nkmp
    iq_min          = 1

    ! Maximum q to include when evaluating W_nkmp. Set to -1 to include all q
    iq_max          = -1

    ! Method to use for q->0 extrapolation. Options: "fit" or "electrons"
    qtf_method      = "fit"

    ! Number of q points to use for fitting the q->0 extrapolation. Only used if qtf_method="fit"
    qtf_fit_nq      = 3
/

&isoenergy
    ! Number of energy points to use when evaluating W(e,e')
    numE             = 200

    ! Minimum energy (compared to Fermi energy) to use when evaluating W(e,e'). 
    minE             = -20.0

    ! Maximum energy (compared to Fermi energy) to use when evaluating W(e,e').
    maxE             = 20.0

    ! Width of Gaussian smearing in eV to use when evaluating W(e,e'). 
    sigma            = 0.2
/"""
    return contents


def main(): 
    parser = argparse.ArgumentParser(description="Generate a mantel.in template file.")
    parser.add_argument("output_file", type=str, help="Output mantel.in file path")
    parser.add_argument("-v", action="store_true", help="Include comments on what all variables mean")
    args = parser.parse_args()

    if args.v:
        content=verbose_input()
    else:
        content=default_input()
    
    with open(args.output_file, 'w') as f:
        f.write(content)
    




if __name__ == "__main__":
    main()

