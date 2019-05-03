.PHONY: build pre_build clean

FC=gfortran
MPIC=mpifort

FCFLAGS=-ffree-form -ffree-line-length-none -fmax-identifier-length=63 -fimplicit-none -std=f2008 -fopenmp
FCWARN=-pedantic -Wall
FCOPT=-O3 -march=native -mtune=native -ftree-vectorize -fopt-info-vec-optimized

BIN=bin
SRC=src
MODS=simple omptest mpitest
BINS=$(addprefix $(BIN)/,$(MODS))


$(BINS): $(BIN)/%: $(SRC)/%.f90
	@echo Building $@
	mkdir -p $(BIN)
	$(MPIC) $(FCFLAGS) $(FCWARN) $(FCOPT) -o $@ $<
	@echo Completed building $@

build: $(BINS)

clean:
	rm -rf $(BIN)