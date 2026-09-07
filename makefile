VPATH     = src
BUILD_DIR = build
BUILD    ?= fast

#Read from here, not from any files
.PHONY: all clean install configs


# ---------------------------------------------------------------------------
# Platform configuration
#
# Everything machine-specific lives in config/<name>.mk. This file holds the
# build rules and nothing else.
#
#   make                 pick a config automatically
#   make CONFIG=lumi     force a particular one
#   make configs         list what is available
#
# To port to a new machine, copy config/template.mk and edit it.
# ---------------------------------------------------------------------------
ifdef MKLROOT
    CONFIG ?= mkl
else ifdef PE_ENV                      # Cray compiler wrappers: LUMI, ARCHER2
    CONFIG ?= lumi
else ifeq ($(shell uname -s), Darwin)
    CONFIG ?= darwin
else
    CONFIG ?= generic
endif

ifeq ($(wildcard config/$(CONFIG).mk),)
    $(error No config '$(CONFIG)'. Available: $(patsubst config/%.mk,%,$(wildcard config/*.mk)))
endif
include config/$(CONFIG).mk

# Whatever the config did not set falls back to the gfortran defaults.
# FC needs the origin test because make predefines it.
ifeq ($(origin FC), default)
    FC = gfortran
endif
ARCH           ?= -march=native
FFLAGS_FAST    ?= -O3 -fopenmp -fbacktrace $(ARCH) -flto -funroll-loops
FFLAGS_PROFILE ?= -O0 -g -pg -Wall -fcheck=all -fopenmp

ifeq ($(BUILD), profile)
    FFLAGS = $(FFLAGS_PROFILE)
else
    FFLAGS = $(FFLAGS_FAST)
endif


ifneq ($(strip $(FFTW_INC)),)
    ifeq ($(filter -I%,$(FFTW_INC)),)
        $(error FFTW_INC is a bare path, not a -I flag: '$(FFTW_INC)'. Your environment probably set it - assign it explicitly in config/$(CONFIG).mk)
    endif
endif

INCLUDES = $(FFTW_INC) -I$(BUILD_DIR)
LIBS     = $(FFTW_LIB) $(BLAS_LIB)


MODULES = precision.f90 \
          array_io.f90 \
          read_mantel_in.f90 \
          read_mantel_nml.f90 \
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
WFC_OBJS = $(addprefix $(BUILD_DIR)/, precision.o array_io.o \
            read_mantel_in.o read_mantel_nml.o $(WFC_SRC:.f90=.o))

ISO_SRC  = isoenergy.f90
ISO_OBJS = $(addprefix $(BUILD_DIR)/, precision.o array_io.o \
            read_mantel_in.o read_mantel_nml.o $(ISO_SRC:.f90=.o))

MU_SRC	 = mu.f90
MU_OBJS	 = $(addprefix $(BUILD_DIR)/, precision.o array_io.o \
              read_mantel_in.o read_mantel_nml.o $(MU_SRC:.f90=.o))


EXEC     = $(BUILD_DIR)/mantel.x
WFC_EXEC = $(BUILD_DIR)/wfc2bin.x
ISO_EXEC = $(BUILD_DIR)/isoenergy.x
MU_EXEC	 = $(BUILD_DIR)/mu.x
BINDIR   = bin

all: $(EXEC) $(WFC_EXEC) ${ISO_EXEC} ${MU_EXEC}

$(EXEC): $(OBJS)
	$(FC) $(FFLAGS) -o $@ $^ $(LIBS)

$(WFC_EXEC): $(WFC_OBJS)
	$(FC) $(FFLAGS) -o $@ $^ $(LIBS)

$(ISO_EXEC): $(ISO_OBJS)
	$(FC) $(FFLAGS) -o $@ $^ $(LIBS)

$(MU_EXEC):  $(MU_OBJS)
	$(FC) $(FFLAGS) -o $@ $^ $(LIBS)

$(BUILD_DIR)/%.o: %.f90 | $(BUILD_DIR)
	$(FC) $(FFLAGS) $(INCLUDES) -J$(BUILD_DIR) -c $< -o $@

$(BUILD_DIR):
	mkdir -p $@

install: all
	mkdir -p $(BINDIR)
	install -m 755 $(EXEC)     $(BINDIR)/mantel.x
	install -m 755 $(WFC_EXEC) $(BINDIR)/wfc2bin.x
	install -m 755 $(ISO_EXEC) $(BINDIR)/isoenergy.x
	install -m 755 $(MU_EXEC)  $(BINDIR)/mu.x

configs:
	@echo "Available configs (make CONFIG=<name>), currently using '$(CONFIG)':"
	@printf '  %s\n' $(patsubst config/%.mk,%,$(wildcard config/*.mk))

clean:
	rm -rf $(BUILD_DIR)

# Module dependency order
$(BUILD_DIR)/mantel.o:   $(addprefix $(BUILD_DIR)/, $(MODULES:.f90=.o))
$(BUILD_DIR)/wfc2bin.o: $(BUILD_DIR)/precision.o $(BUILD_DIR)/array_io.o \
                        $(BUILD_DIR)/read_mantel_in.o $(BUILD_DIR)/read_mantel_nml.o
$(BUILD_DIR)/isoenergy.o: $(BUILD_DIR)/precision.o $(BUILD_DIR)/array_io.o \
                        $(BUILD_DIR)/read_mantel_in.o $(BUILD_DIR)/read_mantel_nml.o
$(BUILD_DIR)/mu.o :	$(BUILD_DIR)/precision.o $(BUILD_DIR)/array_io.o \
			$(BUILD_DIR)/read_mantel_in.o $(BUILD_DIR)/read_mantel_nml.o
