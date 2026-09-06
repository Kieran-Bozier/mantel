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
    numE            = 200
    minE            = -20.0
    maxE            = 20.0
    sigma           = 0.2
/ 

&mu
    min_sigma       = 0.01
    max_sigma       = 1.00
    num_sigma       = 100
    nef             = -1.0
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

    ! G cutoff energy for dielectric function. Determines how many G included for \\epsilon_G,G'(q,w). 
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
    in_min          = 

    ! Maximum band to include when evaluating W_nkmp. 
    in_max          = 

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

    ! Minimum energy (compared to Fermi energy) to use when evaluating W(e,e'). In eV.
    minE             = -20.0

    ! Maximum energy (compared to Fermi energy) to use when evaluating W(e,e'). In eV.
    maxE             = 20.0

    ! Width of Gaussian smearing in eV to use when evaluating W(e,e'). 
    sigma            = 0.2
/ 

&mu
    ! Minimum Gaussian smearing width (eV)
    min_sigma       = 0.01

    ! Maximum Gaussian smearing width (eV)
    max_sigma       = 1.00

    ! Number of smearings
    num_sigma       = 100

    ! True density of states at the Fermi energy (N_F).
    ! Because Gaussian smearing often gets N_F incorrect,
    ! you can pass in e.g. a linear tetrahedral DOS value.
    ! mu.x will then returns a DOS rescaled value as final column
    ! Leave as -1.0 is don't want to apply the correction 
    !
    ! Units: states/eV/spin
    ! Be aware default QE .dos.dat is typically states/eV, so need to half
    nef             = -1.0
/

"""
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

