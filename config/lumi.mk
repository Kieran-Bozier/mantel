# LUMI, and other Cray/HPE systems reached through the compiler wrappers:
#
#   module load PrgEnv-gnu cray-fftw
#
# NOT TESTED BY THE AUTHORS - if you build here and something needs changing,
# please send the fix back.
#
# FFTW_LIB and BLAS_LIB are deliberately empty: the ftn wrapper links cray-fftw
# and Cray libsci itself. Do not add -llapack -lblas, which do not exist under
# those names on the system.

FC = ftn

# The craype-x86-* module (craype-x86-milan on LUMI-C) tells the wrappers which
# microarchitecture to target, so no -march belongs here. -march=native would
# be actively wrong on a login node whose silicon differs from the compute
# nodes.
ARCH =

ifeq ($(PE_ENV), CRAY)
    # Cray Fortran spells these differently from gfortran
    FFLAGS_FAST    = -O3 -homp
    FFLAGS_PROFILE = -O0 -g -homp
endif
