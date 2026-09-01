import struct

import numpy as np
import pytest
from mantel_xml import QExml, fortran_binary_write, write_nml


def test_scf_scalar_properties(data):
    scf = QExml(data / "scf.xml")

    assert scf.calculation == "scf"
    assert scf.prefix == "Al"
    assert scf.nbnd == 10
    assert scf.nelec == 3
    assert scf.nks == 16
    assert scf.k_grid == [6, 6, 6]
    assert scf.converged is True
    assert scf.fermi_energy == pytest.approx(8.2781571105, abs=1e-9)


def test_scf_spin_flags_all_false(data):
    scf = QExml(data / "scf.xml")

    assert scf.lsda is False
    assert scf.noncolin is False
    assert scf.spinorbit is False
    assert scf.gamma_only is False


def test_scf_structure(data):
    scf = QExml(data / "scf.xml")

    assert scf.nat == 1
    assert scf.atomic_species == ["Al"]
    assert scf.cell.shape == (3, 3)
    assert scf.atomic_positions.shape == (1, 3)
    assert scf.alat == pytest.approx(5.360794996669213)


def test_scf_cutoffs_and_energy(data):
    scf = QExml(data / "scf.xml")

    assert scf.ecutwfc == pytest.approx(25.0)
    assert scf.ecutrho == pytest.approx(100.0)
    assert scf.etot == pytest.approx(-64.37091690245042)


def test_scf_kpoint_arrays(data):
    scf = QExml(data / "scf.xml")

    assert scf.kpoints_tpiba.shape == (16, 3)
    assert scf.kweights.shape == (16,)
    assert scf.kweights.sum() == pytest.approx(2.0)
    assert scf.occupations.shape == (16, 10)


def test_gamma_point_is_zero_in_every_basis(data):
    scf = QExml(data / "scf.xml")

    assert scf.kpoints_tpiba[0] == pytest.approx([0.0, 0.0, 0.0])
    assert scf.kpoints_cart[0] == pytest.approx([0.0, 0.0, 0.0])
    assert scf.kpoints_crys[0] == pytest.approx([0.0, 0.0, 0.0])


def test_bands_dimensions(data):
    bands = QExml(data / "bands.xml")

    assert bands.calculation == "bands"
    assert bands.nbnd == 10
    assert bands.nks == 216
    assert bands.eigenvalues.shape == (216, 10)


def test_bands_has_no_monkhorst_pack_grid(data):
    assert QExml(data / "bands.xml").k_grid is None


def test_nscf_dimensions(data):
    nscf = QExml(data / "nscf.xml")

    assert nscf.calculation == "nscf"
    assert nscf.nbnd == 50
    assert nscf.k_grid == [6, 6, 6]
    assert nscf.eigenvalues.shape == (16, 50)
    assert nscf.kweights.shape == (16,)
    assert nscf.kweights.sum() == pytest.approx(2.0)


def test_fortran_binary_write_float(tmp_path):
    array = np.arange(6.0).reshape(2, 3)
    out = tmp_path / "array.bin"

    fortran_binary_write(out, array)

    raw = out.read_bytes()
    rank, type_id, n1, n2 = struct.unpack("4i", raw[:16])
    assert (rank, type_id, n1, n2) == (2, 2, 2, 3)

    values = np.frombuffer(raw[16:], dtype=np.float64)
    assert values == pytest.approx(array.flatten(order="F"))


def test_fortran_binary_write_integer(tmp_path):
    out = tmp_path / "array.bin"

    fortran_binary_write(out, np.arange(4))

    raw = out.read_bytes()
    rank, type_id, n1 = struct.unpack("3i", raw[:12])
    assert (rank, type_id, n1) == (1, 1, 4)
    assert np.frombuffer(raw[12:], dtype=np.int32).tolist() == [0, 1, 2, 3]


def test_fortran_binary_write_complex(tmp_path):
    out = tmp_path / "array.bin"

    fortran_binary_write(out, np.array([1 + 2j, 3 + 4j]))

    raw = out.read_bytes()
    rank, type_id, n1 = struct.unpack("3i", raw[:12])
    assert (rank, type_id, n1) == (1, 3, 2)
    assert np.frombuffer(raw[12:], dtype=np.complex128).tolist() == [1 + 2j, 3 + 4j]


def test_fortran_binary_write_rejects_unsupported_dtype(tmp_path):
    with pytest.raises(ValueError):
        fortran_binary_write(tmp_path / "array.bin", np.array(["a", "b"]))


def test_write_nml_contents(data, tmp_path):
    out = tmp_path / "mantel.nml"

    write_nml(data / "scf.xml", data / "bands.xml", data / "nscf.xml", out)

    text = out.read_text()
    assert 'prefix      = "Al"' in text
    assert "nelec       = 3" in text
    assert "bands_nbnd  = 10" in text
    assert "chi_nbnd    = 50" in text
    assert 'qe_kgrid    = "6 6 6"' in text
    assert 'yambo_qgrid = "6 6 6"' in text
    assert "nks         = 216" in text
    assert "nqs         = 16" in text
