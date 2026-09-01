"""
mantel.x computes the screened interaction W(n,m,k) for each q-point, and
writes the k-point maps it used alongside it.

It starts from the wfc2bin snapshot rather than from a fresh wfc2bin run, so a
failure here is a failure in mantel.x and nothing else.
"""
from conftest import DATA, assert_bins_match, run


def test_mantel_reproduces_reference(mantel_x, workdir):
    wd = workdir("00_qe", "01_wfc2bin")
    run(mantel_x, wd)

    #> FFTs and BLAS, so the last few digits are not reproducible across builds
    assert_bins_match(wd, DATA / "02_mantel", rtol=1e-8)
