# Tutorial 02

In this example, we calculate the W matrix and the Coulomb parameter $\mu$ for Al.

The final outputs will be `W_ee.dat`, `dos.dat` and `mu.dat`. You can use the 
plotting scripts provided to visualise the W matrix.

This quality of calculation is approaching production-ready. Nonetheless, we
highly recommend performing convergence tests for your desired system.

There are two options for running this example. You can compare your results to
the data in `/reference`.

## Mantel only
If you do not have `yambo` and `pw.x` available, you can still run this example 
using the input files and reference data given in the `mantel_only` directory.

You must ensure you have the correct `conda` environment loaded. Unfortunately, these Quantum Espresso wavefunctions are too large to put directly on GitHub, but you can download them from the releases using the `download_data.sh` script.

Once you have extracted the `mantel_only_files.tar.gz`, the simplest way to run 
(assuming `/mantel/bin` is on your `PATH`) is:
```
$ conda activate mantel
$ export OMP_NUM_THREADS=4
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
**Estimated Timing:** around 5 minutes when run on 4 OMP threads


## Full run
If you have both `yambo` and `pw.x` present, you can run the full 
pipeline as follows:
```
$ conda activate mantel
$ mantel_prep.sh -n 4 -c mantel.in &
$ export OMP_NUM_THREADS=4
$ mantel_run.sh -c mantel.in &
```
