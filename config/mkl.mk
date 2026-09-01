# Intel MKL, which supplies the FFTW3, BLAS and LAPACK interfaces together.
# Chosen automatically whenever MKLROOT is set, since it is the fastest option
# where it is available.

FFTW_INC = -I$(MKLROOT)/include -I$(MKLROOT)/include/fftw
BLAS_LIB = -L$(MKLROOT)/lib/intel64 \
            -Wl,--no-as-needed \
            -lmkl_gf_lp64 -lmkl_gnu_thread -lmkl_core -lgomp -lpthread -lm -ldl
