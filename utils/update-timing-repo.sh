#!/bin/bash
# This script does the following:
# - collects the sql data from the place where
# it ran (last night), processes it and inserts
# the timing data into the nproc-specific yaml
# files for the y3-scaling runs.
# - Pushes those results to the git timing repo
# - Submits the y3-prediction scaling run jobs for 
# tonight's tests 

TOPDIR="/p/gpfs1/mtcampbe/CEESD/AutomatedTesting/MIRGE-Timing/timing"

SCALING_CASE_RUN_ROOT="y3-prediction-scaling-run"
SCALING_CASE_TIMING_ROOT="y3-prediction"
TIMING_PLATFORM=$(uname -n | sed 's/[0-9]\+$//')
TEMP_TIMESTAMP=$(date "+%Y.%m.%d-%H.%M.%S")
EMIRGE_HOME=${EMIRGE_HOME:-"${TOPDIR}/emirge"}
export MIRGE_CACHE_ROOT="${TOPDIR}/timing-run-caches"
SCALING_DAY_OF_WEEK=$(date +%a)
SCALING_DRIVER_BRANCH="main"

printf "Updating repo data for ${SCALING_CASE_TIMING_ROOT} on ${TIMING_PLATFORM}@${TEMP_TIMESTAMP}\n"
cd ${TOPDIR}

PLATFORM_TIMING_DATA_DIR="${SCALING_CASE_TIMING_ROOT}/${TIMING_PLATFORM}"
PLATFORM_SQL_DIR="${PLATFORM_TIMING_DATA_DIR}/sql"
PLATFORM_OUTPUT_DIR="${PLATFORM_TIMING_DATA_DIR}/output/${TEMP_TIMESTAMP}"
PLATFORM_YAML_DIR="${PLATFORM_TIMING_DATA_DIR}/yaml"
mkdir -p ${PLATFORM_SQL_DIR} ${PLATFORM_OUTPUT_DIR} ${PLATFORM_YAML_DIR}

if [ -d ${SCALING_CASE_RUN_ROOT} ]; then
    cd ${SCALING_CASE_RUN_ROOT}
    export DRIVER_VERSION=$(git rev-parse HEAD)
    export DRIVER_BRANCH=$(git symbolic-ref --short HEAD)
    cd ${TOPDIR}
    if [ -f PROCESS_SCALING_DATA ]; then
        printf "Processing previous runs from ${SCALING_CASE_RUN_ROOT}-${DRIVER_BRANCH}@${DRIVER_VERSION}\n"
        printf " - Updating timing ${TOPDIR} from remote repository.\n"
        git pull
        printf " - Grabbing and processing previous timing data...\n"
        cd ${PLATFORM_SQL_DIR}
        ln -sf ${TOPDIR}/utils/grab-and-process-new-scaling-data.sh .
        ./grab-and-process-new-scaling-data.sh
        cd ${TOPDIR} 
        cp ${SCALING_CASE_RUN_ROOT}/scalability_test/scal*.txt ${PLATFORM_OUTPUT_DIR}
        if [ -f COMMIT_SCALING_DATA ]; then
            printf " - Updating timing repo with processed data.\n"
            # Add any changes to platform data
            git add ${PLATFORM_TIMING_DATA_DIR}
            if ! git diff --cached --exit-code >/dev/null; then 
                (git commit -m " - Automatic commit: Y3Scalability/${TIMING_PLATFORM} ${TEMP_TIMESTAMP}" && git push)
            else
                printf " -- No changes to commit.\n"
            fi
        else
            printf "Not committing processed timing data: directive not given.\n"
        fi
    else
        printf "Not processing previous runs: No directive given.\n"
    fi
    if [ -f ARCHIVE_PREDICTION_DRIVER ]; then
        printf " - Removing old viz and restart data in ${SCALING_CASE_RUN_ROOT}\n"
        rm -rf ${SCALING_CASE_RUN_ROOT}/scalability_test/viz_data* ${SCALING_CASE_RUN_ROOT}/scalability_test/restart_data*
        printf " - Archiving ${SCALING_CASE_RUN_ROOT}_${TEMP_TIMESTAMP}\n"
        mv ${SCALING_CASE_RUN_ROOT} ${SCALING_CASE_RUN_ROOT}_${TEMP_TIMESTAMP}
    else
        printf "Driver archival directive not given: Skipping archiving existing driver.\n"
    fi
else
    printf "No previous driver or data found in ${SCALING_CASE_RUN_ROOT}\n"
fi
