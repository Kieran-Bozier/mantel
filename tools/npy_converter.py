#!/usr/bin/env python3

####################################################################################
#           This script is used to convert from a .npy file into                   #
#                          a .bin file.                                            #
####################################################################################


import numpy as np
import argparse 
import struct
import sys

def parse_order(ord_str):
    """Helper to parse comma-separated string '1,2,3' into list [1, 2, 3]"""
    try:
        return [int(x) for x in ord_str.split(',')]
    except ValueError:
        raise argparse.ArgumentTypeError("Order must be a comma-separated list of integers (e.g., 1,2,3,0)")


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
        f.write(data_out.tobytes(order='F'))

def main():
    parser = argparse.ArgumentParser(description="Convert .npy files to Fortran-compatible binary format.")
    parser.add_argument('input_file', type=str, help="Input .npy file path")
    parser.add_argument("--ord", type=parse_order, default=None, help="Order of dimensions for reshaping, e.g., '1,2,3,0'")    
    args = parser.parse_args()

    try:
        data = np.load(args.input_file)
    except FileNotFoundError:
        print(f"Error: File {args.input_file} not found.")
        sys.exit(1)

    # Handle Reordering
    if args.ord is not None:
        if len(args.ord) != data.ndim:
            print(f"Error: --ord has {len(args.ord)} dimensions, but data has {data.ndim}.")
            sys.exit(1)
            
        print(f"Transposing data with order: {args.ord}")
        # Note: transpose returns a view; memory is reordered during tobytes(order='F') later
        data = data.transpose(args.ord)

    seedname = args.input_file.rsplit('.', 1)[0]
    output_file = seedname + ".bin"

    fortran_binary_write(output_file, data)

    print(f"Successfully converted {args.input_file} to {output_file}.")
    print(f"Array shape: {data.shape}, dtype: {data.dtype}")


if __name__ == "__main__":
    main()
