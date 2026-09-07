# Generic Linux: gfortran, FFTW3 through pkg-config, whatever BLAS and LAPACK
# the system provides. The fallback when nothing more specific matches.

ifdef FFTW_DIR
    FFTW_INC = -I$(FFTW_DIR)/include
    FFTW_LIB = -L$(FFTW_DIR)/lib -lfftw3 -lfftw3_omp

else
    # If exists, returns 0 and echo yes. String non-zero so doesn;t match
    ifeq ($(shell pkg-config --exists fftw3 2>/dev/null && echo "pkg-config found fftw3"),)
        $(error FFTW3 not found. Set FFTW_DIR=/path/to/fftw or ensure pkg-config can find fftw3)
    endif
    
    FFTW_INC := -I$(shell pkg-config --variable=includedir fftw3)
    FFTW_LIB := $(shell pkg-config --libs fftw3 2>/dev/null) -lfftw3_omp
  endif

  BLAS_LIB = -llapack -lblas
