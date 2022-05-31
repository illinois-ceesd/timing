#!/bin/bash -l

# set -e
set -x

export MIRGE_TIMING_HOME=$(pwd)
TIMING_HOST=$(hostname)
TIMING_DATE=$(date "+%Y-%m-%d %H:%M")
PLOT_WINDOW_START=$(date --date="$(date +%Y-%m-1) -1 month" "+%Y-%m-%d")
testing_date=$(date "+%Y.%m.%d")

# Clone the timing repo if it does not exist
# if [ ! -d timing ]
# then 
#     git clone git@github.com:/illinois-ceesd/timing
# fi

# Go into timing dir
# cd timing

# Get the main repo (nozzle)
# git checkout main
git pull

# Install MIRGE-Com once
# - the script below will build mirgecom
# - after mirgecom is built INSTALL_MIRGECOM file is removed
touch INSTALL_MIRGECOM
touch INSTALL_MATPLOTLIB

# Run the lazy nozzle data collection driver
./time-lazy-nozzle.sh

# Run the lazy 1dflame data collection driver
./time-lazy-flame1d.sh

# Time isolator
./time-lazy-isolator.sh

# Time combustor
# ./time-lazy-combustor.sh

git pull # pick up all the timings we just made
rm -f latest_testing_date
printf "${testing_date}\n" > latest_testing_date
rm -f README.md
printf "Timings last ran on: ${testing_date}\n\n" > README.md
cat config/timing_readme.md >> README.md

source emirge/config/activate_env.sh
if [ -f "INSTALL_MATPLOTLIB" ]; then
    conda install -y matplotlib
    rm -f INSTALL_MATPLOTLIB
fi

python utils/plot-timings.py -l --save-plot plots/nozzle-full.png nozzle-lazy-timings.yaml
python utils/plot-timings.py -l --save-plot plots/flame1d-full.png flame1d-lazy-timings.yaml
python utils/plot-timings.py -l --save-plot plots/isolator-full.png isolator-timings.yaml

python utils/plot-timings.py -d "${TIMING_WINDOW_START}" -l --save-plot plots/nozzle-full-recent.png nozzle-lazy-timings.yaml
python utils/plot-timings.py -d "${TIMING_WINDOW_START}" -l --save-plot plots/flame1d-full-recent.png flame1d-lazy-timings.yaml
python utils/plot-timings.py -d "${TIMING_WINDOW_START}" -l --save-plot plots/isolator-full-recent.png isolator-timings.yaml

python utils/plot-timings.py -d "${TIMING_WINDOW_START}" -s --save-plot plots/isolator-step-recent.png isolator-timings.yaml
python utils/plot-timings.py -d "${TIMING_WINDOW_START}" -s --save-plot plots/nozzle-step-recent.png nozzle-lazy-timings.yaml
python utils/plot-timings.py -d "${TIMING_WINDOW_START}" -s --save-plot plots/flame1d-step-recent.png flame1d-lazy-timings.yaml

git add plots
(git commit -am "Automatic timing summary commit: ${TIMING_HOST} ${TIMING_DATE}" && git push)
