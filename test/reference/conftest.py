"""
Shared setup for the reference tests.

Each test runs one binary in a scratch directory on a frozen input set, then
compares what it wrote against a frozen snapshot. The snapshots live in data/
and are never written by the tests themselves.

Stage N's snapshot is stage N+1's input, so nothing is stored twice, and a
failure points at one binary rather than the whole pipeline.

Only fixtures belong here. Anything a test imports by name goes in
reference_tools.py - see the note at the top of that file.
"""
import shutil

import pytest

# Keep pytest's detailed assert messages inside the helpers, as it gives them
# in test files and here. Must be registered before the module is imported.
pytest.register_assert_rewrite("reference_tools")
from reference_tools import DATA, ROOT     # noqa: E402


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
