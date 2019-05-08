EXE=simple
ARG_PRINT=0
ARG_STEPS=10
ARG_WIDTH=30000
ARG_HEIGHT=30000
ARG_THREADS=8
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

HELPERSSRC=$(SRC)/helpers.f90
SRCS=$(filter-out $(HELPERSSRC),$(wildcard $(SRC)/*.f90))
MODS=$(SRCS:$(SRC)/%.f90=%)
BINS=$(addprefix $(BIN)/,$(MODS))

$(BIN)/%: $(SRC)/%.f90 $(HELPERSSRC)
	@echo Building $@
	mkdir -p $(BIN)
	$(MPIC) $(FCFLAGS) $(FCWARN) $(FCOPT) $(HELPERSSRC) -o $@ $<
	@echo Completed building $@

$(MODS): %: $(BIN)/%

all: $(MODS)

run: $(BIN)/$(EXE)
	$(MPIX) -n $(ARG_NODES) $(BIN)/$(EXE) $(ARG_PRINT) $(ARG_STEPS) $(ARG_WIDTH) $(ARG_HEIGHT) $(ARG_THREADS) $(ARG_NODES)

clean:
	rm -rf $(BIN)

deps:
	apt-get install -y build-essential gfortran mpich libmpich-dev