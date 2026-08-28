#!/usr/bin/env python3

####################################################################################
#       This script is used to prepare the YAMBO data in the .bin format           #
#     Produces the epsm1_unpadded.bin, yambo_qs.bin and yambo_Gs.bin files         #
####################################################################################

try:
    from yambopy import *
except ImportError:
    print("Error: yambopy is not installed. Install it with: pip install yambopy")
    import sys
    sys.exit(1)

import argparse
import struct
import sys

def fortran_binary_write(filename, data):
    """
    Saves the data in a format that can be easily read in with fortran
    Format is:
    <rank_id>
    <array shape>
    <array>

    e.g.
    3
    4 4 4
    <data>
    """
    # 1. Detect Type and Assign ID
    # ----------------------------
    if np.issubdtype(data.dtype, np.integer):
        #print(f"Detected INTEGER. Converting to int32...")
        type_id = 1
        # Fortran 'int32' matches numpy 'int32'
        data_out = data.astype(np.int32)
        
    elif np.issubdtype(data.dtype, np.complexfloating):
        #print(f"Detected COMPLEX. Converting to complex128...")
        type_id = 3
        # Fortran 'complex(real64)' matches numpy 'complex128'
        # NumPy stores this as (Real, Imag) pairs automatically.
        data_out = data.astype(np.complex128)
        
    elif np.issubdtype(data.dtype, np.floating):
        #print(f"Detected REAL. Converting to float64...")
        type_id = 2
        # Fortran 'real(real64)' matches numpy 'float64'
        data_out = data.astype(np.float64)
        
    else:
        raise ValueError("Unsupported Data Type! Use Int, Float, or Complex.")

    # 2. Extract Metadata
    # -------------------
    rank = data_out.ndim
    shape = data_out.shape

    # 3. Write to File
    # ----------------
    
    with open(filename, 'wb') as f:
        # A. Write Rank (int32)
        f.write(struct.pack('i', rank))
        
        # B. Write Type ID (int32)
        f.write(struct.pack('i', type_id))
        
        # C. Write Dimensions (N * int32)
        # We pack 'N' integers at once.
        f.write(struct.pack(f'{rank}i', *shape))
        
        # D. Write Data 
        # CRITICAL: Use order='F' to fix the Column-Major vs Row-Major difference
        # CRITICAL: Do NOT split real/imag. Keep them interleaved.
        f.write(data_out.tobytes(order='F'))


def main():
    parser = argparse.ArgumentParser(description='Prepare the yambo output. Ensure you have yambopy installed.')
    parser.add_argument("save", type=str, help="The yambo save folder. e.g. YAMBO/SAVE")
    parser.add_argument("job", type=str, help="The yambo job folder. e.g. YAMBO/RPA")
    args = parser.parse_args()

    yambo_database = YamboStaticScreeningDB(save=f"{args.save}", em1s=f"{args.job}/")

    # (numq, num_yamboG, num_yamboG)
    epsm1_unpadded = np.array ( yambo_database.X )                  

    # Need scaling to match QE. (numq, 3)
    yambo_qs = 2 * np.pi * np.array(yambo_database.car_qpoints)

    # (num_yamboGs, 3)
    yambo_Gs_crystal = np.rint( np.array(yambo_database.red_gvectors)).astype(np.int32)

    # rearrange to suit fortran ordering
    epsm1_unpadded_fort = np.transpose(epsm1_unpadded, (1,2,0))
    yambo_qs_fort = np.transpose(yambo_qs, (1,0))
    yambo_Gs_crystal_fort = np.transpose(yambo_Gs_crystal, (1,0))

    #save .bin files
    fortran_binary_write("epsm1_unpadded.bin", epsm1_unpadded_fort)
    fortran_binary_write("yambo_qs.bin", yambo_qs_fort)
    fortran_binary_write("yambo_Gs.bin", yambo_Gs_crystal_fort)
    print("Wrote: epsm1_unpadded.bin, yambo_qs.bin, yambo_Gs.bin")

if __name__ == "__main__":
    main()