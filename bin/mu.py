#!/usr/bin/env python3

###################################################
#       This script will produce a list of        #
#       mu values for each choice of sigma,       #
#       analagously to lambda.x and a2tc          #
###################################################
import numpy as np
import argparse
import time
from tqdm import tqdm

def readBandEnergies(bands_file):
    """
    Reads the band energies from a QE .bands.out file and returns them
    as a numpy array of shape (num_kpoints, num_bands). 

    REQUIRES that the calcualtion was performed with verbosity='high',
    as otherwise not all band energies are printed
    """
    with open(bands_file, 'r') as f:
        lines = f.readlines()
    band_energies = []
    record = False
    current_band = []
    for line in lines:
        if "End of band structure calculation" in line: record = True; continue
        if "Writing all to output data" in line: record = False; continue
        if record:
            if "k =" in line:
                if current_band: band_energies.append(current_band); current_band = []
                continue
            if line.strip() == "": continue
            energies = [float(e) for e in line.strip().split()]
            current_band.extend(energies)
    if current_band: band_energies.append(current_band)
    return np.array(band_energies)

def get_q_weights(yambo_nscf_out):
    with open(yambo_nscf_out, 'r') as f:
        lines = f.readlines()
    q_weights = []
    record = False
    for line in lines:
        if "cart. coord. in units 2pi/alat" in line: record = True; continue
        if record:
            if line.strip() == "": record = False; break
            else: w_q = line.split("=")[-1].strip("\n"); q_weights.append(float(w_q))
    return np.array(q_weights)


def calculate_gaussian_Nf(energy_array, sigma):
    """
    Given an energy array where 0 is the Fermi energy (eV), and 
    a value of sigma (eV), calculate the density of states 
    at the Fermi energy using a Gaussian smearing method.

    The function assumes each point has uniform weight 
    (i.e. we are working with the full BZ)

    We will use the QE definition of the Gaussian smearing, which is given by:
    \\delta(x) -> 1 / sigma*sqrt(pi) * exp(-x^2 / sigma^2)

    Inputs:
        energy_array    Shape (num_kpoints, num_Bands)
        - A numpy array of energies (eV) where 0 is the Fermi energy.

        sigma
        - The smearing width (eV) to use in the Gaussian smearing method.
    
    Outputs:
        Nf
        - The density of states at the Fermi energy (states/eV/spin) calculated using 
          the Gaussian smearing method.
    """
    num_kpoints, num_bands = energy_array.shape
    normalization_factor = 1 / (sigma * np.sqrt(np.pi))

    gaussian = normalization_factor * np.exp(- (energy_array / sigma) ** 2)
    Nf = np.sum(gaussian) / num_kpoints
    return Nf



def calculate_W00(sigmas, E_kn, q_weights):
    """
    Compute W(0,0) — the screened Coulomb matrix element at the Fermi level —
    for each value of sigma.

    For each sigma, the Gaussian weight at E=0 is:
        G_0[k, n] = (1/Nk) * (1/(sigma*sqrt(pi))) * exp(-(E_kn[k,n]/sigma)^2)

    W(0,0) = sum_q  (w_q/W_tot) * Nk * sum_{k,n,m} G_0[k,n] * W[k,n,m] * G_0[k',m]  (eV)

    Inputs:
        sigmas        array of smearing widths (eV), shape (num_sigmas,)
        E_kn          band energies relative to Ef, shape (numK, numN)
        q_weights     BZ weights, shape (num_q,)

    Returns:
        W_00          shape (num_sigmas,), W(0,0) in eV for each sigma
    """
    numK, numN = E_kn.shape
    total_w = np.sum(q_weights)
    num_q = len(q_weights)

    # G_0[s, k, n] = (1/Nk) * (1/(sigma*sqrt(pi))) * exp(-(E_kn/sigma)^2)
    G_0 = np.stack([
        (1.0 / numK) * (1.0 / (s * np.sqrt(np.pi))) * np.exp(-(E_kn / s) ** 2)
        for s in sigmas
    ]).astype(np.float32)   # shape (num_sigmas, numK, numN)

    W_00 = np.zeros(len(sigmas), dtype=np.float64)

    #tqdm is just here to give a nice progress bar
    for iq in tqdm(range(num_q), desc="q-points"):
        wq = q_weights[iq] / total_w

        ikp_idx = np.load(f"ikp_iq{iq+1}.npy")
        W_real  = np.real(np.load(f"W_iq{iq+1}.npy")).astype(np.float32)
        # W_real shape: (numK, numN, numM)

        # Safety check: convert ikp_idx to zero-indexed if needed
        if np.min(ikp_idx) == 0:
            if iq == 0: print("ikp_idx appears to be zero indexed")
        elif np.min(ikp_idx) == 1:
            if iq == 0: print("ikp_idx appears to be one indexed, converting to zero indexed")
            ikp_idx = ikp_idx - 1
        else:
            raise ValueError(f"ikp_idx has unexpected minimum value {np.min(ikp_idx)}")

        # G_0 at k' = k+q: shape (num_sigmas, numK, numM)
        # Same array, just scrambled according to ikp_idx
        G_0_ikp = G_0[:, ikp_idx, :]

        # Contract over k, n, m -> scalar per sigma: 'skn, knm, skm -> s'
        contrib = np.einsum('skn, knm, skm -> s', G_0, W_real, G_0_ikp, optimize=True)

        # numK restores the one surviving 1/Nk; convert Hartree -> eV
        W_00 += wq * contrib * numK * 27.211386
    return W_00




def main():
    parser = argparse.ArgumentParser(description="Calculate mu values for different values of sigma")
    parser.add_argument("yambo_nscf_out", type=str, help="The yambo nscf output file containing the q-point weightds")
    parser.add_argument("bands", type=str, help="The QE .bands.out file containing the band energies. REQUIRES that the calcualtion was performed with verbosity='high', as otherwise not all band energies are printed")
    parser.add_argument("Ef", type=float, help="The Fermi energy (eV)")
    parser.add_argument("minSigma", type=float, help="The minimum value of sigma (eV) to consider")
    parser.add_argument("maxSigma", type=float, help="The maximum value of sigma (eV) to consider")
    parser.add_argument("numSigma", type=int, help="The number of sigma values to consider between minSigma and maxSigma")
    parser.add_argument("--log", action='store_true', help="Whether to use logarithmically spaced sigma values (default: False, i.e. linearly spaced)")
    parser.add_argument("--nmin", type=int, default=1, help="Minimum band index of band.out to consider")
    args = parser.parse_args()

    #arguments
    start_time = time.time()
    yambo_nscf_out = args.yambo_nscf_out
    bands_file = args.bands
    Ef = args.Ef
    minSigma = args.minSigma
    maxSigma = args.maxSigma
    numSigma = args.numSigma
    log = args.log
    n_min = args.nmin

    # Define the sigma values to consider
    if log:
        sigma_values = np.logspace(np.log10(minSigma), np.log10(maxSigma), numSigma)
    else:
        sigma_values = np.linspace(minSigma, maxSigma, numSigma)
    
    # Read the band energies and q-point weights
    band_energies = readBandEnergies(bands_file)
    q_weights = get_q_weights(yambo_nscf_out)
    num_kpoints = band_energies.shape[0]

    # Read in k and n indices
    ik_idx = np.load("ik.npy").astype(int)                  # k indices
    in_idx = np.loadtxt("in.txt", dtype=int)                # n indices
    ##############          Safety checks          ##############
    #num K points in ik_idx should match num k points in band_energies
    if len(ik_idx) != num_kpoints:
        raise ValueError(f"Number of k-points in ik.npy ({len(ik_idx)}) does not match number of k-points in bands.out ({num_kpoints})")

    if np.min(ik_idx) == 0:
        print(f"ik_idx appears to be zero indexed")
    elif np.min(ik_idx) == 1:
        print(f"ik_idx appears to be one indexed, converting to zero indexed")
        ik_idx -= 1

    if np.min(in_idx) == 0:
        print(f"in_idx appears to be zero indexed")
    elif np.min(in_idx) == 1:
        print(f"in_idx appears to be one indexed, converting to zero indexed")
        in_idx -= 1
    ################################################################

    W_00_all = calculate_W00(sigma_values, band_energies[ik_idx[:, None], in_idx[None, :] + n_min - 1] - Ef, q_weights)
    Nf_all = np.array([calculate_gaussian_Nf(band_energies - Ef, s) for s in sigma_values])
    mu_values = W_00_all * Nf_all

    # Print table to stdout
    print("")
    print(f"  {'sigma (eV)':>12}  {'N_F (states/eV/spin)':>20}  {'W(0,0) (eV)':>14}  {'mu':>10}")
    print("  " + "-" * 62)
    for s, nf, w00, mu in zip(sigma_values, Nf_all, W_00_all, mu_values):
        print(f"  {s:>12.4f}  {nf:>20.6f}  {w00:>14.6f}  {mu:>10.6f}")
    print("")

    # Write to file
    out_file = "mu_results.dat"
    with open(out_file, 'w') as f:
        f.write(f"# Ef = {Ef} eV\n")
        f.write(f"# {'sigma (eV)':>12}  {'N_F (states/eV/spin)':>20}  {'W(0,0) (eV)':>14}  {'mu':>10}\n")
        for s, nf, w00, mu in zip(sigma_values, Nf_all, W_00_all, mu_values):
            f.write(f"  {s:>12.4f}  {nf:>20.6f}  {w00:>14.6f}  {mu:>10.6f}\n")
    print(f"Results written to {out_file}")





