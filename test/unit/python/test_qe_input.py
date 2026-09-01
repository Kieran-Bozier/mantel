import argparse

import pytest
from qe_input import build_bands, build_nscf_yambo, build_scf_yambo
from qe_input import kpoints_crystal, split_kgrid, kpoints_automatic
from qe_input import set_key, replace_kpoints

def test_kpoints_crystal_grid_size():
    """A 2x2x2 crystal grid is 8 points with weights summing to 1."""
    lines = kpoints_crystal(2, 2, 2)

    assert lines[0] == "K_POINTS crystal\n"
    assert lines[1] == "8\n"
    assert len(lines) == 2 + 8          # two header lines, then one per point

    weights = [float(line.split()[3]) for line in lines[2:]]
    assert sum(weights) == pytest.approx(1.0)


def test_build_bands_rewrites_calculation_and_kpoints(Al_scf_lines):
    out = build_bands(Al_scf_lines, nbnd=20, kgrid=[2, 2, 2])
    text = "".join(out)

    assert "calculation = 'bands'" in text
    assert "nbnd = 20" in text
    assert "K_POINTS crystal" in text
    assert "K_POINTS automatic" not in text  


def test_kpoints_automatic():
    lines = kpoints_automatic(2,2,2)
    assert len(lines) == 2
    assert lines[0] == "K_POINTS automatic\n"
    assert lines[1] == "  2 2 2 0 0 0\n"


def test_split_grid():
    grid = split_kgrid("4 4 4")
    assert len(grid) == 3
    assert grid[0] == 4
    assert grid[1] == 4
    assert grid[2] == 4

def test_split_kgrid_too_few():
    with pytest.raises(argparse.ArgumentTypeError):
        split_kgrid("4 4")

def test_set_key_replaces_existing_key():
    lines = ["&control\n", "  calculation='scf'\n", "/\n"]
    out = set_key(lines, "control", "calculation", "'bands'")

    assert out == ["&control\n", "  calculation = 'bands'\n", "/\n"]


def test_set_key_inserts_missing_key_after_header():
    lines = ["&system\n", "  nat = 1\n", "/\n"]
    out = set_key(lines, "system", "nbnd", 20)

    assert out[1] == "  nbnd = 20\n"
    assert "  nat = 1\n" in out          # the existing key survives


def test_set_key_missing_group_raises():
    with pytest.raises(ValueError):
        set_key(["&control\n", "/\n"], "system", "nbnd", 20)


# --- replace_kpoints ----------------------------------------------------
# Nb.scf.in has ATOMIC_POSITIONS after K_POINTS. If the card-scanning in
# replace_kpoints ever breaks, this is the test that catches it - the
# positions would be swallowed and QE would fail a long way downstream.
def test_replace_kpoints_preserves_following_cards(Nb_scf_lines):
    out = replace_kpoints(Nb_scf_lines, kpoints_crystal(2, 2, 2))
    text = "".join(out)

    assert "K_POINTS crystal" in text
    assert "K_POINTS automatic" not in text
    assert "6  6  6  0  0  0" not in text     # old grid line is gone
    assert "ATOMIC_POSITIONS {crystal}" in text
    assert "CELL_PARAMETERS (angstrom)" in text


def test_replace_kpoints_missing_card_raises():
    with pytest.raises(ValueError):
        replace_kpoints(["&control\n", "/\n"], kpoints_automatic(2, 2, 2))


# --- the build_* entry points -------------------------------------------
def test_build_bands_writes_one_line_per_kpoint(Al_scf_lines):
    out = build_bands(Al_scf_lines, nbnd=20, kgrid=[3, 3, 3])

    assert "K_POINTS crystal\n27\n" in "".join(out)


def test_build_nscf_yambo_uses_automatic_grid(Al_scf_lines):
    out = build_nscf_yambo(Al_scf_lines, nbnd=50, kgrid=[6, 6, 6])
    text = "".join(out)

    assert "calculation = 'nscf'" in text
    assert "nbnd = 50" in text
    assert "force_symmorphic = .true." in text
    assert "K_POINTS automatic" in text
    assert "K_POINTS crystal" not in text     # nscf differs from bands here


def test_build_scf_yambo_applies_overrides(Al_scf_lines):
    out = build_scf_yambo(Al_scf_lines, nbnd=30, kgrid=[4, 4, 4])
    text = "".join(out)

    assert "  4 4 4 0 0 0\n" in text
    assert "nbnd = 30" in text
    assert "force_symmorphic = .true." in text


def test_build_scf_yambo_defaults_leave_input_alone(Al_scf_lines):
    """With no nbnd and no kgrid, force_symmorphic is the only change."""
    out = build_scf_yambo(Al_scf_lines, nbnd=None, kgrid=None)
    text = "".join(out)

    assert "force_symmorphic = .true." in text
    assert "nbnd=10" in text                  # original spelling, untouched
    assert "calculation='scf'" in text
    assert "K_POINTS automatic" in text
    assert "6 6 6" in text
