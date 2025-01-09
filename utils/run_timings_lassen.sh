#!/bin/bash -l

# Intended to be run by cron with working directory the top level of the timing repo

# set -e
set -x

export MIRGE_TIMING_HOME=/p/gpfs1/mtcampbe/CEESD/AutomatedTesting/RepoMonitoring/pilot-timing
cd ${MIRGE_TIMING_HOME}

TIMING_HOST=$(hostname)
TIMING_DATE=$(date "+%Y-%m-%d %H:%M")

testing_date=$(date "+%Y.%m.%d")

# New: now explicitly set the env modules
# . ./lassen-env.sh

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
export MIRGE_BRANCH="production-pilot"
export TIMING_ENV_NAME="timing.pilot"
if [ -f "INSTALL_STUFF" ]; then
    touch INSTALL_MIRGECOM
    touch INSTALL_MATPLOTLIB
    ./install-mirgecom.sh
fi

if [ -f "RUN_SCALING_TEST" ]; then
    ./run-scaling-test.sh
fi

# Update the README with the latest testing date
if [ -f "UPDATE_PLOTS" ]; then
    ./update-performance-plots.sh
fi
