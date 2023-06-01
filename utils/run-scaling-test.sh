#!/bin/bash

TOPDIR=$(pwd)

# Run this dumb data collect script which
# collects the sql data from the place where
# it runs, and inserts the timing data into
# the nproc-specific yaml files.
SCALING_CASE_RUN_ROOT="y3-prediction-scaling-run"
SCALING_CASE_TIMING_ROOT="y3-prediction"
TEMP_TIMESTAMP=$(date "+%Y.%m.%d-%H.%M.%S")
EMIRGE_HOME=${EMIRGE_HOME:-"${TOPDIR}/emirge"}

cd ${EMIRGE_HOME}/mirgecom
export MIRGE_VERSION=$(git rev-parse HEAD)
export MIRGE_BRANCH=$(git symbolic-ref --short HEAD)
printf "MIRGE_BRANCH=${MIRGE_BRANCH}\n"
printf "MIRGE_VERSION=${MIRGE_VERSION}\n"
cd ${TOPDIR}

if [ -d ${SCALING_CASE_RUN_ROOT} ]; then
    git pull
    cd ${SCALING_CASE_TIMING_ROOT}/sql
    ./grab-and-process-new-scaling-data.sh
    cd ../..
    git add ${SCALING_CASE_TIMING_ROOT}/sql/*-sqlite
    mkdir ${SCALING_CASE_TIMING_ROOT}/output/${TEMP_TIMESTAMP}
    cp ${SCALING_CASE_RUN_ROOT}/scalability_test/scal*.txt ${SCALING_CASE_TIMING_ROOT}/output/${TEMP_TIMESTAMP}
    git add ${SCALING_CASE_TIMING_ROOT}/output/${TEMP_TIMESTAMP}
    git add ${SCALING_CASE_TIMING_ROOT}/yaml
    # git add ${SCALING_CASE_TIMING_ROOT}/yaml
    (git commit -m "Automatic commit: Y3Scalability/Lassen ${TEMP_TIMESTAMP}" && git push)
    mv ${SCALING_CASE_RUN_ROOT} ${SCALING_CASE_RUN_ROOT}_${TEMP_TIMESTAMP}
fi

# Install the prediction driver
# rm -rf ${SCALING_CASE_RUN_ROOT}
printf "Installing driver in: ${TOPDIR}/${SCALING_CASE_RUN_ROOT}\n"

git clone -b scalability-testing git@github.com:/illinois-ceesd/drivers_y3-prediction ${SCALING_CASE_RUN_ROOT}
cd ${SCALING_CASE_RUN_ROOT}
export DRIVER_VERSION=$(git rev-parse HEAD)
export DRIVER_BRANCH=$(git symbolic-ref --short HEAD)

printf "DRIVER_BRANCH=${DRIVER_BRANCH}\n"
printf "DRIVER_VERSION=${DRIVER_VERSION}\n"

conda deactivate
source ${EMIRGE_HOME}/config/activate_env.sh

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

