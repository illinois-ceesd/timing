#!/bin/bash -l

# Intended to be run by cron with working directory the top level of the timing repo

# set -e
set -x

export MIRGE_TIMING_HOME=/p/gpfs1/mtcampbe/CEESD/AutomatedTesting/MIRGE-Timing/timing
cd ${MIRGE_TIMING_HOME}

TIMING_HOST=$(hostname)
TIMING_DATE=$(date "+%Y-%m-%d %H:%M")

testing_date=$(date "+%Y.%m.%d")

# New: now explicitly set the env modules
. ./lassen-env.sh

# --- Debugging ---
# which mpicc
# mpicc --version
# module list
# env
# exit

# make sure the timing repo is up-to-date
git pull

# Install MIRGE-Com once
# - the script below will build mirgecom
# - after mirgecom is built INSTALL_MIRGECOM file is removed
# TODO: Make install a script-local option
if [ -f "INSTALL_STUFF" ]; then
    touch INSTALL_MIRGECOM
    touch INSTALL_MATPLOTLIB
fi

# Run the lazy nozzle data collection driver
if [ -f "RUN_NOZZLE" ]; then
    ./time-lazy-nozzle.sh
fi

# Run the lazy 1dflame data collection driver
if [ -f "RUN_FLAME" ]; then
    ./time-lazy-flame1d.sh
fi

# Time isolator
if [ -f "RUN_ISOLATOR" ]; then
    ./time-lazy-isolator.sh
fi

# Time combustor
# ./time-lazy-combustor.sh

# Time prediction
if [ -f "RUN_PREDICTION" ]; then
    ./run-driver-timing.sh -d drivers_y2-prediction -b update-to-y3 -i y2-prediction
fi

if [ -f "RUN_SCALING_TEST" ]; then
    ./run-scaling-test.sh
fi

# Update the README with the latest testing date
if [ -f "UPDATE_PLOTS" ]; then
    ./update-performance-plots.sh
fi
