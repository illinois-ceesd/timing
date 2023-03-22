#!/bin/bash -l

# Intended to be run by cron with working directory the top level of the timing repo

# set -e
set -x

export MIRGE_TIMING_HOME=/p/gpfs1/mtcampbe/CEESD/AutomatedTesting/MIRGE-Timing/timing
cd ${MIRGE_TIMING_HOME}

TIMING_HOST=$(hostname)
TIMING_DATE=$(date "+%Y-%m-%d %H:%M")

PLOT_WINDOW_START=$(date --date="$(date +%Y-%m-1) -1 month" "+%Y-%m-%d")
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
    ./run-driver-timing.sh -d drivers_y2-prediction -b main -i y2-prediction
fi

if [ -f "RUN_SCALING_TEST" ]; then
    ./run-scaling-test.sh
fi

# Update the README with the latest testing date
if [ -f "UPDATE_PLOTS" ]; then

    git pull # pick up all the timings we just made
    rm -f latest_testing_date
    printf "${testing_date}\n" > latest_testing_date
    rm -f README.md
    printf "Timings last ran on: ${testing_date}\n\n" > README.md
    cat config/timing_readme.md >> README.md

    # Activate the env to make the plots
    source emirge/config/activate_env.sh

    # Install MATPLOTLIB if needed
    if [ -f "INSTALL_MATPLOTLIB" ]; then
        conda install -y matplotlib
        rm -f INSTALL_MATPLOTLIB
    fi

# Replace the timing plots with the most recent 
    python utils/plot-timings.py -l --save-plot plots/nozzle-full.png nozzle-lazy-timings.yaml
    python utils/plot-timings.py -l --save-plot plots/flame1d-full.png flame1d-lazy-timings.yaml
    python utils/plot-timings.py -l --save-plot plots/isolator-full.png isolator-timings.yaml
    python utils/plot-timings.py -l --save-plot plots/y2-prediction-single-smoke_test-full.png y2-prediction/yaml/single_timing_smoke_test-timing-data.yaml
    python utils/plot-timings.py -l --save-plot plots/y2-prediction-single-smoke_test_3d-full.png y2-prediction/yaml/single_timing_smoke_test_3d-timing-data.yaml
    python utils/plot-timings.py -l --save-plot plots/y2-prediction-single-smoke_test_ks-full.png y2-prediction/yaml/single_timing_smoke_test_ks-timing-data.yaml

    python utils/plot-timings.py -d "${PLOT_WINDOW_START}" -l --save-plot plots/nozzle-full-recent.png nozzle-lazy-timings.yaml
    python utils/plot-timings.py -d "${PLOT_WINDOW_START}" -l --save-plot plots/flame1d-full-recent.png flame1d-lazy-timings.yaml
    python utils/plot-timings.py -d "${PLOT_WINDOW_START}" -l --save-plot plots/isolator-full-recent.png isolator-timings.yaml
    python utils/plot-timings.py -d "${PLOT_WINDOW_START}" -l --save-plot plots/y2-prediction-single-smoke_test-full-recent.png y2-prediction/yaml/single_timing_smoke_test-timing-data.yaml
    python utils/plot-timings.py -d "${PLOT_WINDOW_START}" -l --save-plot plots/y2-prediction-single-smoke_test_3d-full-recent.png y2-prediction/yaml/single_timing_smoke_test_3d-timing-data.yaml
    python utils/plot-timings.py -d "${PLOT_WINDOW_START}" -l --save-plot plots/y2-prediction-single-smoke_test_ks-full-recent.png y2-prediction/yaml/single_timing_smoke_test_ks-timing-data.yaml

    python utils/plot-timings.py -d "${PLOT_WINDOW_START}" -s --save-plot plots/isolator-step-recent.png isolator-timings.yaml
    python utils/plot-timings.py -d "${PLOT_WINDOW_START}" -s --save-plot plots/nozzle-step-recent.png nozzle-lazy-timings.yaml
    python utils/plot-timings.py -d "${PLOT_WINDOW_START}" -s --save-plot plots/flame1d-step-recent.png flame1d-lazy-timings.yaml
    python utils/plot-timings.py -d "${PLOT_WINDOW_START}" -s --save-plot plots/y2-prediction-single-smoke_test-step-recent.png y2-prediction/yaml/single_timing_smoke_test-timing-data.yaml
    python utils/plot-timings.py -d "${PLOT_WINDOW_START}" -s --save-plot plots/y2-prediction-single-smoke_test_3d-step-recent.png y2-prediction/yaml/single_timing_smoke_test_3d-timing-data.yaml
    python utils/plot-timings.py -d "${PLOT_WINDOW_START}" -s --save-plot plots/y2-prediction-single-smoke_test_ks-step-recent.png y2-prediction/yaml/single_timing_smoke_test_ks-timing-data.yaml

    # Update origin/timing with the new README and plots
    git add plots
    (git commit -am "Automatic timing summary commit: ${TIMING_HOST} ${TIMING_DATE}" && git push)
fi
