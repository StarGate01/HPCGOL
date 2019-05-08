EXE=simple
ARG_PRINT=0
ARG_STEPS=10
ARG_WIDTH=10000
ARG_HEIGHT=10000
ARG_THREADS=1
ARG_NODES=1

.PHONY: build clean

export OMP_NUM_THREADS:=$(ARG_THREADS)

BIN=bin
SRC=src

FC=gfortran
MPIC=mpifort
FCFLAGS=-ffree-form -ffree-line-length-none -fmax-identifier-length=63 -fimplicit-none -std=f2008 -fopenmp
FCWARN=-pedantic -Wall -Wno-conversion
FCOPT=-Ofast -march=native -mtune=native -funroll-loops -ftree-vectorize -fopt-info-vec-optimized -fopenmp-simd

HELPERSSRC=$(SRC)/helpers.f90
MODS=simple simple_opt simple_simd simple_simd2
BINS=$(addprefix $(BIN)/,$(MODS))

$(BINS): $(BIN)/%: $(SRC)/%.f90 $(HELPERSSRC)
	@echo Building $@
	mkdir -p $(BIN)
	$(MPIC) $(FCFLAGS) $(FCWARN) $(FCOPT) $(HELPERSSRC) -o $@ $<
	@echo Completed building $@

build: $(BINS)

run: $(BIN)/$(EXE)
	$(BIN)/$(EXE) $(ARG_PRINT) $(ARG_STEPS) $(ARG_WIDTH) $(ARG_HEIGHT) $(ARG_THREADS) $(ARG_NODES)

clean:
	rm -rf $(BIN)