#!/usr/bin/env python3
#
#       This python script is used to read xml files
#       Can be imported as a module, or if used as a 
#       script, will write out 
#
import xml.etree.ElementTree as ET
from pathlib import Path
import numpy as np 
import argparse
import struct
from datetime import datetime


class QExml:
    """
    Class to store the information held in the xml file
    """

    def __init__(self, filename):
        """
        Initialise the class
        """
        tree = ET.parse(filename)
        self.root = tree.getroot()

    def _find(self, path):
        """
        Finds entry associated with path
        """
        return self.root.find(path)

    def _findall(self, path):
        """
        Finds ALL entries associated with path. Useful for KS eigenvalues
        """
        return self.root.findall(path)

    @property
    def calculation(self):
        """
        Return the calculation element
        """
        return self._find(".//input/control_variables/calculation").text

    @property
    def prefix(self):
        """Prefix / Seedname."""
        return self._find(".//input/control_variables/prefix").text

    @property
    def nbnd(self):
        """
        Number of bands used in the calculation
        """
        return int(float(self._find(".//input/bands/nbnd").text))
    
    @property
    def lsda(self):
        """
        Check if ldsa is used in the calculation
        """
        return self._find(".//input/spin/lsda").text == "true"

    @property
    def noncolin(self):
        """
        Check if non-colinear is used in the calculation
        """
        return self._find(".//input/spin/noncolin").text == "true"

    @property
    def spinorbit(self):
        """
        Check if spin orbit is used in the calculation
        """
        return self._find(".//input/spin/spinorbit").text == "true"

    @property
    def gamma_only(self):
        """
        Check if gamma_only is used in the calculation
        """
        return self._find(".//input/basis/gamma_only").text == "true"


    @property 
    def k_grid(self):
        """
        Returns the kgrid
        """
        try:
            elem = self._find(".//input/k_points_IBZ/monkhorst_pack")
            return [int(elem.attrib[f"nk{i}"]) for i in range(1, 4)]

        except (AttributeError, KeyError):
            return None



    @property
    def fermi_energy(self):
        """
        Fermi energy in eV.
        """
        Ha_to_eV = 27.211386245988
        return float(self._find(".//output/band_structure/fermi_energy").text) * Ha_to_eV  

    @property
    def nelec(self):
        """
        Number of electrons
        """
        return int(float(self._find(".//output/band_structure/nelec").text))

    @property
    def cell(self):
        """
        Cell vectors in Bohr, shape (3, 3).
        """
        a1 = np.array(self._find(".//output/atomic_structure/cell/a1").text.split(), dtype=float)
        a2 = np.array(self._find(".//output/atomic_structure/cell/a2").text.split(), dtype=float)
        a3 = np.array(self._find(".//output/atomic_structure/cell/a3").text.split(), dtype=float)
        return np.array([a1, a2, a3])

    @property
    def alat(self):
        """
        Lattice parameter in Bohr."""
        return float(self._find(".//output/atomic_structure").get("alat"))

    @property
    def kpoints_tpiba(self):
        """K-points in units of 2pi/alat, shape (nk, 3)."""
        ks_list = self._findall(".//output/band_structure/ks_energies")
        return np.array([
            ks.find("k_point").text.split()
            for ks in ks_list
        ], dtype=float)

    @property
    def kpoints_cart(self):
        """K-points in Cartesian coordinates, inverse Bohr, shape (nk, 3)."""
        return self.kpoints_tpiba * (2 * np.pi / self.alat)

    @property
    def kpoints_crys(self):
        """K-points in crystal (fractional) coordinates, shape (nk, 3)."""
        return self.kpoints_tpiba @ self.cell.T / self.alat

    @property
    def kweights(self):
        """K-point weights, shape (nk,)."""
        ks_list = self._findall(".//output/band_structure/ks_energies")
        return np.array([
            float(ks.find("k_point").get("weight"))
            for ks in ks_list
        ])

    @property
    def eigenvalues(self):
        """Eigenvalues in eV, shape (nk, nbnd)."""
        Ha_to_eV = 27.211386245988
        ks_list = self._findall(".//output/band_structure/ks_energies")
        return np.array([
            np.array(ks.find("eigenvalues").text.split(), dtype=float)
            for ks in ks_list
        ]) * Ha_to_eV


    @property
    def nat(self):
        """Number of atoms."""
        return int(self._find(".//output/atomic_structure").get("nat"))

    @property
    def atomic_positions(self):
        """Atomic positions in Bohr, shape (nat, 3)."""
        atoms = self._findall(".//output/atomic_structure/atomic_positions/atom")
        return np.array([atom.text.split() for atom in atoms], dtype=float)

    @property
    def atomic_species(self):
        """List of atom labels, length nat."""
        atoms = self._findall(".//output/atomic_structure/atomic_positions/atom")
        return [atom.get("name") for atom in atoms]

    @property
    def etot(self):
        """Total energy in eV."""
        Ha_to_eV = 27.211386245988
        return float(self._find(".//output/total_energy/etot").text) * Ha_to_eV

    @property
    def ecutwfc(self):
        """Wavefunction cutoff in Ry."""
        return float(self._find(".//input/basis/ecutwfc").text)

    @property
    def ecutrho(self):
        """Charge density cutoff in Ry."""
        return float(self._find(".//input/basis/ecutrho").text)

    @property
    def converged(self):
        """Whether SCF convergence was achieved."""
        return self._find(".//output/convergence_info/scf_conv/convergence_achieved").text == "true"

    @property
    def nks(self):
        """Number of k-points."""
        return int(self._find(".//output/band_structure/nks").text)

    @property
    def occupations(self):
        """Occupation numbers, shape (nk, nbnd)."""
        ks_list = self._findall(".//output/band_structure/ks_energies")
        return np.array([
            np.array(ks.find("occupations").text.split(), dtype=float)
            for ks in ks_list
        ])


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
    # Detect data Type and Assign ID
    # ----------------------------
    if np.issubdtype(data.dtype, np.integer):
        type_id = 1
        data_out = data.astype(np.int32)
        
    elif np.issubdtype(data.dtype, np.complexfloating):
        type_id = 3
        data_out = data.astype(np.complex128)
        
    elif np.issubdtype(data.dtype, np.floating):
        type_id = 2
        data_out = data.astype(np.float64)
        
    else:
        raise ValueError("Unsupported Data Type! Use Int, Float, or Complex.")

    rank = data_out.ndim
    shape = data_out.shape
    
    with open(filename, 'wb') as f:
        f.write(struct.pack('i', rank))
        f.write(struct.pack('i', type_id))
        f.write(struct.pack(f'{rank}i', *shape))
        f.write(data_out.tobytes(order='F'))

def write_nml(scf_file, bands_file, nscf_file, filename):
    """
    This writes all "facts" from the DFT and Yambo runs
    """
    scf = QExml(scf_file)
    bands = QExml(bands_file)
    nscf = QExml(nscf_file)

    prefix        = scf.prefix
    alat          = scf.alat
    cell          = scf.cell
    volume        = np.abs(np.linalg.det(cell))
    nelec         = scf.nelec
    fermi         = scf.fermi_energy 
    qe_nbnd       = bands.nbnd
    chi_nbnd      = nscf.nbnd

    qe_kgrid      = scf.k_grid
    yambo_qgrid   = nscf.k_grid

    nks           = bands.nks
    nqs           = nscf.nks

    bohr_to_angstrom = 0.529177210903



#Consider adding:
    # cell_a1_ang = {cell[0, 0]*bohr_to_angstrom:.10f} {cell[0, 1]*bohr_to_angstrom:.10f} {cell[0, 2]*bohr_to_angstrom:.10f}
    # cell_a2_ang = {cell[1, 0]*bohr_to_angstrom:.10f} {cell[1, 1]*bohr_to_angstrom:.10f} {cell[1, 2]*bohr_to_angstrom:.10f}
    # cell_a3_ang = {cell[2, 0]*bohr_to_angstrom:.10f} {cell[2, 1]*bohr_to_angstrom:.10f} {cell[2, 2]*bohr_to_angstrom:.10f}

    contents=f"""! GENERATED BY mantel_xml.py - do not edit
&structure
    alat        = {alat}
    volume      = {volume}
    cell_a1_au  = {cell[0, 0]:>23.16e} {cell[0, 1]:>23.16e} {cell[0, 2]:>23.16e}
    cell_a2_au  = {cell[1, 0]:>23.16e} {cell[1, 1]:>23.16e} {cell[1, 2]:>23.16e}
    cell_a3_au  = {cell[2, 0]:>23.16e} {cell[2, 1]:>23.16e} {cell[2, 2]:>23.16e}

/

&system
    prefix      = "{prefix}"
    nelec       = {nelec}
    scf_fermi   = {fermi}
/

&bands
    bands_nbnd  = {qe_nbnd}
    chi_nbnd    = {chi_nbnd}
/

&grids
    qe_kgrid    = "{qe_kgrid[0]} {qe_kgrid[1]} {qe_kgrid[2]}"
    yambo_qgrid = "{yambo_qgrid[0]} {yambo_qgrid[1]} {yambo_qgrid[2]}"
    nks         = {nks}
    nqs         = {nqs}
/

&provenance
    source_scf   = "{scf_file}"
    source_bands = "{bands_file}"
    source_nscf  = "{nscf_file}"
    generated    = "{datetime.now().isoformat(timespec='seconds')}"
/
"""
    with open(filename, 'w') as f:
        f.write(contents)



def main():
    parser = argparse.ArgumentParser(description="Reads the .xml files and saves important information in .nml and .bin.")
    parser.add_argument("--scf",   type=Path, default="xml/scf.xml", help="The scf xml file")
    parser.add_argument("--bands", type=Path, default="xml/bands.xml", help="The bands xml file")
    parser.add_argument("--nscf",  type=Path, default="xml/nscf.xml", help="The nscf xml file")
    args = parser.parse_args()

    info = f"""
Using:
    - scf path      : {args.scf}
    - bands path    : {args.bands}
    - nscf path     : {args.nscf}"""
    print(info)

    scf   = QExml(args.scf)
    bands = QExml(args.bands)
    nscf  = QExml(args.nscf)


    prefix        = scf.prefix
    Ef            = scf.fermi_energy
    nelec         = scf.nelec
    cell          = scf.cell
    bands_nbnd    = bands.nbnd
    band_energies = bands.eigenvalues       # (numK, nbnd)
    q_weights     = nscf.kweights           

    #Write the binary files. Use transpose to get in fortran ordering
    fortran_binary_write("band_energies.bin", band_energies.T)
    fortran_binary_write("q_weights.bin", q_weights)


    #write the namelist file 
    write_nml(args.scf, args.bands, args.nscf, f"mantel.nml")





if __name__ == "__main__":
    main()