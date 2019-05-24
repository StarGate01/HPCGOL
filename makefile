EXE=simple
ARG_PRINT=1
ARG_STEPS=5
ARG_WIDTH=10
ARG_HEIGHT=10
ARG_THREADS=1
ARG_NODES=1

.PHONY: build clean deps

export OMP_NUM_THREADS:=$(ARG_THREADS)

BIN=bin
SRC=src

FC=gfortran
MPIC=mpifort
MPIX=mpiexec
FCFLAGS=-ffree-form -ffree-line-length-none -fmax-identifier-length=63 -fimplicit-none -std=f2008 -fopenmp
FCOPT=-Ofast -march=native -mtune=native -funroll-loops -ftree-vectorize -fopt-info-vec-optimized -fopenmp-simd
FCWARN=-pedantic -Wall
FCDEBUG=-g

FCINT=ifort
MPICINT=mpif90
FCINTFLAGS=-free -implicitnone -stand f08 -qopenmp
FCINTOPT=-O3 -ipo -fno-alias -align all -unroll -inline-level=2 -qopt-report1 -qopenmp-simd
FCINTWARN=-warn all
FCINTDEBUG=-g

LIBS=helpers functions
LIBSRCS=$(LIBS:%=$(SRC)/%.f90)
SRCS=$(filter-out $(LIBSRCS),$(wildcard $(SRC)/*.f90))
MODS=$(SRCS:$(SRC)/%.f90=%)
BINS=$(MODS:%=$(BIN)/%)

$(BIN)/%: $(SRC)/%.f90 $(LIBSRCS)
	@echo Building $@
	mkdir -p $(BIN)
ifdef DEBUG
ifdef INTEL
	@echo "Building debug using Intel"
	MPICH_F90=$(FCINT) OMPI_FC=$(FCINT) I_MPI_F90=$(FCINT) $(MPICINT) $(FCINTFLAGS) $(FCINTWARN) $(FCINTDEBUG) $(LIBSRCS) -module $(BIN) -o $@ $<
else
	@echo "Building debug using GCC"
	MPICH_F90=$(FC) OMPI_FC=$(FC) I_MPI_F90=$(FC) $(MPIC) $(FCFLAGS) $(FCWARN) $(FCDEBUG) $(LIBSRCS) -J $(BIN) -o $@ $<
endif
else
ifdef INTEL
	@echo "Building release using Intel"
	MPICH_F90=$(FCINT) OMPI_FC=$(FCINT) I_MPI_F90=$(FCINT) $(MPICINT) $(FCINTFLAGS) $(FCINTWARN) $(FCINTOPT) $(LIBSRCS) -module $(BIN) -o $@ $<
else
	@echo "Building release using GCC"
	MPICH_F90=$(FC) OMPI_FC=$(FC) I_MPI_F90=$(FC) $(MPIC) $(FCFLAGS) $(FCWARN) $(FCOPT) $(LIBSRCS) -J $(BIN) -o $@ $<
endif
endif
	@echo Completed building $@

$(MODS): %: $(BIN)/%

all: $(MODS)

run: $(BIN)/$(EXE)
	$(MPIX) -n $(ARG_NODES) $(BIN)/$(EXE) $(ARG_PRINT) $(ARG_STEPS) $(ARG_WIDTH) $(ARG_HEIGHT) $(ARG_THREADS) $(ARG_NODES)

clean:
	rm -rf $(BIN)

deps:
	apt-get install -y gfortran mpich libmpich-dev