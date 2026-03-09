#!/usr/bin/env python3


#    Plot W_ee
#    =============

import argparse
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

def tetra_dos(dosdat_file):
    """
    Returns the tetrahedra energy_grid, dos, and Fermi energy
    """
    data = np.loadtxt(dosdat_file)
    energy_grid = data[:,0]
    dos = data[:,1]

    with open(dosdat_file, 'r') as f:
        Ef = f.readline().split()[8]
    
    return energy_grid, dos, float(Ef)



def header(emin, emax):
    print(f"==============================================")
    print(f"       W(E,E') Plotter - v1.0                ")
    print(f"==============================================")
    print(f" ")
    print(f"  Plotting W(E,E') from {emin} eV to {emax} eV")

def main():
    parser = argparse.ArgumentParser(description="Plot W(E,E') from saved numpy file")
    parser.add_argument("W_file", type=str, help="Path to the W_ee_raw.npy file")
    parser.add_argument("dos_file", type=str, help="Path to the dos_raw.npy file")
    parser.add_argument("--seed", default="", type=str, help="Sets name of the output")
    parser.add_argument("--dosdat", type=str, help="Path to the .dos.dat file which provided a better DOS and activates rescaling")
    parser.add_argument("--emin", type=float, help="Minimum energy for plotting (eV)")
    parser.add_argument("--emax", type=float, help="Maximum energy for plotting (eV)")
    args = parser.parse_args()





    W_ee = np.load(args.W_file)
    W_ee = 0.5 * (W_ee + W_ee.T)    # symmetrize
    energy_grid = np.load(args.dos_file)[:,0]
    dos = np.load(args.dos_file)[:,1]

    #set min and max energy for plotting
    if args.emin is None:
        args.emin = energy_grid[0]
    if args.emax is None:
        args.emax = energy_grid[-1]

    header(args.emin, args.emax)

    #Now get the indices for the energy range
    emin_idx = np.searchsorted(energy_grid, args.emin, side='left')
    emax_idx = np.searchsorted(energy_grid, args.emax, side='right')
    
    if args.dosdat is None:
        print("Using DOS from dos_raw.npy file")
        fig, ax = plt.subplots(2,2, figsize=(10,10))
    else:
        print("Using both DOS from dos_raw and .dos.dat file for rescaling")
        fig, ax = plt.subplots(2,3, figsize=(15,10))
        
        tetra_energy_grid, tetra_dos_values, Ef = tetra_dos(args.dosdat)
        tetra_energy_grid = tetra_energy_grid - Ef              # shift to E-Ef
        tetra_dos_values = tetra_dos_values / 2                 # per spin

        # Interpolate dos onto the energy grid used in W_ee
        tetra_dos_interpolated = np.interp(energy_grid, tetra_energy_grid, tetra_dos_values)


    # plot the standard dos
    ax[0,0].plot(energy_grid[emin_idx:emax_idx], dos[emin_idx:emax_idx], label='Gauss DOS')
    ax[0,0].set_xlabel(r"$E-E_F$ (eV)")
    ax[0,0].set_ylabel("DOS (states/eV/spin)")
    ax[0,0].set_title("Density of States")
    ax[0,0].set_xlim(args.emin, args.emax)

    if args.dosdat is not None:
        #plot the tetra dos too
        ax[0,0].plot(energy_grid[emin_idx:emax_idx], tetra_dos_interpolated[emin_idx:emax_idx], linestyle='--', label='Tetra DOS')
    ax[0,0].legend()

    # plot 1 / dos outer product. Apply mask to remove infinites
    #The .compressed gets the non-masked values
    dos_outer = np.outer(dos[emin_idx:emax_idx], dos[emin_idx:emax_idx])
    threshold = 1e-5
    dos_product_masked = np.ma.masked_less(dos_outer, threshold)
    inv_dos_map = 1 / dos_product_masked
    vmax = np.percentile(inv_dos_map.compressed(), 98)
    im1 = ax[0,1].imshow(
        inv_dos_map,
        origin='lower',
        extent=(args.emin, args.emax, args.emin, args.emax),
        aspect='equal',
        vmin=0,
        vmax=vmax,
        interpolation='nearest'
    )
    ax[0,1].set_xlabel(r"$E-E_F$ (eV)")
    ax[0,1].set_ylabel(r"$E'-E_F$ (eV)")
    ax[0,1].set_title(r"$\frac{1}{DOS(E) \cdot DOS(E')}$")


    #if tetra dos given, plot 1 / tetra dos outer product
    if args.dosdat is not None:
        tetra_dos_outer = np.outer(tetra_dos_interpolated[emin_idx: emax_idx], tetra_dos_interpolated[emin_idx:emax_idx])
        tetra_dos_product_masked = np.ma.masked_less(tetra_dos_outer, threshold)
        inv_tetra_dos_map = 1 / tetra_dos_product_masked
        vmax = np.percentile(inv_tetra_dos_map.compressed(), 98)
        im_tetra = ax[0,2].imshow(
            inv_tetra_dos_map,
            origin='lower',
            extent=(args.emin, args.emax, args.emin, args.emax),
            aspect='equal',
            vmin=0,
            vmax=vmax,
            interpolation='nearest'
        )
        ax[0,2].set_xlabel(r"$E-E_F$ (eV)")
        ax[0,2].set_ylabel(r"$E'-E_F$ (eV)")
        ax[0,2].set_title(r"$\frac{1}{TetraDOS(E) \cdot TetraDOS(E')}$")

    ####################
    # plot W(E,E')
    vmax = np.percentile(W_ee[emin_idx:emax_idx , emin_idx:emax_idx], 98)
    im2 = ax[1,0].imshow(
        W_ee[emin_idx:emax_idx , emin_idx:emax_idx],
        origin='lower',
        extent=(args.emin, args.emax, args.emin, args.emax),
        aspect='equal',
        vmin=0,
        vmax=vmax,
        interpolation='nearest'
    )
    ax[1,0].set_xlabel(r"$E-E_F$ (eV)")
    ax[1,0].set_ylabel(r"$E'-E_F$ (eV)")
    ax[1,0].set_title(r"$W(E,E')$ raw (eV)")

    # plot W(E,E') * (1 / dos outer product)
    # Inverse dos map alread right size
    W_weighted = W_ee[emin_idx:emax_idx , emin_idx:emax_idx] * inv_dos_map
    vmax = np.percentile(W_weighted.compressed(), 98)
    im3 = ax[1,1].imshow(
        W_weighted,
        origin='lower',
        extent=(args.emin, args.emax, args.emin, args.emax),
        aspect='equal',
        vmin=0,
        vmax=vmax,
        interpolation='nearest'
    )
    ax[1,1].set_xlabel(r"$E-E_F$ (eV)")
    ax[1,1].set_ylabel(r"$E'-E_F$ (eV)")
    ax[1,1].set_title(r"$W(E,E') \cdot \frac{1}{DOS(E) \cdot DOS(E')}$")
    ####    colourbar    ####
    cbar = plt.colorbar(im3, ax=ax[1,1])
    


    # if tetra dos given, plot W(E,E') * (1 / tetra dos outer product)
    if args.dosdat is not None:
        W_tetra_weighted = W_ee[emin_idx:emax_idx , emin_idx:emax_idx] * inv_tetra_dos_map
        vmax = np.percentile(W_tetra_weighted.compressed(), 98)
        im_tetra_W = ax[1,2].imshow(
            W_tetra_weighted,
            origin='lower',
            extent=(args.emin, args.emax, args.emin, args.emax),
            aspect='equal',
            vmin=0,
            vmax=vmax,
            interpolation='nearest'
        )
        ax[1,2].set_xlabel(r"$E-E_F$ (eV)")
        ax[1,2].set_ylabel(r"$E'-E_F$ (eV)")
        ax[1,2].set_title(r"$W(E,E') \cdot \frac{1}{TetraDOS(E) \cdot TetraDOS(E')}$")
        cbar = plt.colorbar(im3, ax=ax[1,2])



    plt.savefig(f"{args.seed}_W_ee_plots.png", dpi=300)

    #Now also plot the diagonal
    fig, ax2 = plt.subplots(figsize=(8,6))
    ax2.set_xlim(float(args.emin), float(args.emax))
    if args.dosdat:
        diag_W = np.diagonal(W_tetra_weighted)
        ax2.plot(energy_grid[emin_idx:emax_idx], diag_W, label="tetrahedra")
    ax2.set_xlabel(r"$E-E_F$ (eV)")
    ax2.set_ylabel(r"$W(E,E)$ (eV)")
    ax2.set_title("Diagonal of W(E,E')")

    diag_W = np.diagonal(W_weighted)
    ax2.set_ylim(top=np.max(diag_W) * 1.1, bottom=0)
    ax2.plot(energy_grid[emin_idx:emax_idx], diag_W, linestyle='--', label="gaussian")

    ax2.legend()

    #save the data
    np.savetxt(f"{args.seed}_W_ee_diagonal.dat", np.column_stack((energy_grid[emin_idx:emax_idx], diag_W)))
    print(f"Plotting x-data range: {energy_grid[emin_idx:emax_idx].min()} to {energy_grid[emin_idx:emax_idx].max()}")
    print(f"Setting x-lim to: {args.emin} to {args.emax}")

    plt.savefig(f"{args.seed}_W_ee_diagonal.png", dpi=300)


    # Do a bespoke plot of just the W_ee final result
    fig, ax3 = plt.subplots(figsize=(8,6))
    vmax = np.percentile(W_weighted.compressed(), 98)
    im_final = ax3.imshow(
        W_weighted,
        origin='lower',
        extent=(args.emin, args.emax, args.emin, args.emax),
        aspect='equal',
        vmin=0,
        vmax=vmax,
        interpolation='nearest'
    )
    ax3.set_xlabel(r"$E-E_F$ (eV)")
    ax3.set_ylabel(r"$E'-E_F$ (eV)")
    ax3.set_title(r"W(E,E')")
    cbar = plt.colorbar(im_final, ax=ax3)
    plt.savefig(f"{args.seed}_W_ee_final.pdf", dpi=300)

    
    


if __name__ == "__main__":
    main()