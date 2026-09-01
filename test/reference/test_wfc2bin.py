"""
wfc2bin.x maps the QE wavefunctions onto a fixed G cube and records the
k-points. It does no arithmetic, so the output should match bit for bit.
"""
from conftest import DATA, assert_bins_match, run


def test_wfc2bin_reproduces_reference(wfc2bin_x, workdir):
    wd = workdir("00_qe")
    run(wfc2bin_x, wd)

    assert_bins_match(wd, DATA / "01_wfc2bin")
