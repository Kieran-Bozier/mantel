# macOS with the homebrew toolchain:  brew install gcc fftw openblas
#
# OpenBLAS is a requirement here. Accelerate returns
# complex values through a hidden first argument (the old f2c convention)
# while gfortran expects them in registers, so the zdotc call in W_nkmp.f90
# reads its arguments one slot out and dies with SIGSEGV or SIGBUS - inside
# the OpenMP block in mantel.f90, a long way from the actual cause.

FFTW_DIR     ?= $(shell brew --prefix fftw 2>/dev/null)
OPENBLAS_DIR ?= $(shell brew --prefix openblas 2>/dev/null)


ifeq ($(strip $(FFTW_DIR)),)
    $(error FFTW not found. Run `brew install fftw`, or set FFTW_DIR=/path/to/fftw)
endif
ifeq ($(strip $(OPENBLAS_DIR)),)
    $(error OpenBLAS not found. Run `brew install openblas`, or set OPENBLAS_DIR=/path/to/openblas. Accelerate cannot be substituted - see the comment at the top of config/darwin.mk)
endif

FFTW_INC = -I$(FFTW_DIR)/include
FFTW_LIB = -L$(FFTW_DIR)/lib -lfftw3 -lfftw3_omp
BLAS_LIB = -L$(OPENBLAS_DIR)/lib -lopenblas
