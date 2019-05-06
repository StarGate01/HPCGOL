.PHONY: build clean

BIN=bin
SRC=src

FC=gfortran
MPIC=mpifort
FCFLAGS=-ffree-form -ffree-line-length-none -fmax-identifier-length=63 -fimplicit-none -std=f2008 -fopenmp
FCWARN=-pedantic -Wall
FCOPT=-O3 -march=native -mtune=native -ftree-vectorize -fopt-info-vec-optimized

HELPERSSRC=$(SRC)/helpers.f90
MODS=simple omptest mpitest

BINS=$(addprefix $(BIN)/,$(MODS))


$(BINS): $(BIN)/%: $(SRC)/%.f90 $(HELPERSSRC)
	@echo Building $@
	mkdir -p $(BIN)
	$(MPIC) $(FCFLAGS) $(FCWARN) $(FCOPT) $(HELPERSSRC) -o $@ $<
	@echo Completed building $@

build: $(BINS)

clean:
	rm -rf $(BIN)