#!/bin/bash
# This script does the following:
# - collects the sql data from the place where
# it ran (last night), processes it and inserts
# the timing data into the nproc-specific yaml
# files for the y3-scaling runs.
# - Pushes those results to the git timing repo
# - Submits the y3-prediction scaling run jobs for 
# tonight's tests 

TOPDIR=$(pwd)

SCALING_CASE_RUN_ROOT="y3-prediction-scaling-run"
SCALING_CASE_TIMING_ROOT="y3-prediction"
TIMING_PLATFORM=$(uname -n | sed 's/[0-9]\+$//')
TEMP_TIMESTAMP=$(date "+%Y.%m.%d-%H.%M.%S")
EMIRGE_HOME=${EMIRGE_HOME:-"${TOPDIR}/emirge"}
export MIRGE_CACHE_ROOT="${TOPDIR}/timing-run-caches"
SCALING_DAY_OF_WEEK=$(date +%a)
SCALING_DRIVER_BRANCH="production-pilot"

printf "Running scaling cases for ${SCALING_CASE_TIMING_ROOT} on ${TIMING_PLATFORM}@${TEMP_TIMESTAMP}\n"

if [ "$SCALING_DAY_OF_WEEK" = "Mon" ]; then
    if [ -f DELETE_TIMING_CACHE ]; then
        echo "Today is Monday. Deleting the cache directory..."
        mv $MIRGE_CACHE_ROOT ${MIRGE_CACHE_ROOT}.delete
        rm -rf ${MIRGE_CACHE_ROOT}.delete &
        # Only remove the cache *once* on Monday
        rm DELETE_TIMING_CACHE
    else
        echo "Cache deletion directive not given. Not touching the cache."
    fi
elif [ -f AUTODELETE_TIMING_CACHE ]; then
    echo "Today is not Monday. Skipping cache deletion. Enabling Monday deletion."
    # Re-enable cache deletion for when Monday hits
    touch DELETE_TIMING_CACHE
fi

cd ${EMIRGE_HOME}/mirgecom
export MIRGE_VERSION=$(git rev-parse HEAD)
export MIRGE_BRANCH=$(git symbolic-ref --short HEAD)
printf "MIRGE_BRANCH=${MIRGE_BRANCH}\n"
printf "MIRGE_VERSION=${MIRGE_VERSION}\n"
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

conda deactivate
source ${EMIRGE_HOME}/config/activate_env.sh
${EMIRGE_HOME}/version.sh

# Install the prediction driver
if [ -f CLONE_PREDICTION_DRIVER ]; then
    printf "Cloning (drivers_y3-prediction@${SCALING_DRIVER_BRANCH}) to: ${TOPDIR}/${SCALING_CASE_RUN_ROOT}\n"
    rm -rf ${SCALING_CASE_RUN_ROOT}
    git clone -b ${SCALING_DRIVER_BRANCH} git@github.com:/illinois-ceesd/drivers_y3-prediction ${SCALING_CASE_RUN_ROOT}
    if [ -f INSTALL_PREDICTION_DRIVER ]; then
        printf "Installing driver in ${SCALING_CASE_RUN_ROOT}\n"
        cd ${SCALING_CASE_RUN_ROOT}
        ln -s $EMIRGE_HOME emirge
        pip install -e .
        cd data/cav5_comb4/3D/scalability
        ln -sf ${TOPDIR}/y3-prediction-scalability-data/*.msh .
        printf "Installed driver in ${SCALING_CASE_RUN_ROOT} at ${TEMP_TIMESTAMP}\n"
        cd ${TOPDIR}
    else
        printf "Skipping driver install: Installation directive not given.\n"
    fi
else
    printf "Driver clone directive not given: Skipping cloning of new driver.\n"
fi

conda deactivate

if [ -d ${SCALING_CASE_RUN_ROOT} ]; then
    printf "Found driver in ${SCALING_CASE_RUN_ROOT}\n"
    cd ${SCALING_CASE_RUN_ROOT}
    export DRIVER_VERSION=$(git rev-parse HEAD)
    export DRIVER_BRANCH=$(git symbolic-ref --short HEAD)
    printf "DRIVER_BRANCH=${DRIVER_BRANCH}\n"
    printf "DRIVER_VERSION=${DRIVER_VERSION}\n"
    cd ../

    if [ -f SUBMIT_SCALING_JOBS ]; then
        touch ${TOPDIR}/$SCALING_CASE_RUN_ROOT}/scaling-run_${TEMP_TIMESTAMP}
        printf "Submitting scaling jobs.\n"
        cd ${TOPDIR}/${SCALING_CASE_RUN_ROOT}/scalability_test
        PLATFORM_BATCH_NAME="lassen.bsub"
        BATCH_COMMAND="bsub"
        if test "${TIMING_PLATFORM}" == "tioga"
        then
            PLATFORM_BATCH_NAME="tioga.flux"
            BATCH_COMMAND="flux batch"
        fi
        printf "Submitting timing jobs using ${PLATFORM_BATCH_NAME} and ${BATCH_COMMAND}.\n"
        pwd
        ls *${PLATFORM_BATCH_NAME}*
        set -x
        job1=$(${BATCH_COMMAND} scal1node_${PLATFORM_BATCH_NAME}.sh)
        set +x
        if test "${TIMING_PLATFORM}" == "tioga"
        then
            sleep 30
            set -x
            job2=$(${BATCH_COMMAND} scal2nodes_${PLATFORM_BATCH_NAME}.sh)
            set +x
            sleep 30
            set -x
            job3=$(${BATCH_COMMAND} scal4nodes_${PLATFORM_BATCH_NAME}.sh)
            set +x
            printf "Scaling JobIDs: ${job1} ${job2} ${job3}\n"
        else
            job1_id=$(printf "${job1}" | cut -d "<" -f 2 | cut -d ">" -f 1)
            set -x
            # job2=$(${BATCH_COMMAND} -w "ended(${job1_id})" scal2nodes_${PLATFORM_BATCH_NAME}.sh)
            sleep 30 # sleep helps prevent identical timestamps on logfiles for multiple runs
            job2=$(${BATCH_COMMAND} scal2nodes_${PLATFORM_BATCH_NAME}.sh)
            set +x
            job2_id=$(printf "${job2}" | cut -d "<" -f 2 | cut -d ">" -f 1)
            set -x
            # job3=$(${BATCH_COMMAND} -w "ended(${job2_id})" scal4nodes_${PLATFORM_BATCH_NAME}.sh)
            sleep 30
            job3=$(${BATCH_COMMAND} scal4nodes_${PLATFORM_BATCH_NAME}.sh)
            set +x
            job3_id=$(printf "${job3}" | cut -d "<" -f 2 | cut -d ">" -f 1)
            set -x
            # job4=$(${BATCH_COMMAND} -w "ended(${job3_id})" scal8nodes_${PLATFORM_BATCH_NAME}.sh)
            sleep 30
            job4=$(${BATCH_COMMAND} scal8nodes_${PLATFORM_BATCH_NAME}.sh)
            set +x
            job4_id=$(printf "${job4}" | cut -d "<" -f 2 | cut -d ">" -f 1)
            printf "Scaling JobIDs: ${job1_id} ${job2_id} ${job3_id} ${job4_id}\n"
        fi
        cd ${TOPDIR}
    else
        printf "Job submission directive not given.\n"
    fi
else
    printf "No prediction driver found in ${SCALING_CASE_RUN_ROOT}\n"
fi
