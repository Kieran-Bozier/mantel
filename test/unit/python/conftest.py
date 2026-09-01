"""
Shared setup for the Python unit tests.

pytest imports this file automatically before collecting any test_*.py in
this directory, so anything defined here is available without importing it.
"""
import sys
from pathlib import Path

import pytest

# Make bin/ importable so tests can do `from qe_input import ...`.
# parents[3] is the repo root: test/unit/python -> test/unit -> test -> repo
BIN = Path(__file__).resolve().parents[3] / "bin"
sys.path.insert(0, str(BIN))

# Reference inputs live next to this file, so tests work from any directory.
DATA = Path(__file__).resolve().parent / "data"


@pytest.fixture
def data():
    """Path to test/unit/python/data. Ask for it by adding `data` as an argument."""
    return DATA


@pytest.fixture
def Al_scf_lines():
    """The Al scf input, read as a list of lines - the shape qe_input.py works on."""
    return (DATA / "Al.scf.in").read_text().splitlines(keepends=True)

@pytest.fixture
def Nb_scf_lines():
    """The Nb scf input. Unlike Al, this one has a card *after* K_POINTS."""
    return (DATA / "Nb.scf.in").read_text().splitlines(keepends=True)
