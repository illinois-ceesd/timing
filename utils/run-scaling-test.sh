#!/bin/bash

# Run this dumb data collect script which
# collects the sql data from the place where
# it runs, and inserts the timing data into
# the nproc-specific yaml files.
SCALING_CASE_RUN_ROOT="y3-prediction-performance-run"
SCALING_CASE_TIMING_ROOT="y3-prediction"
cd ${SCALING_CASE_TIMING_ROOT}/sql
./grab-and-process-new-scaling-data.sh
cd ../..

# Install the prediction driver
rm -rf ${SCALING_CASE_RUN_ROOT}
git clone -b scalability_testing git@github.com:/illinois-ceesd/driver_y3-prediction ${SCALING_CASE_RUN_ROOT}
EMIRGE_HOME=${EMIRGE_HOME:-"./emirge"}
conda deactivate
source ${EMIRGE_HOME}/config/activate_env.sh
cd ${SCALING_CASE_RUN_ROOT}
pip install -e .

cd scalability_test

job1=$(bsub scal1node_lassen.bsub.sh)
job1_id=$(printf "${job1}" | cut -d "<" -f 2 | cut -d ">" -f 1)
job2=$(bsub -w "${job1_id}" scal2nodes_lassen.bsub.sh)
job2_id=$(printf "${job2}" | cut -d "<" -f 2 | cut -d ">" -f 1)
job3=$(bsub -w "${job2_id}" scal4nodes_lassen.bsub.sh)
job3_id=$(printf "${job3}" | cut -d "<" -f 2 | cut -d ">" -f 1)
job4=$(bsub -w "${job3_id}" scal8nodes_lassen.bsub.sh)
job4_id=$(printf "${job4}" | cut -d "<" -f 2 | cut -d ">" -f 1)
printf "Scaling JobIDs: ${job1_id} ${job2_id} ${job3_id} ${job4_id}\n"

cd ../..

