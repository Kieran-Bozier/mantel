#!/usr/bin/env python3

#       qe_input.py
#       This script is responsible for taking the input
#       scf file and making the bands, yambo_scf etc.
import argparse
from pathlib import Path
import re

#All cards in pw.x
CARDS = ("ATOMIC_SPECIES", "ATOMIC_POSITIONS", "K_POINTS", "CELL_PARAMETERS",
           "OCCUPATIONS", "CONSTRAINTS", "ATOMIC_VELOCITIES", "ATOMIC_FORCES",
           "ADDITIONAL_K_POINTS", "SOLVENTS", "HUBBARD")

def set_key(lines, group, key, value):
    """Replace `key` if present, else insert it after the &group header."""
    pat = re.compile(rf"^\s*{key}\s*=", re.I)
    for i, line in enumerate(lines):
        if pat.match(line):
            lines[i] = f"  {key} = {value}\n"
            return lines

    head = re.compile(rf"^\s*&{group}\b", re.I)
    for i, line in enumerate(lines):
        if head.match(line):
            lines.insert(i + 1, f"  {key} = {value}\n")
            return lines

    raise ValueError(f"&{group} not found — cannot set {key}")


def replace_kpoints(lines, new_block):
    """                                                                                                                                                                                                                               
    Replaces the K_POINTS card with new_block.
    The card runs from the K_POINTS header to the next card (or the
    end of the file), so any cards written after it are preserved.
    """
    start = None
    for i, line in enumerate(lines):
        if line.strip().upper().startswith("K_POINTS"):
            start = i
            break

    if start is None:
        raise ValueError("K_POINTS card not found")

    end = start + 1
    while end < len(lines) and not lines[end].strip().upper().startswith(CARDS):
        end += 1

    return lines[:start] + list(new_block) + lines[end:]


def kpoints_crystal(n1, n2, n3):
    """
    Replaces the kmesh.pl utility. Weights sum to 1.
    """
    nk = n1 * n2 * n3
    w = 1.0 / nk

    lines = ["K_POINTS crystal\n", f"{nk}\n"]
    for i in range(n1):
        for j in range(n2):
            for k in range(n3):
                lines.append(f"  {i/n1:.8f} {j/n2:.8f} {k/n3:.8f} {w:.8f}\n")
    return lines

def kpoints_automatic(n1, n2, n3):
    """
    Uniform Monkhorst-Pack grid, no offset.
    """
    return ["K_POINTS automatic\n", f"  {n1} {n2} {n3} 0 0 0\n"]


def split_kgrid(string):
    """
    Splits the kgrid string into 3 integers
    """
    parts = string.split()
    if len(parts) != 3:
        raise argparse.ArgumentTypeError(f"expected 3 integers, got '{string}'") 
    return [int(p) for p in parts]


def build_bands(lines, nbnd, kgrid):
    """
    Builds the bands file used to find the QE wavefunctions
    """
    lines = set_key(lines, "control", "calculation", "'bands'")
    lines = set_key(lines, "system", "nbnd", nbnd)
    lines = replace_kpoints(lines, kpoints_crystal(kgrid[0], kgrid[1], kgrid[2]))
    return lines



def build_nscf_yambo(lines, nbnd, kgrid):
    """
    Builds the nscf file used for Yambo
    """
    lines = set_key(lines, "control", "calculation", "'nscf'")
    lines = set_key(lines, "system", "nbnd", nbnd)
    lines = set_key(lines, "system", "force_symmorphic", ".true.")
    lines = replace_kpoints(lines, kpoints_automatic(kgrid[0], kgrid[1], kgrid[2]))
    return lines 


def build_scf_yambo(lines, nbnd, kgrid):
    """
    Builds the scf file used for Yambo
    """
    if kgrid is not None:
        lines = replace_kpoints(lines, kpoints_automatic(kgrid[0], kgrid[1], kgrid[2]))
    if nbnd is not None:
        lines = set_key(lines, "system", "nbnd", nbnd)
    lines = set_key(lines, "system", "force_symmorphic", ".true.")
    return lines



def main(): 
    parser = argparse.ArgumentParser(description="Python helper to write necessary input files")
    parser.add_argument("infile", type=Path, help="Template QE scf input")
    parser.add_argument("outfile", type=Path, help="File to write")
    parser.add_argument("--mode", required=True, choices=["bands", "scf-yambo", "nscf-yambo"])
    parser.add_argument("--nbnd" , type=int, help="Number of bands")
    parser.add_argument("--kgrid", type=split_kgrid, help="The new kgrid. Pass in as \"nk1 nk2 nk3\".")
    args = parser.parse_args()


    if args.mode in ["bands" , "nscf-yambo"]:
        if args.nbnd is None or args.kgrid is None:
            parser.error(f"--mode {args.mode} requires --nbnd and --kgrid")
    

    with open(args.infile, 'r') as f:
        lines = f.readlines()

    if args.mode == "bands":
        lines = build_bands(lines, args.nbnd, args.kgrid)
    elif args.mode == "scf-yambo":
        lines = build_scf_yambo(lines, args.nbnd, args.kgrid)
    elif args.mode == "nscf-yambo":
        lines = build_nscf_yambo(lines, args.nbnd, args.kgrid)

    
    with open(args.outfile, 'w') as f2:
        f2.write("".join(lines))

 

if __name__ == "__main__":
    main()