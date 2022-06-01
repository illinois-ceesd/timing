#!/bin/bash -l

# Intended to be run by cron with working directory the top level of the timing repo

# set -e
set -x

# MIRGE_TIMING_HOME should be set to the platform-specific path to timing repo top
export MIRGE_TIMING_HOME=$(pwd)
cd ${MIRGE_TIMING_HOME}

TIMING_HOST=$(hostname)
TIMING_DATE=$(date "+%Y-%m-%d %H:%M")

PLOT_WINDOW_START=$(date --date="$(date +%Y-%m-1) -1 month" "+%Y-%m-%d")
testing_date=$(date "+%Y.%m.%d")

# make sure the timing repo is up-to-date
git pull

# Install MIRGE-Com once
# - the script below will build mirgecom
# - after mirgecom is built INSTALL_MIRGECOM file is removed
# TODO: Make install a script-local option
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

# Update the README with the latest testing date
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

python utils/plot-timings.py -d "${PLOT_WINDOW_START}" -l --save-plot plots/nozzle-full-recent.png nozzle-lazy-timings.yaml
python utils/plot-timings.py -d "${PLOT_WINDOW_START}" -l --save-plot plots/flame1d-full-recent.png flame1d-lazy-timings.yaml
python utils/plot-timings.py -d "${PLOT_WINDOW_START}" -l --save-plot plots/isolator-full-recent.png isolator-timings.yaml

python utils/plot-timings.py -d "${PLOT_WINDOW_START}" -s --save-plot plots/isolator-step-recent.png isolator-timings.yaml
python utils/plot-timings.py -d "${PLOT_WINDOW_START}" -s --save-plot plots/nozzle-step-recent.png nozzle-lazy-timings.yaml
python utils/plot-timings.py -d "${PLOT_WINDOW_START}" -s --save-plot plots/flame1d-step-recent.png flame1d-lazy-timings.yaml

# Update origin/timing with the new README and plots
git add plots
(git commit -am "Automatic timing summary commit: ${TIMING_HOST} ${TIMING_DATE}" && git push)
