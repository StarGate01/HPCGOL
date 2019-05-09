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
FCWARN=-pedantic -Wall
FCOPT=-Ofast -march=native -mtune=native -funroll-loops -ftree-vectorize -fopt-info-vec-optimized -fopenmp-simd
FCDEBUG=-g

LIBS=helpers functions
LIBSRCS=$(LIBS:%=$(SRC)/%.f90)
SRCS=$(filter-out $(LIBSRCS),$(wildcard $(SRC)/*.f90))
MODS=$(SRCS:$(SRC)/%.f90=%)
BINS=$(MODS:%=$(BIN)/%)

$(BIN)/%: $(SRC)/%.f90 $(LIBSRCS)
	@echo Building $@
	mkdir -p $(BIN)
ifdef $(DEBUG)
	$(MPIC) $(FCFLAGS) $(FCWARN) $(FCDEBUG) $(LIBSRCS) -J $(BIN) -o $@ $<
else
	$(MPIC) $(FCFLAGS) $(FCWARN) $(FCOPT) $(LIBSRCS) -J $(BIN) -o $@ $<
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