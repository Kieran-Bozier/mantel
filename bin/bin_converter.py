#!/usr/bin/env python3

####################################################################################
#           This script is used to convert from a .bin file into                   #
#                          a .npy file.                                            #
####################################################################################

import numpy as np 
import argparse 
import struct
import sys
import os

def parse_order(ord_str):
    try:
        return [int(x) for x in ord_str.split(',')]
    except ValueError:
        raise argparse.ArgumentTypeError("Order must be a comma-separated list of integers (e.g., 1,2,3,0)")


def fortran_binary_read(filename):
    """
    Reads the data in from the binary format
    Format is:
    <rank>
    <rank_id>
    <array shape>
    <array>
    """
    # map id to numpy dtype
    dtype_map = {
        1: np.int32,
        2: np.float64,
        3: np.complex128
    }

    if not os.path.exists(filename):
        raise FileNotFoundError(f"File '{filename}' does not exist.")

    with open(filename, 'rb') as f:
        #Rank
        rank_data = f.read(4)
        if not rank_data:
            raise ValueError("File is empty or header is missing.")
        rank = struct.unpack('i', rank_data)[0]

        #Type
        type_id_data = f.read(4)
        type_id = struct.unpack('i', type_id_data)[0]

        if not type_id in dtype_map:
            raise ValueError(f"Unsupported type ID '{type_id}' found in file.")
        dtype = dtype_map[type_id]

        #Shape
        shape_bytes = f.read(4 * rank)
        shape = struct.unpack(f'{rank}i', shape_bytes)

        #Data
        try:
            flat_data = np.fromfile(f, dtype=dtype)
        except Exception as e:
            raise IOError(f"Failed to read data payload: {e}")

    expected_elements = np.prod(shape)
    if flat_data.size != expected_elements:
        raise ValueError(
            f"Data mismatch! Header claims shape {shape} ({expected_elements} elements), "
            f"but file contained {flat_data.size} elements."
        )

    # 5. Reshape and Reorder
    # CRITICAL: We must use order='F' because the writer used tobytes(order='F').
    # This reconstructs the array filling columns first (Fortran style).
    data = flat_data.reshape(shape, order='F')

    return data

def main():
    parser = argparse.ArgumentParser(description="Convert Fortran-style binary .bin files to NumPy .npy files.")
    parser.add_argument("input_file", type=str, help="Input .bin file to convert.")
    parser.add_argument("--ord", type=parse_order, default=None, help="Order of dimensions for reshaping, e.g., '1,2,3,0'")
    parser.add_argument("--out", type=str, default=None, help="Output .npy filename. If not provided, uses input filename with .npy extension.")
    args = parser.parse_args()


    try:
        print(f"Reading {args.input_file}...")
        data = fortran_binary_read(args.input_file)
        print(f"Original Shape: {data.shape}")

        # Handle Reordering
        if args.ord is not None:
            if len(args.ord) != data.ndim:
                print(f"Error: --ord has {len(args.ord)} dimensions, but data has {data.ndim}.")
                sys.exit(1)
                
            print(f"Transposing data with order: {args.ord}")
            data = data.transpose(args.ord)
            print(f"New Shape: {data.shape}")
        
        # Determine output filename
        if args.out:
            output_file = args.out
        else:
            base = os.path.splitext(args.input_file)[0]
            output_file = base + ".npy"

        np.save(output_file, data)
        
        print(f"Success! Saved to {output_file}")
        print(f"Final Dtype: {data.dtype}")
        
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()





