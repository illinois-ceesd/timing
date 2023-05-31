#!/bin/bash

TOPDIR=$(pwd)

# Run this dumb data collect script which
# collects the sql data from the place where
# it runs, and inserts the timing data into
# the nproc-specific yaml files.
SCALING_CASE_RUN_ROOT="y3-prediction-scaling-run"
SCALING_CASE_TIMING_ROOT="y3-prediction"
TEMP_TIMESTAMP=$(date "+%Y.%m.%d-%H.%M.%S")
if [ -d ${SCALING_CASE_RUN_ROOT} ]; then
    git pull
    cd ${SCALING_CASE_TIMING_ROOT}/sql
    ./grab-and-process-new-scaling-data.sh
    cd ../..
    git add ${SCALING_CASE_TIMING_ROOT}/sql/*-sqlite
    # git add ${SCALING_CASE_TIMING_ROOT}/yaml
    (git commit -am "Automatic commit: Y3Scalability/Lassen ${TEMP_TIMESTAMP}" && git push)
    mv ${SCALING_CASE_RUN_ROOT} ${SCALING_CASE_RUN_ROOT}_${TEMP_TIMESTAMP}
fi

# Install the prediction driver
# rm -rf ${SCALING_CASE_RUN_ROOT}
git clone -b scalability-testing git@github.com:/illinois-ceesd/drivers_y3-prediction ${SCALING_CASE_RUN_ROOT}
EMIRGE_HOME=${EMIRGE_HOME:-"${TOPDIR}/emirge"}
conda deactivate
source ${EMIRGE_HOME}/config/activate_env.sh
cd ${SCALING_CASE_RUN_ROOT}
ln -s $EMIRGE_HOME emirge
pip install -e .

cd data/cav5_comb4/3D/scalability
ln -sf ../../../../../y3-prediction-scalability-data/*.msh .
cd ../../../../scalability_test

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

