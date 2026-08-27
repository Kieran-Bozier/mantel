#


import xml.etree.ElementTree as ET
import numpy as np 


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

    
calc = QExml("Al.xml")
print(calc.root.tag)
print(calc.fermi_energy)
print(calc.nelec)
print(calc.calculation)
print(calc.lsda)
print(calc.nbnd)
print(calc.kpoints_crys)
print(calc.cell)