# Tutorial 01

Welcome to Mantel! In this tutorial, we'll run a very small test run for niobium. 
Please be aware that the results here are not at all representative, due to the coarse 
calculation parameters used.

There are two options for running this example. You can compare your results to
the data in `/reference`.

## Mantel only
### First run
If you do not have `yambo` and `pw.x` available, you can still run this example 
using the input files and reference data given in the `mantel_only` directory. Extract the files using
```
tar -xvf Nb_mantel_only_files.tar.gz
```

Every `Mantel` run is controlled by the `mantel.in` file. This file is broken up into
separate namelists, like in Quantum ESPRESSO. Be aware that some of the exectuables read
from more than one namelist. 

Use the `mantel.in` file present in this directory, but be aware for future runs you can 
generate a template using
```mantel_gen.py -v my_mantel.in```

All the pre-requisite Quantum ESPRESSO and Yambo data is already in the directory. Provided you have 
activated the `conda` environment and added `/mantel/bin` to your `PATH`, you should be able to run
the example using

```
$ conda activate mantel
$ mantel_run.sh -c mantel.in &
```
Output is written to `mantel_run.log`. Alternatively, you can run each step 
within `mantel_run.sh` manually with:
```
$ mantel_xml.py
$ wfc2bin.x < mantel.in > wfc2bin.out
$ prepare_yambo.py YAMBO/SAVE YAMBO/RPA
$ mantel.x < mantel.in > mantel.out
$ isoenergy.x < mantel.in > isoenergy.out
$ mu.x < mantel.in > mu.out
```
**Estimated Timing:** 10 seconds

### DOS rescaling
Your `mu.dat` file should look something like
```
# mu(sigma) from mantel
# Fermi energy [eV] =    17.732216
# Bands  in_min = 1  in_max = 10
# Q-pts  iq_min = 1  iq_max = 3
# No external N_F supplied - mu rescaled column set to -1
#   sigma (eV)  N_F (states/eV/spin)  N_F (states/Ry/spin)     W(0,0) (eV)          mu  mu (dos rescaled)
        0.1000              0.918209             12.492883        2.767374    2.541029          -1.000000
        0.2000              0.657713              8.948650        2.477035    1.629178          -1.000000
        0.3000              0.654390              8.903440        2.209561    1.445915          -1.000000
        0.4000              0.622164              8.464974        2.043916    1.271650          -1.000000
        0.5000              0.591718              8.050743        1.842727    1.090375          -1.000000
        0.6000              0.575458              7.829516        1.621776    0.933265          -1.000000
        0.7000              0.569299              7.745709        1.433176    0.815905          -1.000000
        0.8000              0.567878              7.726378        1.296372    0.736181          -1.000000
        0.9000              0.567920              7.726948        1.203888    0.683712          -1.000000
        1.0000              0.567956              7.727442        1.141578    0.648366          -1.000000
```

You will notice the final column is all set to -1. This column corresponds to the case where we supply an external
density of states at the Fermi energy $N_F$, that should be calculated at high quality and on a fine grid. 


By using this high quality $N_F$ instead of the one derived from Gaussian smearing, we often find convergence with 
respect to smearing is greatly accelerated, (see https://doi.org/10.1103/82zm-by55). We refer to this as the "DOS rescaled value".


You can easily perform the DOS rescaling by modifying your `mantel.in`:
```
40c40
<     nef             = -1.0
---
>     nef             = 0.7405
```
Note that the units here is states/eV/spin.

You can either run the full calculation again with `mantel_run.sh`, but it's quicker to just pass this directly into `mu.x`
```
mu.x < mantel.in
```

Because the grids used here are so coarse, the rescaled value is still very poor. However, on finer $k$- and $q$-grids, you will
find both approaches converge to the same result, but the rescaled one does so more rapidly. 




## Full run
If you have both Quantum ESPRESSO and Yambo installed, you should be able to run the full pipeline. 
First use `mantel_prep.sh` to run the QE and Yambo steps
```
mantel_prep.sh -n 4 -c mantel.in &
```
after which you should have the same files as the `mantel_only` directory, and can follow the instructions above.

