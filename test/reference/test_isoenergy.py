"""
isoenergy.x averages W over the isoenergy surfaces to give W(e,e').
"""
import numpy as np
from conftest import DATA, run


def test_isoenergy_reproduces_reference(isoenergy_x, workdir):
    wd = workdir("00_qe", "02_mantel")
    run(isoenergy_x, wd)

    #> loadtxt skips the header and the blank lines between blocks, leaving
    #> the three columns: e, e', W(e,e')
    got = np.loadtxt(wd / "W_ee.dat")
    ref = np.loadtxt(DATA / "03_isoenergy" / "W_ee.dat")

    assert got.shape == ref.shape, f"shape {got.shape}, expected {ref.shape}"
    assert np.allclose(got, ref, rtol=1e-8, atol=1e-12), \
        f"largest deviation {np.abs(got - ref).max():.3e}"


def test_W_ee_is_symmetric(isoenergy_x, workdir):
    """W(e,e') = W(e',e) by construction, whatever the reference happens to say.

    Only to about 1e-7 though: the two halves accumulate over k in different
    orders, and dividing by dos(ie)*dos(je) amplifies that wherever the DOS
    approaches the 1e-5 cutoff. The check is here to catch the mapping being
    wrong, not to police the last digits.
    """
    wd = workdir("00_qe", "02_mantel")
    run(isoenergy_x, wd)

    columns = np.loadtxt(wd / "W_ee.dat")
    numE = int(round(np.sqrt(len(columns))))
    W_ee = columns[:, 2].reshape(numE, numE)

    assert np.allclose(W_ee, W_ee.T, rtol=1e-6, atol=1e-6), \
        f"largest asymmetry {np.abs(W_ee - W_ee.T).max():.3e}"
