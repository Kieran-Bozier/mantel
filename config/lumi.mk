# LUMI, and other Cray/HPE systems reached through the compiler wrappers:
#
#   module load PrgEnv-gnu cray-fftw
#
#
# The ftn wrapper links cray-fftw and Cray libsci itself, so there is nothing
# to add.
FFTW_INC =
FFTW_LIB =
BLAS_LIB =

FC = ftn

# -march=native would be actively wrong as uses login node instead of compute
# nodes. cray compilers decide which architecture to use
ARCH =

