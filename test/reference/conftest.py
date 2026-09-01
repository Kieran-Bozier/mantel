"""
Shared setup for the reference tests.

Each test runs one binary in a scratch directory on a frozen input set, then
compares what it wrote against a frozen snapshot. The snapshots live in data/
and are rebuilt by regenerate.sh - never by the tests themselves.

Stage N's snapshot is stage N+1's input, so nothing is stored twice, and a
failure points at one binary rather than the whole pipeline.
"""
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np
import pytest

# parents[2] is the repo root: test/reference -> test -> repo
ROOT = Path(__file__).resolve().parents[2]
DATA = Path(__file__).resolve().parent / "data"

# fortran_binary_read parses the rank/type/shape header that array_io.f90 writes.
sys.path.insert(0, str(ROOT / "tools"))
from bin_converter import fortran_binary_read      # noqa: E402


def find_exe(name):
    """build/ is where make leaves the binaries, bin/ is where make install puts them."""
    for exe in (ROOT / "build" / name, ROOT / "bin" / name):
        if exe.exists():
            return exe
    pytest.skip(f"{name} not built - run `make`")


@pytest.fixture(scope="session")
def wfc2bin_x():
    return find_exe("wfc2bin.x")


@pytest.fixture(scope="session")
def mantel_x():
    return find_exe("mantel.x")


@pytest.fixture(scope="session")
def isoenergy_x():
    return find_exe("isoenergy.x")


@pytest.fixture
def workdir(tmp_path):
    """Copy the named snapshots into a scratch dir and hand back the path.

    The binaries write into the working directory, so each test needs its own.
    """
    def _stage(*snapshots):
        if not DATA.exists():
            pytest.skip(f"no reference data in {DATA}")

        for name in ("mantel.in", "mantel.nml"):
            shutil.copy(DATA / name, tmp_path)
        for snapshot in snapshots:
            shutil.copytree(DATA / snapshot, tmp_path, dirs_exist_ok=True)
        return tmp_path

    return _stage


def run(exe, workdir):
    """Run a binary on mantel.in.

    All three read the input from stdin - open_file() is called with an empty
    filename, so the -i flag the error message advertises is not wired up.
    """
    with open(workdir / "mantel.in") as stdin:
        result = subprocess.run([exe], cwd=workdir, stdin=stdin,
                                capture_output=True, text=True)

    assert result.returncode == 0, result.stdout + result.stderr
    return result


def assert_bins_match(workdir, snapshot, rtol=0.0):
    """Every .bin in the snapshot must have been reproduced in workdir.

    rtol=0 asks for a bit-exact match, which is only fair on a binary that does
    no arithmetic. Anything running FFTs or BLAS needs a tolerance: the last
    digits move with the thread count, and with FFTW against MKL.
    """
    expected = sorted(snapshot.rglob("*.bin"))
    assert expected, f"{snapshot} holds no reference files"

    for ref_file in expected:
        got_file = workdir / ref_file.relative_to(snapshot)
        assert got_file.exists(), f"{ref_file.name} was not written"

        got = fortran_binary_read(got_file)
        ref = fortran_binary_read(ref_file)
        assert got.shape == ref.shape, \
            f"{ref_file.name}: shape {got.shape}, expected {ref.shape}"

        if rtol == 0.0:
            assert np.array_equal(got, ref), f"{ref_file.name} differs"
        else:
            assert np.allclose(got, ref, rtol=rtol, atol=1e-12), \
                f"{ref_file.name}: largest deviation {np.abs(got - ref).max():.3e}"
