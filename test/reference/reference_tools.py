"""
Helpers the reference tests import.

These live here rather than in conftest.py because the unit tests have a
conftest.py too. When both folders run in one pytest session, only one module
can be called conftest, so `from conftest import ...` picks up whichever loaded
last.
"""
import subprocess
import sys
from pathlib import Path

import numpy as np

# parents[2] is the repo root: test/reference -> test -> repo
ROOT = Path(__file__).resolve().parents[2]
DATA = Path(__file__).resolve().parent / "data"

# fortran_binary_read parses the rank/type/shape header that array_io.f90 writes.
sys.path.insert(0, str(ROOT / "tools"))
from bin_converter import fortran_binary_read      # noqa: E402


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
