#!/bin/bash
#SBATCH -o /home/hpc/pr63so/ga63yos2/HPCGOL/test/out/job.%j.out
#SBATCH -e /home/hpc/pr63so/ga63yos2/HPCGOL/test/out/job.%j.err
#SBATCH -D /home/hpc/pr63so/ga63yos2/HPCGOL
#SBATCH -J hpcgol_fat2
#SBATCH --mail-user=christoph.honal@tum.de
#SBATCH --mail-type=ALL
#SBATCH --clusters=mpp2
#SBATCH --get-user-env
#SBATCH --ntasks=16
#SBATCH --cpus-per-task=28
#SBATCH --time=00:05:00

source /etc/profile.d/modules.sh

export LC_NUMERIC="en_US.UTF-8"
export OMP_NUM_THREADS=28

NODES=16
EXE=hybrid
STEPS=10
WIDTH=10000
HEIGHT=10000

make run EXE=$EXE ARG_PRINT=0 ARG_STEPS=$STEPS ARG_WIDTH=$WIDTH ARG_HEIGHT=$HEIGHT ARG_THREADS=28 ARG_NODES=$NODES