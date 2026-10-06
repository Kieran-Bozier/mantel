#!/usr/bin/env python3

#               Plotting
#               ========
#       Script to plot the W_ee.dat         
#       and dos.dat from isoenergy.x

import argparse

import numpy as np 
import matplotlib.pyplot as plt

def W_get_sigma(filename):
    """
    Returns the Gaussian smearing used for W_ee
    """
    with open(filename, 'r') as f1:
        line = f1.readline()
        sigma = float(line.split()[-1])
    return (sigma)

def dos_get_sigma(filename):
    """
    Returns the Gaussian smearing used for DOS
    """
    with open(filename, 'r') as f2:
        lines = f2.readlines()
        sigma = float(lines[1].split()[-2])
    return (sigma)


def load_gnuplot_grid(filename):
    """
    Return numpy meshgrid style arrays
    """

    # Get block size from first blank line
    with open(filename) as f:
        block_size = 0
        for line in f:
            if not line.strip():
                # Only a blank line ends the block, not a comment
                if block_size > 0:
                    break
            elif not line.startswith('#'):
                block_size += 1

    if block_size == 0:
        raise ValueError(f"No data rows found in {filename}")

    data = np.loadtxt(filename)
    if len(data) % block_size != 0:
        raise ValueError(f"{filename} has {len(data)} data rows, which is not a "
                         f"whole number of {block_size}-row blocks")
    n_blocks = len(data) // block_size

    X = data[:, 0].reshape(n_blocks, block_size)
    Y = data[:, 1].reshape(n_blocks, block_size)
    W = data[:, 2].reshape(n_blocks, block_size)

    return X,Y,W


def dos_plot(ax, dos_dat):
    data = np.loadtxt(dos_dat)

    ax.plot(data[:,0] , data[:,1])
    ax.set_xlabel(r"$\varepsilon - \varepsilon_{F}$ (eV)")
    ax.set_ylabel(f"DOS (states/eV/spin)")

    ax.axvline(x=0, color='k', linestyle='--', linewidth=0.5)
    mask = data[:,0] < 0
    ax.fill_between(data[mask, 0], data[mask, 1], alpha=0.3)    
    ax.set_ylim(bottom=0)
    return ax


def diag_plot(ax, Weep_file, dos_file):
    dos_data = np.loadtxt(dos_file)
    dos_energy = dos_data[:,0]
    dos = dos_data[:,1]

    X,Y,W = load_gnuplot_grid(Weep_file)

    #Confirm W is square
    if (W.shape[0] != W.shape[1]):
        print("Error: W is not square, dimensions: ", W.shape )
        return None 
    
    W_diag = np.diag(W)
    W_energy = X[:,0]
    line1, = ax.plot(W_energy, W_diag, label=r"$W(\varepsilon, \varepsilon)$")
    ax.set_ylim(bottom=0)
    ax.set_ylabel(r"$W(\varepsilon, \varepsilon)$")


    if W_energy.size != dos_energy.size:
        print(f"DOS has {dos_energy.size} energies but W has {W_energy.size}")
        return None 
    

    ax2 = ax.twinx()
    line2, = ax2.plot(W_energy, W_diag*dos, label=r"$\mu(\varepsilon)$", color="#c0392b")
    ax2.set_ylim(bottom=0)
    ax2.set_ylabel(r"$\mu$")

    ax.set_xlabel(r"$\varepsilon - \varepsilon_{F}$ (eV)")
    ax.legend(handles=[line1, line2], loc='lower center', bbox_to_anchor=(0.5, 1.02), ncol=2)





def main():
    parser = argparse.ArgumentParser(description="Plots W_ee.dat and dos_dat files")
    parser.add_argument("-w", "--Weep", default="W_ee.dat", help="W_ee file")
    parser.add_argument("-d", "--dos", default="dos.dat", help="DOS file")
    args = parser.parse_args()

    try:
        import scienceplots
        plt.style.use(['science'])
    except ImportError:
        print("Couldn't find scienceplots. Using matplotlib defaults")


    Weep_file = args.Weep
    dos_file = args.dos

    # Check same smearing used
    W_ee_sigma = W_get_sigma(Weep_file)
    try:
        dos_sigma = dos_get_sigma(dos_file)
    except FileNotFoundError:
        print(f"Couldn't find {dos_file}. Skipping the smearing consistency check")
    else:
        if (np.abs(W_ee_sigma - dos_sigma) > 1.0e-6):
            print(f"Warning: Smearing used in W_ee ({W_ee_sigma} eV) does not match that used in DOS ({dos_sigma} eV)")
    
    X,Y,W = load_gnuplot_grid(Weep_file)

    fig, ax_wee = plt.subplots(figsize=(3.2,3.2))
    ax_wee.imshow(W, origin='lower', extent=[Y.min(), Y.max(), X.min(), X.max()])
    ax_wee.set_ylabel(r"$\varepsilon$ (eV)")
    ax_wee.set_xlabel(r"$\varepsilon$ (eV)")
    plt.savefig("W_ee.pdf")

    fig, ax_dos = plt.subplots(figsize=(3.2, 1.6))
    ax_dos = dos_plot(ax_dos, dos_file)
    plt.savefig("gauss_dos.pdf")

    fig, ax_diag = plt.subplots(figsize=(3.2, 1.6))
    ax_diag = diag_plot(ax_diag, Weep_file, dos_file)

    plt.show()








if __name__ == "__main__":
    main()
