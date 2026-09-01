# Generic Linux: gfortran, FFTW3 through pkg-config, whatever BLAS and LAPACK
# the system provides. The fallback when nothing more specific matches.

ifdef FFTW_DIR
    FFTW_INC = -I$(FFTW_DIR)/include
    FFTW_LIB = -L$(FFTW_DIR)/lib -lfftw3 -lfftw3_omp
else
    FFTW_INC := $(shell pkg-config --cflags fftw3 2>/dev/null)
    FFTW_LIB := $(shell pkg-config --libs fftw3 2>/dev/null) -lfftw3_omp
    ifeq ($(strip $(FFTW_INC)),)
        $(error FFTW3 not found. Set FFTW_DIR=/path/to/fftw or ensure pkg-config can find fftw3)
    endif
endif

BLAS_LIB = -llapack -lblas
