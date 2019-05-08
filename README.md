# High performance Conway's Game of Life
High performance Conway's Game of Life. See https://en.wikipedia.org/wiki/Conway%27s_Game_of_Life.

## Modules
 - Exploitation of cache locality and memory layout (`simple`)
 - Optimized kernel (`simple_opt`) 
 - Vectorization (sub-optimal in this use-case, not recommended) using
   - The Auto-Vectorizer (`simple_simd`)
   - OpenMP SIMD (`simple_simd2`)
 - Thread-level parallelism using OpenMP (`threads`)
 - CPU-Node parallelism using MPI (`nodes`)
 - Thread-level and CPU-Node hybrid parallelism using OpenMP and MPI (`hybrid`)

## Installation
Run `sudo make deps` if your package manager ist apt, otherwise install these packages:
 - gfortran
 - mpich
 - libmpich-dev

## Compilation
Run `make all` or `make modulename` or `make bin/modulename` to build all resp. a single program.

Run `make clean` to remove all binaries.

### MPICH2 vs OpenMPI
If you want to use `OpenMPI` instead of `MPICH2`, the code should compile and work but I have not tested this yet but may support it in the future.

### GNU compiler vs Intel compiler
Instead of the GNU compiler `gfortran` the intel compiler `ifort` may be used. In general, every OpenMP- and MPI-capable Fortran-2008 standard compliant compiler should work.

## Execution
The included makefile has a `run` target, which should be used to launch the binaries. Note that also invokes the compilation. The syntax and some default values are as follows:

`make run EXE=modulename ARG_PRINT=1 ARG_STEPS=15 ARG_WIDTH=10 ARG_HEIGHT=10 ARG_THREADS=1 ARG_NODES=1`
 - `EXE`: The name of the module to launch, see above.
 - `ARG_PRINT`: 1 to print the field as ACII, 0 to not print it. This is only recommended for small field sizes.
 - `ARG_STEPS`: The number of iterations to compute.
 - `ARG_WIDTH`: The width in cells of the field.
 - `ARG_HEIGHT`: The height in cells of the field.
 - `ARG_THREADS`: The number of threads to use. Note that more threads than your system has CPU cores or hyper-threads may slow things down.
 - `ARG_NODES`: The number of MPI nodes to use. If there is no MPI cluster available, `hydra` will automatically emulate a cluster using multiple processes.

### Recommended settings
Use the default values above to test the program using its graphical output.

A field size of `10000` times `10000` is a reasonable first scale test, it runs with about 0.2 - 1 steps per second on most laptops and PCs, depending on optimization and CPU speed.

### Memory requirements
The minimum amount of required RAM is roughly `2 * ARG_WIDTH * ARG_HEIGHT` bytes. When running on a MPI cluster, this memory is equally distributed.

## IDE support
The Visual Studio Code IDE (See https://code.visualstudio.com/) is supported. But any other IDE capable of launching makefiles should work.