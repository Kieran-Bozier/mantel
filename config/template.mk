$(error config/template.mk is a starting point to copy, not a config to build with. Copy it to config/<yourmachine>.mk, delete this line, and build with `make CONFIG=<yourmachine>`)

# ---------------------------------------------------------------------------
# Template for a new machine.
#
#   cp config/template.mk config/mymachine.mk
#   make CONFIG=mymachine
#
# Set only what differs from the defaults. Anything left out falls back to
# gfortran with -O3 -fopenmp -march=native, which is what the makefile assumes.
#
# If you get mantel building somewhere new, please send the config back as a
# pull request so the next person on that machine does not repeat the work.
# ---------------------------------------------------------------------------

# The compiler, if not gfortran. Either a compiler or a wrapper (ftn, mpif90).
#FC = gfortran

# Target architecture. Leave empty on systems where a module sets the target.
#ARCH = -march=native

# FFTW3.
FFTW_INC = -I/path/to/fftw/include
FFTW_LIB = -L/path/to/fftw/lib -lfftw3 -lfftw3_omp

# BLAS and LAPACK. May be empty if a compiler wrapper links them for you.
#
# One caution that has already cost a day of debugging: mantel calls zdotc,
# which returns a complex value. A few BLAS implementations return complex
# results through a hidden first argument (the old f2c convention) instead of
# in registers, which puts every argument one slot out and segfaults. If you
# hit a crash inside the OpenMP block in mantel.f90 with nothing wrong nearby,
# check what the binary actually linked (ldd / otool -L) and try a different
# BLAS before looking anywhere else.
BLAS_LIB = -llapack -lblas

# Only needed if the compiler above is not gfortran-compatible.
#FFLAGS_FAST    = -O3 -fopenmp -fbacktrace $(ARCH) -flto -funroll-loops
#FFLAGS_PROFILE = -O0 -g -pg -Wall -fcheck=all -fopenmp
