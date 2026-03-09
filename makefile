FC       = gfortran
VPATH    = src
BUILD_DIR = build
BUILD   ?= fast

# FFTW3: use FFTW_DIR if set, otherwise fall back to pkg-config
ifdef FFTW_DIR
    FFTW_INC = -I$(FFTW_DIR)/include
    FFTW_LIB = -L$(FFTW_DIR)/lib -lfftw3 -lfftw3_omp
else
    FFTW_INC := $(shell pkg-config --cflags fftw3 2>/dev/null)
    FFTW_LIB := $(shell pkg-config --libs fftw3 2>/dev/null) -lfftw3_omp
    ifeq ($(FFTW_INC),)
        $(error FFTW3 not found. Set FFTW_DIR=/path/to/fftw or ensure pkg-config can find fftw3)
    endif
endif

INCLUDES = $(FFTW_INC) -I$(BUILD_DIR)

ifeq ($(BUILD), profile)
    FFLAGS = -O0 -g -pg -Wall -fcheck=all -fopenmp
else
    FFLAGS = -O3 -fopenmp -fbacktrace -march=native
endif

LIBS = $(FFTW_LIB) -llapack -lblas

MODULES = precision.f90 \
          array_io.f90 \
          read_input.f90 \
          write_data.f90 \
          precompute.f90 \
          epsm1.f90 \
          k_mapping.f90 \
          g_mapping.f90 \
          wfc.f90 \
          W_nkmp.f90 \
          output.f90

MAIN     = mantel.f90
OBJS     = $(addprefix $(BUILD_DIR)/, $(MODULES:.f90=.o) $(MAIN:.f90=.o))

WFC_SRC  = wfc2bin.f90
WFC_OBJS = $(addprefix $(BUILD_DIR)/, precision.o array_io.o $(WFC_SRC:.f90=.o))

EXEC     = $(BUILD_DIR)/mantel.x
WFC_EXEC = $(BUILD_DIR)/wfc2bin
BINDIR   = bin

all: $(EXEC) $(WFC_EXEC)

$(EXEC): $(OBJS)
	$(FC) $(FFLAGS) -o $@ $^ $(LIBS)

$(WFC_EXEC): $(WFC_OBJS)
	$(FC) $(FFLAGS) -o $@ $^ $(LIBS)

$(BUILD_DIR)/%.o: %.f90 | $(BUILD_DIR)
	$(FC) $(FFLAGS) $(INCLUDES) -J$(BUILD_DIR) -c $< -o $@

$(BUILD_DIR):
	mkdir -p $@

install: all
	mkdir -p $(BINDIR)
	install -m 755 $(EXEC)     $(BINDIR)/mantel.x
	install -m 755 $(WFC_EXEC) $(BINDIR)/wfc2bin

clean:
	rm -rf $(BUILD_DIR)

# Module dependency order
$(BUILD_DIR)/mantel.o:   $(addprefix $(BUILD_DIR)/, $(MODULES:.f90=.o))
$(BUILD_DIR)/wfc2bin.o: $(BUILD_DIR)/precision.o $(BUILD_DIR)/array_io.o
