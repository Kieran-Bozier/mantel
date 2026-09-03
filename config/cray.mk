# LUMI, and other Cray/HPE systems reached through the compiler wrappers:
#
#   module load PrgEnv-gnu cray-fftw cray-libsci


# The ftn wrapper links cray-fftw and Cray libsci itself, so there is nothing
# to add.
FFTW_INC =
FFTW_LIB =
BLAS_LIB =

FC = ftn

# -march=native would be wrong as would use login node instead of compute
# node. Let compilers decide which architecture to use
ARCH =

