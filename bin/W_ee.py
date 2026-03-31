#!/usr/bin/env python3

#W_ee.py
import numpy as np 
import argparse
import re
from multiprocessing import Pool, RawArray
from functools import partial
from tqdm import tqdm
import time

#Global variable to hold shared memory reference
var_dict = {}

def save_Weep(W_raw, dos_raw, sigma):
    """
    This function saves the true W(E,E') after division by the dos**2.
    It is written in the "gnuplot" format, the same format as the IsoME example
    The first column is the energy E, the second column is the energy E', and the third column is W(E,E'). 

    Inputs:
        W_raw: the raw W(E,E') matrix, shape (numE, numE)
        dos_raw: the raw DOS data, shape (numE, 2), where the first column is energy and the second column is dos
    """
    energy_grid = dos_raw[:,0]
    dos = dos_raw[:,1]

    # divide through by dos**2, using same logic as plotting script
    threshold = 1e-5
    dos_outer = np.outer(dos, dos)
    dos_product_masked = np.ma.masked_less(dos_outer, threshold)
    inv_dos_map = 1 / dos_product_masked
    W_ee = W_raw * inv_dos_map

    #Any bits that fail the mask are set to zero
    W_ee_vector = W_ee.filled(0.0).flatten()

    # Build e and e'
    X, Y = np.meshgrid(energy_grid, energy_grid, indexing='ij')
    x = X.flatten()
    y = Y.flatten()

    #Check that shapes match
    if not (x.shape == y.shape == W_ee_vector.shape):
        raise ValueError(f"Shape mismatch: x shape {x.shape}, y shape {y.shape}, W_ee_vector shape {W_ee_vector.shape}")

    #Writing newline at each x is a little tricky
    prev_x = None
    with open("W_ee.dat", 'w') as f:
        f.write(f"# Fermi energy [eV] = 0.  Smearing width (sigma) [eV] = {sigma}\n")
        f.write(f"# energy (e) [eV]      energy (e') [eV]       W(e,e') [eV]\n")

        #gnuplot expects the data to be in blocks separated by newlines, where each block corresponds to a unique x value (energy e).
        for row in range(len(W_ee_vector)):
            current_x = x[row]
            if prev_x is not None and abs(current_x - prev_x) > 1e-9:
                f.write("\n")
            f.write(f"{x[row]: .10E}     {y[row]: .10E}     {W_ee_vector[row]:.10E}\n")
            prev_x = current_x






def readBandEnergies3(bands_file):
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
            # The regex looks for an optional +/-, followed by digits and a decimal point
            energies = [float(e) for e in re.findall(r"[-+]?\d*\.\d+|\d+", line)]   
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


def init_worker(shared_G_shape, shared_G_raw):
    var_dict['G_all_shape'] = shared_G_shape
    var_dict['G_all'] = np.frombuffer(shared_G_raw, dtype=np.float32).reshape(shared_G_shape)


def process_q_point(iq, q_weights, total_q_weight, num_kpoints, num_bands, n_min, numE, ik_arr, in_arr):
    """
    Worker function to calcualte the iq's contribution
    to W_ee_final_map
    """
    wq = (q_weights[iq] / total_q_weight).astype(np.float32)
    G_all = var_dict['G_all'] 

    ikp_file = f"ikp_iq{iq+1}.npy"
    im_file = f"in.txt"
    W_file = f"W_iq{iq+1}.npy"

    ikp_idx = np.load(ikp_file)    
    im_idx = np.loadtxt(im_file, dtype=int)  

    ####################### SAFETY CHECKS  ##################################
    if np.min(ikp_idx) == 0:
        if iq == 0:
            print(f"ikp_idx appears to be zero indexed")
    elif np.min(ikp_idx) == 1:
        if iq == 0:
            print(f"ikp_idx appears to be one indexed, converting to zero indexed")
        ikp_idx = ikp_idx - 1
    else:
        raise ValueError(f"ikp_idx has unexpected minimum value {np.min(ikp_idx)}")
    
    if np.min(im_idx) == 0: 
        if iq == 0:
            print(f"im_idx appears to be zero indexed")
    elif np.min(im_idx) == 1:
        if iq == 0:
            print(f"im_idx appears to be one indexed, converting to zero indexed")
        im_idx = im_idx - 1
    else:
        raise ValueError(f"im_idx has unexpected minimum value {np.min(im_idx)}")
    #############################################################################
    



    #load W
    W_nm_k = np.load(W_file)
    if W_nm_k.shape != (num_kpoints, num_bands, num_bands):
        raise ValueError(f"W shape {W_nm_k.shape} does not match expected shape {(num_kpoints, num_bands, num_bands)}")
    W_real = np.real(W_nm_k)

    #Accumulator for this iq
    W_map_iq = np.zeros((numE, numE), dtype=np.float32)


    batch_size=512
    n_indices = in_arr + n_min - 1
    m_indices = im_idx + n_min - 1  

    for start in range(0, num_kpoints, batch_size):
        end = min(start + batch_size, num_kpoints)
        
        ik_batch = ik_arr[start:end]
        ikp_batch = ikp_idx[start:end] 

        #First slices extracts out the relevant k-points, second slice extracts the relevant n or m indices
        G1_batch = G_all[:,ik_batch,:][:,:,:]   
        G2_batch = G_all[:,ikp_batch,:][:,:,:]

        W_batch = W_real[start:end,:,:]

        W_map_iq += np.einsum('ebn, bnm, fbm -> ef', G1_batch, W_batch, G2_batch, optimize=True)

    #Working in Hartrees, so convert to eV
    return wq * W_map_iq * 27.211386


def header():
    print("=======================================")
    print("   Fast W(E,E') calculator - v1.0    ")
    print("=======================================")
    print("")

def print_setup(emin, emax, numE, sigma, Ef):
    print(f"Calculation setup:")
    print(f"-------------------")
    print(f"  Energy minimum: {emin} eV")
    print(f"  Energy maximum: {emax} eV")
    print(f"  Num energy points: {numE}")
    print(f"  Sigma value: {sigma} eV")
    print(f"  Fermi energy: {Ef} eV")
    print(f"")


def main():
    #argparser
    parser = argparse.ArgumentParser(description="Calculate full 2D W(E, E')")
    parser.add_argument("yambo_nscf_out", type=str, help="The yambo nscf output file containing the q-point weights")
    parser.add_argument("bands", type=str, help="bands.out file")
    parser.add_argument("Ef", type=float, help="Set the Fermi energy (eV)")
    parser.add_argument("--sigma", type=float, default=0.1, help="Sigma value in eV (default 0.1 eV)")
    parser.add_argument("--test", action='store_true', help="Run in test mode")
    parser.add_argument("--numE", type=int, default=2000, help="Number of energy points (default 2000)")
    parser.add_argument("--minE", type=float, default=-12.0, help="Minimum energy value (eV) (default -12 eV)")
    parser.add_argument("--maxE", type=float, default=35.0, help="Maximum energy value (eV) (default 35 eV)")
    parser.add_argument("--nmin", type=int, default=1, help="Minimum band index to consider (default 1)")
    parser.add_argument("--ncores", type=int, default=32, help="Number of parallel processes (default 32)")
    args = parser.parse_args()

    #arguments
    start_time = time.time()
    bands_out_file = args.bands
    yambo_nscf_out = args.yambo_nscf_out
    Ef = args.Ef
    sigma = args.sigma
    numE = args.numE
    emin = args.minE
    emax = args.maxE
    n_min = args.nmin


    #Define energy grid 
    energy_grid = np.linspace(emin, emax, numE)
    print_setup(emin, emax, numE, sigma, Ef)


    #load global data
    if args.test:
        band_energies = np.loadtxt("band_energies.txt")
    else:
        band_energies = readBandEnergies3(bands_out_file).astype(np.float64)  
 
    num_kpoints = band_energies.shape[0]
    print(f"Reading bands file. Shape is: {band_energies.shape}")
    if args.test:
        q_weights = np.loadtxt("q_weights.txt", ndmin=1).astype(np.float64)
    else:
        q_weights = get_q_weights(yambo_nscf_out).astype(np.float64)
    total_qweight = np.sum(q_weights)

    #read in the k points and n values
    ik_idx = np.load("ik.npy")             #only kpoints, not k,n pairs
    in_idx = np.loadtxt("in.txt", dtype=int)             #only band indices, not k,n pairs
    #n_min = 1
    num_n = len(in_idx)
    num_m = num_n


    ####################              Safety checks               ##########################
    if len(ik_idx) != num_kpoints:
        raise ValueError(f"Number of k-points in ik_rank0.txt ({len(ik_idx)}) does not match number of k-points in bands.out ({num_kpoints})")
    #Note that the number of bands however CAN differ


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
    #########################################################################################



    #precompute G1. E_kn is shape numK, numN, G1 is shape numE, numK, numN
    E_kn = band_energies[ik_idx[:,None] , in_idx[None,:] + n_min - 1] - Ef
    diff = energy_grid[:,None,None] - E_kn[None,:,:]    
    G_all = (1.0 / num_kpoints) * (1.0 / (sigma * np.sqrt(np.pi))) * np.exp( - (diff / sigma)**2 )      #numE, numK, numN
    G_all = G_all.astype(np.float32)

    #Setup shared memory for 32 processes
    shared_G_all = RawArray('f', G_all.size)              #allocate memory outside python heap
    shared_G_np = np.frombuffer(shared_G_all, dtype=np.float32).reshape(G_all.shape)
    np.copyto(shared_G_np, G_all)                       #copy data into shared memory
    del G_all, diff, E_kn                               #free memory    

    
    print(f"launching calculation on {args.ncores} cores...")
    worker_func = partial(process_q_point, q_weights=q_weights, total_q_weight=total_qweight, num_kpoints=num_kpoints, num_bands=num_n, n_min=n_min, numE=numE, ik_arr=ik_idx, in_arr=in_idx)


    W_map = np.zeros((numE, numE), dtype=np.float64)
    with Pool(processes=args.ncores, initializer=init_worker, initargs=(shared_G_np.shape, shared_G_all)) as pool:

        iterator = pool.imap_unordered(worker_func, range(q_weights.size), chunksize=1)
        for result_matrix in tqdm(iterator, total=q_weights.size, desc="Calculating W(E,E')"):
            W_map += result_matrix


    #Final processing
    #W_map = np.sum(results, axis=0)
    W_map = W_map * num_kpoints                                 #account for 1/Nk in G_all definition
    np.save("W_ee_raw.npy", W_map)

    #Also need to calcualte and save the DOS
    dos = np.sum(shared_G_np, axis=(1,2))
    np.save("dos_raw.npy", np.column_stack((energy_grid, dos)))

    save_Weep(W_map, np.column_stack((energy_grid, dos)), sigma)




    end_time = time.time()
    print(f"Total computation time: {end_time - start_time:.2f} seconds")



if __name__ == "__main__":
    header()
    main()