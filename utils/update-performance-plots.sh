#!/bin/bash

PLOT_WINDOW_START=$(date --date="$(date +%Y-%m-%d) -1 month" "+%Y-%m-%d")
testing_date=$(date "+%Y.%m.%d")

git pull # pick up all the timings we just made
rm -f latest_testing_date
printf "${testing_date}\n" > latest_testing_date
rm -f README.md
# Status of production timings

printf "# Timing status (last ran on: ${testing_date})\n\n" > README.md
cat config/timing_readme.md >> README.md

# Activate the env to make the plots
conda deactivate
source emirge/config/activate_env.sh

# Install MATPLOTLIB if needed
if [ -f "INSTALL_MATPLOTLIB" ]; then
    conda install -y matplotlib
    rm -f INSTALL_MATPLOTLIB
fi

# Replace the timing plots with the most recent
set -x
#python utils/plot-timings.py -l --save-plot plots/nozzle-full.png nozzle-lazy-timings.yaml
#python utils/plot-timings.py -l --save-plot plots/flame1d-full.png flame1d-lazy-timings.yaml
#python utils/plot-timings.py -l --save-plot plots/isolator-full.png isolator-timings.yaml
#python utils/plot-timings.py -l --save-plot plots/y2-prediction-single-smoke_test-full.png y2-prediction/yaml/single_timing_smoke_test-timing-data.yaml
#python utils/plot-timings.py -l --save-plot plots/y2-prediction-single-smoke_test_3d-full.png y2-prediction/yaml/single_timing_smoke_test_3d-timing-data.yaml
#python utils/plot-timings.py -l --save-plot plots/y2-prediction-single-smoke_test_ks-full.png y2-prediction/yaml/single_timing_smoke_test_ks-timing-data.yaml
python utils/plot-multi-timings.py -k -g --save-plot plots/y3-prediction-scalability-full.png y3-prediction/lassen/yaml/*.yaml
python utils/plot-multi-timings.py -k -s -g -w --save-plot y3-prediction-scalability-step-full.png y3-prediction/lassen/yaml/*.yaml
mv y3-prediction-scalability-step-full.png plots
mv weak_scaling_y3-prediction-scalability-step-full.png plots

#python utils/plot-timings.py -d "${PLOT_WINDOW_START}" -l --save-plot plots/nozzle-full-recent.png nozzle-lazy-timings.yaml
#python utils/plot-timings.py -d "${PLOT_WINDOW_START}" -l --save-plot plots/flame1d-full-recent.png flame1d-lazy-timings.yaml
#python utils/plot-timings.py -d "${PLOT_WINDOW_START}" -l --save-plot plots/isolator-full-recent.png isolator-timings.yaml
#python utils/plot-timings.py -d "${PLOT_WINDOW_START}" -l --save-plot plots/y2-prediction-single-smoke_test-full-recent.png y2-prediction/yaml/single_timing_smoke_test-timing-data.yaml
#python utils/plot-timings.py -d "${PLOT_WINDOW_START}" -l --save-plot plots/y2-prediction-single-smoke_test_3d-full-recent.png y2-prediction/yaml/single_timing_smoke_test_3d-timing-data.yaml
#python utils/plot-timings.py -d "${PLOT_WINDOW_START}" -l --save-plot plots/y2-prediction-single-smoke_test_ks-full-recent.png y2-prediction/yaml/single_timing_smoke_test_ks-timing-data.yaml

#python utils/plot-timings.py -d "${PLOT_WINDOW_START}" -s --save-plot plots/isolator-step-recent.png isolator-timings.yaml
#python utils/plot-timings.py -d "${PLOT_WINDOW_START}" -s --save-plot plots/nozzle-step-recent.png nozzle-lazy-timings.yaml
#python utils/plot-timings.py -d "${PLOT_WINDOW_START}" -s --save-plot plots/flame1d-step-recent.png flame1d-lazy-timings.yaml
#python utils/plot-timings.py -d "${PLOT_WINDOW_START}" -s --save-plot plots/y2-prediction-single-smoke_test-step-recent.png y2-prediction/yaml/single_timing_smoke_test-timing-data.yaml
#python utils/plot-timings.py -d "${PLOT_WINDOW_START}" -s --save-plot plots/y2-prediction-single-smoke_test_3d-step-recent.png y2-prediction/yaml/single_timing_smoke_test_3d-timing-data.yaml
#python utils/plot-timings.py -d "${PLOT_WINDOW_START}" -s --save-plot plots/y2-prediction-single-smoke_test_ks-step-recent.png y2-prediction/yaml/single_timing_smoke_test_ks-timing-data.yaml

python utils/plot-multi-timings.py -k -d "${PLOT_WINDOW_START}" -g -p viridis --save-plot plots/y3-prediction-scalability-recent.png y3-prediction/lassen/yaml/*.yaml
python utils/plot-multi-timings.py -k -d "${PLOT_WINDOW_START}" -s -g -p viridis --save-plot plots/y3-prediction-scalability-step-recent.png y3-prediction/lassen/yaml/*.yaml

# Update origin/timing with the new README and plots
git add plots
git add README.md
git add latest_testing_date
(git commit -m "Automatic timing summary commit: ${TIMING_HOST} ${TIMING_DATE}" && git push)
set +x
